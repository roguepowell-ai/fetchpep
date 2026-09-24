// Billing kill switch (D-070, brief B-001).
//
// Receives budget notifications from the topic. It acts only on the kill budget's own
// messages, from the current budget month, and only when actual spend has passed
// KILL_AMOUNT. Then it detaches billing from PROJECT_ID.
//
// While DRY_RUN is anything other than the exact string "false" it changes nothing: it
// checks that it holds the permission the detach needs, and logs "would detach" with the
// answer, so a dry run proves "could detach" as well.

"use strict";

const functions = require("@google-cloud/functions-framework");

const PROJECT_ID = process.env.PROJECT_ID;
const KILL_BUDGET = process.env.KILL_BUDGET; // display name of the kill budget
const KILL_AMOUNT = Number(process.env.KILL_AMOUNT);
const DRY_RUN = process.env.DRY_RUN !== "false"; // fail safe: unset means dry run

const DETACH_PERMISSION = "resourcemanager.projects.deleteBillingAssignment";

const TOKEN_URL =
  "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token";
const BILLING_URL = (project) =>
  `https://cloudbilling.googleapis.com/v1/projects/${project}/billingInfo`;
const TEST_PERMISSIONS_URL = (project) =>
  `https://cloudresourcemanager.googleapis.com/v3/projects/${project}:testIamPermissions`;

// Structured logs. Amounts and names only — never the token (R-SEC-06).
function log(severity, message, fields = {}) {
  console.log(JSON.stringify({ severity, message, project: PROJECT_ID, dryRun: DRY_RUN, ...fields }));
}

function parseBudget(cloudEvent) {
  const encoded = cloudEvent?.data?.message?.data;
  if (typeof encoded !== "string") return null;
  try {
    return JSON.parse(Buffer.from(encoded, "base64").toString("utf8"));
  } catch {
    return null;
  }
}

// A budget month runs from costIntervalStart for one calendar month. A message whose
// month has ended is stale (a redelivery, or one delayed across the month boundary) and
// must not act on the new month. An unreadable start is not treated as stale: the check
// exists to stop a wrong detach, not to block a right one.
function monthHasEnded(costIntervalStart, now = new Date()) {
  const start = new Date(costIntervalStart);
  if (Number.isNaN(start.getTime())) return false;
  const end = new Date(start);
  end.setUTCMonth(end.getUTCMonth() + 1);
  return now >= end;
}

async function accessToken() {
  const res = await fetch(TOKEN_URL, { headers: { "Metadata-Flavor": "Google" } });
  if (!res.ok) throw new Error(`metadata token request failed: ${res.status}`);
  return (await res.json()).access_token;
}

async function canDetach() {
  const res = await fetch(TEST_PERMISSIONS_URL(PROJECT_ID), {
    method: "POST",
    headers: {
      Authorization: `Bearer ${await accessToken()}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ permissions: [DETACH_PERMISSION] }),
  });
  if (!res.ok) throw new Error(`testIamPermissions failed: ${res.status} ${await res.text()}`);
  const granted = (await res.json()).permissions ?? [];
  return granted.includes(DETACH_PERMISSION);
}

async function detachBilling() {
  const res = await fetch(BILLING_URL(PROJECT_ID), {
    method: "PUT",
    headers: {
      Authorization: `Bearer ${await accessToken()}`,
      "Content-Type": "application/json",
    },
    // An empty account name unlinks the project from its billing account.
    body: JSON.stringify({ billingAccountName: "" }),
  });
  if (!res.ok) {
    throw new Error(`detach failed: ${res.status} ${await res.text()}`);
  }
}

async function killSwitch(cloudEvent) {
  if (!PROJECT_ID || !KILL_BUDGET || !(KILL_AMOUNT > 0)) {
    log("ERROR", "PROJECT_ID, KILL_BUDGET or KILL_AMOUNT is not set; doing nothing");
    return;
  }

  const budget = parseBudget(cloudEvent);
  const cost = Number(budget?.costAmount);

  // A message we cannot read is acknowledged, not retried: a retry would fail the same way.
  if (!budget || !Number.isFinite(cost)) {
    log("WARNING", "unreadable budget notification; ignored");
    return;
  }

  const fields = {
    budget: budget.budgetDisplayName,
    costAmount: cost,
    killAmount: KILL_AMOUNT,
    currency: budget.currencyCode,
    costIntervalStart: budget.costIntervalStart,
  };

  // Only the kill budget's messages count. The threshold is this function's own setting,
  // not the amount the message carries, so a message from any other budget cannot trip it.
  if (budget.budgetDisplayName !== KILL_BUDGET) {
    log("INFO", "not the kill budget; ignored", fields);
    return;
  }

  if (monthHasEnded(budget.costIntervalStart)) {
    log("INFO", "message from a budget month that has ended; ignored", fields);
    return;
  }

  // costAmount is actual spend so far this month. Forecasts are never acted on.
  if (cost <= KILL_AMOUNT) {
    log("INFO", "under the kill amount; no action", fields);
    return;
  }

  if (DRY_RUN) {
    const could = await canDetach(); // throws on failure, so the error is visible
    log(could ? "WARNING" : "ERROR", "would detach billing", {
      ...fields,
      couldDetach: could,
      permission: DETACH_PERMISSION,
    });
    return;
  }

  log("WARNING", "over the kill amount; detaching billing", fields);
  await detachBilling(); // throws on failure, so Pub/Sub retries delivery
  log("WARNING", "billing detached", fields);
}

functions.cloudEvent("killSwitch", killSwitch);

module.exports = { killSwitch, monthHasEnded };
