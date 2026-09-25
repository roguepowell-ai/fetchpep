#!/usr/bin/env node
// Inkfold / FetchPep — PreToolUse write guard.
//
// Refuses writes that the contract says must never happen. This is the enforcement
// tier: CLAUDE.md reaches the model as a user message and carries no compliance
// guarantee, so anything that must never happen is blocked here rather than requested
// in prose.
//
// Wire it up in .claude/settings.json — see hooks/README.md.
//
// Protocol: reads one JSON object on stdin. Exit 0 allows the call. Exit 2 blocks it
// and feeds stderr back to the model as the reason.

import { readFileSync, existsSync } from "node:fs";
import { relative, sep, dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

// The repo root, worked out from this file's own location rather than from the working
// directory.
//
// Two things here were relative to the working directory, and only one of them mattered.
// Measured from `infra/dev` against the version on main, 25 Sep:
//
//   george-only file    BLOCKED, exit 2   — the `rules/` prefix test did fail, because
//                                           `rel` came out as `../../rules/…`, but the
//                                           frontmatter arm reads the absolute path and
//                                           caught it anyway. Two arms, one held.
//   banned term         ALLOWED, exit 0   — `checks/banned-terms.txt` was opened by a
//                                           relative path, was not found, and an empty
//                                           list matches nothing. Silently open.
//
// So the authority guard held and the language guard did not. Anchoring on this file's own
// location fixes both, and leaves the guard independent of where the process starts. This
// file is always <root>/hooks/, so the parent of its directory is the root.
const ROOT = dirname(dirname(fileURLToPath(import.meta.url)));

const ALLOW = 0;
const BLOCK = 2;

const WRITE_TOOLS = new Set(["Write", "Edit", "MultiEdit", "NotebookEdit"]);

// Unity asset files whose structure must not be rewritten by hand.
const UNITY_ASSET = /\.(unity|prefab|asset|meta|controller|mat)$/i;

// Cross-reference tokens. A line carrying one of these is load-bearing.
const UNITY_REF = /\b(guid|fileID|m_CorrespondingSourceObject|m_PrefabInstance)\s*:/;

const BANNED_TERMS_FILE = join(ROOT, "checks/banned-terms.txt");

// R-SEC-01. A secret in git history is permanent — rotation is the only remedy — so
// this blocks the write rather than catching the commit. Exempt a line with a trailing
// `allow-secret:` comment; the exemption is then visible in the diff.
const SECRET_PATTERNS = [
  [/AKIA[0-9A-Z]{16}/, "an AWS access key id"],
  [/\b[rs]k_(live|test)_[0-9a-zA-Z]{16,}/, "a Stripe key"],
  [/\bgh[pousr]_[0-9A-Za-z]{30,}/, "a GitHub token"],
  [/-----BEGIN [A-Z ]*PRIVATE KEY-----/, "a private key"],
  [/\bAIza[0-9A-Za-z_-]{30,}/, "a Google API key"],
  [/\bxox[baprs]-[0-9A-Za-z-]{10,}/, "a Slack token"],
  [/(password|passwd|secret|api_?key|token)\s*[:=]\s*["'][^"']{12,}["']/i,
   "a credential assigned inline"],
];

function refuse(reason, remedy) {
  process.stderr.write(`BLOCKED by hooks/guard-write.mjs\n\n${reason}\n\n${remedy}\n`);
  process.exit(BLOCK);
}

function readStdin() {
  try {
    return JSON.parse(readFileSync(0, "utf8") || "{}");
  } catch {
    process.exit(ALLOW); // never block because the guard itself failed to parse
  }
}

function frontmatterAuthority(path) {
  if (!existsSync(path)) return null;
  let head;
  try {
    head = readFileSync(path, "utf8").slice(0, 600);
  } catch {
    return null;
  }
  if (!head.startsWith("---")) return null;
  const end = head.indexOf("\n---", 3);
  const block = end === -1 ? head : head.slice(0, end);
  const m = block.match(/^authority:\s*([a-z-]+)\s*$/m);
  return m ? m[1] : null;
}

function bannedTerms() {
  if (!existsSync(BANNED_TERMS_FILE)) return [];
  return readFileSync(BANNED_TERMS_FILE, "utf8")
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l && !l.startsWith("#"));
}

const input = readStdin();
const tool = input.tool_name ?? "";
if (!WRITE_TOOLS.has(tool)) process.exit(ALLOW);

const ti = input.tool_input ?? {};
const filePath = ti.file_path ?? ti.notebook_path ?? "";
if (!filePath) process.exit(ALLOW);

const rel = relative(ROOT, filePath).split(sep).join("/");

// ---------------------------------------------------------------- 1. authority
if (rel.startsWith("rules/") || frontmatterAuthority(filePath) === "george-only") {
  refuse(
    `${rel} is authority: george-only. Claude does not edit the rules it is bound by.`,
    "Propose the change in state/OPEN.state.md and let George make the edit."
  );
}

// ------------------------------------------------------- 2. Unity asset structure
if (UNITY_ASSET.test(rel)) {
  refuse(
    `${rel} is a Unity asset file. Its YAML is readable but not safely editable — ` +
      `every cross-reference resolves through a GUID, and a hand edit breaks scenes silently.`,
    "Use the Unity CLI against a live Editor (unity command / unity status), or make the " +
      "change in the Editor. If no Editor is reachable, stop and say so."
  );
}

// ---------------------------------------------------------- 3. GUID / fileID edits
const payload = [ti.content, ti.new_string, ti.old_string, ti.new_source]
  .filter((s) => typeof s === "string")
  .join("\n");

if (UNITY_REF.test(payload)) {
  refuse(
    `The change to ${rel} touches a guid: or fileID: reference.`,
    "Changing an existing GUID breaks every reference to that asset, silently and " +
      "untraceably. Route this through the Editor."
  );
}

// ------------------------------------------------------------------- 4. secrets
if (payload && !/^checks\//.test(rel) && !/^hooks\//.test(rel)) {
  for (const line of payload.split("\n")) {
    if (line.includes("allow-secret")) continue;
    for (const [re, what] of SECRET_PATTERNS) {
      if (re.test(line)) {
        refuse(
          `The change to ${rel} contains what looks like ${what} (R-SEC-01).`,
          "A secret committed to git is permanent — removing the line does not remove it " +
            "from history, and rotation becomes the only remedy. Put it in GitHub Actions " +
            "secrets or Secret Manager and reference it by name. If this is a false " +
            "positive, end the line with `allow-secret: why`."
        );
      }
    }
  }
}

// ------------------------------------------------------------------ 5. banned terms
const isContractFile = /^(checks|rules)\//.test(rel);
if (!isContractFile && payload) {
  const lower = payload.toLowerCase();
  for (const term of bannedTerms()) {
    if (lower.includes(term.toLowerCase())) {
      refuse(
        `The change to ${rel} contains the banned term "${term}".`,
        "See rules/LANGUAGE.rule.md. Use the project vocabulary instead."
      );
    }
  }
}

process.exit(ALLOW);
