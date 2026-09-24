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
import { relative, sep } from "node:path";

const ALLOW = 0;
const BLOCK = 2;

const WRITE_TOOLS = new Set(["Write", "Edit", "MultiEdit", "NotebookEdit"]);

// Unity asset files whose structure must not be rewritten by hand.
const UNITY_ASSET = /\.(unity|prefab|asset|meta|controller|mat)$/i;

// Cross-reference tokens. A line carrying one of these is load-bearing.
const UNITY_REF = /\b(guid|fileID|m_CorrespondingSourceObject|m_PrefabInstance)\s*:/;

const BANNED_TERMS_FILE = "checks/banned-terms.txt";

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

const rel = relative(process.cwd(), filePath).split(sep).join("/");

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

// ------------------------------------------------------------------ 4. banned terms
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
