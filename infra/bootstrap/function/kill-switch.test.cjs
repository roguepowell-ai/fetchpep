// Tests for the kill switch. Run: node infra/bootstrap/function/kill-switch.test.cjs
// No network: fetch and the Functions Framework are replaced. Not shipped (see excludes
// in kill_switch.tf).
const assert = require("node:assert");
const Module = require("node:module");
const path = require("node:path").join(__dirname, "index.js");
// Stand-in for the Functions Framework: record what is registered.
let registered = {};
const origLoad = Module._load;
Module._load = function (req, ...rest) {
  if (req === "@google-cloud/functions-framework") return { cloudEvent: (n, f) => { registered[n] = f; } };
  return origLoad.call(this, req, ...rest);
};
const thisMonth = new Date(Date.UTC(new Date().getUTCFullYear(), new Date().getUTCMonth(), 1, 7)).toISOString();
const lastMonth = new Date(Date.UTC(new Date().getUTCFullYear(), new Date().getUTCMonth() - 1, 1, 7)).toISOString();
const ev = (o) => ({ data: { message: { data: Buffer.from(JSON.stringify({ costIntervalStart: thisMonth, ...o })).toString("base64") } } });
function load(env) {
  delete require.cache[require.resolve(path)];
  for (const k of ["DRY_RUN", "PROJECT_ID", "KILL_BUDGET", "KILL_AMOUNT"]) delete process.env[k];
  Object.assign(process.env, { PROJECT_ID: "fetchpep-dev", KILL_BUDGET: "fetchpep-dev-kill", KILL_AMOUNT: "30" }, env);
  registered = {};
  const m = require(path);
  assert.equal(registered.killSwitch, m.killSwitch, "killSwitch registered as a CloudEvent function");
  return m;
}
let calls, logs, billingOk, granted;
global.fetch = async (url, opts = {}) => {
  calls.push({ url, opts });
  if (url.includes("metadata")) return { ok: true, json: async () => ({ access_token: "T" }) };
  if (url.includes("testIamPermissions")) return { ok: true, json: async () => (granted ? { permissions: JSON.parse(opts.body).permissions } : {}) };
  return billingOk ? { ok: true } : { ok: false, status: 403, text: async () => "denied" };
};
const api = () => calls.filter((c) => !c.url.includes("metadata"));
const orig = console.log;
async function run(name, env, event, check) {
  calls = []; logs = []; console.log = (s) => logs.push(JSON.parse(s));
  let err; try { await load(env).killSwitch(event); } catch (e) { err = e; }
  console.log = orig;
  check(err); orig("pass", name);
}
(async () => {
  billingOk = true; granted = true;
  const kill = (cost) => ev({ budgetDisplayName: "fetchpep-dev-kill", costAmount: cost, budgetAmount: 30, currencyCode: "GBP" });
  await run("dry run by default, over: permission tested, would detach, couldDetach true, no billing call", {}, kill(31.2), (e) => {
    assert(!e); assert.equal(api().length, 1); assert.match(api()[0].url, /cloudresourcemanager.*fetchpep-dev:testIamPermissions/);
    assert.deepEqual(JSON.parse(api()[0].opts.body), { permissions: ["resourcemanager.projects.deleteBillingAssignment"] });
    const l = logs.at(-1); assert.match(l.message, /would detach/); assert.equal(l.couldDetach, true); assert.equal(l.severity, "WARNING");
  });
  granted = false;
  await run("dry run without the permission: would detach logged as ERROR, couldDetach false", {}, kill(31.2), (e) => {
    assert(!e); const l = logs.at(-1); assert.equal(l.couldDetach, false); assert.equal(l.severity, "ERROR");
  });
  granted = true;
  await run("DRY_RUN=False (not exact) is still dry", { DRY_RUN: "False" }, kill(31.2), () => assert(!api().some((c) => c.url.includes("billingInfo"))));
  await run("reviewer case: warn budget message 11/10, live: ignored", { DRY_RUN: "false" }, ev({ budgetDisplayName: "fetchpep-dev-warn", costAmount: 11, budgetAmount: 10 }), (e) => {
    assert(!e); assert.equal(calls.length, 0); assert.match(logs.at(-1).message, /not the kill budget/);
  });
  await run("kill message whose amount says 10, cost 11, live: env threshold 30 wins, no call", { DRY_RUN: "false" }, ev({ budgetDisplayName: "fetchpep-dev-kill", costAmount: 11, budgetAmount: 10 }), () => assert.equal(calls.length, 0));
  await run("29.99, live: no call", { DRY_RUN: "false" }, kill(29.99), () => assert.equal(calls.length, 0));
  await run("30 exactly, live: no call", { DRY_RUN: "false" }, kill(30), () => assert.equal(calls.length, 0));
  await run("last month's message, over, live: ignored as stale", { DRY_RUN: "false" }, ev({ budgetDisplayName: "fetchpep-dev-kill", costAmount: 99, costIntervalStart: lastMonth }), (e) => {
    assert(!e); assert.equal(calls.length, 0); assert.match(logs.at(-1).message, /ended/);
  });
  await run("unreadable message: ignored", { DRY_RUN: "false" }, { data: {} }, (e) => { assert(!e); assert.equal(calls.length, 0); });
  await run("missing KILL_AMOUNT: does nothing", { DRY_RUN: "false", KILL_AMOUNT: "" }, kill(99), () => { assert.equal(calls.length, 0); assert.equal(logs.at(-1).severity, "ERROR"); });
  await run("30.01, live: PUT empty account on fetchpep-dev, token not logged", { DRY_RUN: "false" }, kill(30.01), (e) => {
    assert(!e); assert.equal(api().length, 1);
    assert.equal(api()[0].url, "https://cloudbilling.googleapis.com/v1/projects/fetchpep-dev/billingInfo");
    assert.equal(api()[0].opts.method, "PUT"); assert.deepEqual(JSON.parse(api()[0].opts.body), { billingAccountName: "" });
    assert.equal(logs.at(-1).message, "billing detached"); assert(!JSON.stringify(logs).includes('"T"'));
  });
  billingOk = false;
  await run("detach refused: throws so Pub/Sub retries", { DRY_RUN: "false" }, kill(31), (e) => { assert(e); assert.match(e.message, /403/); });
  const { monthHasEnded } = load({});
  assert.equal(monthHasEnded("2026-09-01T07:00:00Z", new Date("2026-09-30T23:00:00Z")), false);
  assert.equal(monthHasEnded("2026-09-01T07:00:00Z", new Date("2026-10-01T07:00:00Z")), true);
  assert.equal(monthHasEnded(undefined), false);
  orig("pass monthHasEnded boundaries");
  orig("ALL PASS");
})().catch((e) => { console.log = orig; console.error("FAIL", e); process.exit(1); });
