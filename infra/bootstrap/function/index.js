// Billing kill switch (D-070, brief B-001).
//
// Receives every notification from the fetchpep-dev-kill budget. When actual spend this
// month has passed the budget amount, it detaches billing from PROJECT_ID. While DRY_RUN
// is anything other than the exact string "false" it only logs "would detach".
//
// No dependencies: a token from the metadata server and one REST call. Nothing to pin,
// nothing to audit, nothing on the money path that is not in this file.

"use strict";

const PROJECT_ID = process.env.PROJECT_ID;
const DRY_RUN = process.env.DRY_RUN !== "false"; // fail safe: unset means dry run

const TOKEN_URL =
  "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token";
const BILLING_URL = (project) =>
  `https://cloudbilling.googleapis.com/v1/projects/${project}/billingInfo`;

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

async function accessToken() {
  const res = await fetch(TOKEN_URL, { headers: { "Metadata-Flavor": "Google" } });
  if (!res.ok) throw new Error(`metadata token request failed: ${res.status}`);
  return (await res.json()).access_token;
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

exports.killSwitch = async (cloudEvent) => {
  if (!PROJECT_ID) {
    log("ERROR", "PROJECT_ID is not set; doing nothing");
    return;
  }

  const budget = parseBudget(cloudEvent);
  const cost = Number(budget?.costAmount);
  const limit = Number(budget?.budgetAmount);

  // A message we cannot read is acknowledged, not retried: a retry would fail the same way.
  if (!budget || !Number.isFinite(cost) || !Number.isFinite(limit)) {
    log("WARNING", "unreadable budget notification; ignored");
    return;
  }

  const fields = {
    budget: budget.budgetDisplayName,
    costAmount: cost,
    budgetAmount: limit,
    currency: budget.currencyCode,
    costIntervalStart: budget.costIntervalStart,
  };

  // costAmount is actual spend so far this month. Forecasts are never acted on.
  if (cost <= limit) {
    log("INFO", "under budget; no action", fields);
    return;
  }

  if (DRY_RUN) {
    log("WARNING", "would detach billing", fields);
    return;
  }

  log("WARNING", "over budget; detaching billing", fields);
  await detachBilling(); // throws on failure, so Pub/Sub retries delivery
  log("WARNING", "billing detached", fields);
};
