# CLAUDE.md — the directory

A lookup table, not a rulebook. It says which contract file to read for the work in front
of you. A rule written *here* rather than routed *to* is a bug — with one deliberate
exception, section 2, explained there.

Product **Inkfold** · codename **FetchPep** · owner George Powell.

---

## 1. Always loaded

Imported, not referenced. [likely] Only this file is re-read from disk and re-injected after a compaction; a file merely *named* here is not.

@rules/NON-NEGOTIABLES.rule.md
@rules/LANGUAGE.rule.md
@rules/WORKING-METHOD.rule.md
@state/OPEN.state.md

Four. Past five, the contract is leaking into the router. `state/DECISIONS.state.md` is deliberately not imported —
it grows without limit, and an always-loaded file that grows eventually crowds out the ones that matter. Route to it instead.

---

## 2. Hard stops — the exception to "no rules here"

Here rather than in a nested file, because a nested file **stops applying after a compaction** until that directory is read again, and a rule
that silently expires is not a rule. Each is also enforced by a hook; this text exists so the refusal is comprehensible.

- Never alter an existing asset **GUID**. Every reference in every scene and prefab
  resolves through it; changing one breaks things silently and untraceably.
- Never move an asset without its `.meta` file. `git mv` both, or use the Editor.
- Never restructure `.unity`, `.prefab` or `.asset` YAML. Reading is fine. A single-line
  scalar change with no `fileID:` or `guid:` on the line is the only permitted edit, and
  only when no Editor is reachable.
- Never edit a file whose frontmatter says `authority: george-only`.
- Never run `terraform apply` against production, and never touch billing configuration, except the kill switch's first version, written once under D-070.
- Never claim work is done on the strength of your own account of it. See section 5.

---

## 3. Routes by path

Scoped rules live in `.claude/rules/` with a `paths:` glob in frontmatter, so a rule enters
context only when a matching file is read. [certain] This is what actually scopes context;
`@import` does not — imported files load in full at launch.

| Rule file | `paths:` |
|---|---|
| `.claude/rules/unity-editor.md` | `unity/**/*.cs`, `unity/**/*.asmdef` |
| `.claude/rules/unity-assets.md` | `unity/**/*.unity`, `unity/**/*.prefab` |
| `.claude/rules/api-seam.md` | `services/api/**` |
| `.claude/rules/nakama.md` | `services/nakama/**` |
| `.claude/rules/infra.md` | `infra/**/*.tf` |
| `.claude/rules/warehouse.md` | `warehouse/**` |
| `.claude/rules/web.md` | `web/**` |
| `.claude/rules/ci.md` | `.github/workflows/**` |

Each scoped rule routes to its spec. It does not restate it.

---

## 4. Routes by topic

Path routing misses work spanning directories, and all work that happens before a file
exists — which is most of planning.

| When the work is about | Read |
|---|---|
| Deciding anything, or calling something settled | `rules/DECISION-RULES.rule.md` · `state/DECISIONS.state.md` |
| Schema, migrations, the global/shard seam | `spec/DATA-MODEL.spec.md` · `spec/PLACES.spec.md` |
| Folds, places, the world map | `spec/PLACES.spec.md` · `spec/PRODUCT.spec.md` |
| Encounters, rarity, anything random | `spec/ENCOUNTERS.spec.md` · `rules/NON-NEGOTIABLES.rule.md` |
| Submissions, screening, age verification | `spec/SCREENING.spec.md` · `rules/NON-NEGOTIABLES.rule.md` |
| Any text a person reads — UI, copy, errors | `spec/BRAND.spec.md` · `spec/IDENTITY.spec.md` |
| Sprites, layout, components | `spec/DESIGN.spec.md` · the Inkfold design system |
| Cost, billing, anything that spends | `ops/COSTS.ops.md` |
| Releasing, signing, uploading to a store | `ops/RUNBOOK.ops.md` · `ops/INFRA.ops.md` |
| Secrets, authorization, uploads, third-party dependencies | `spec/SECURITY.spec.md` |
| Personal data, retention, erasure, anything a person could be identified by | `spec/PRIVACY.spec.md` |
| Whether to scale, shard, or raise a limit | `ops/SCALING.ops.md` · `state/DECISIONS.state.md` |
| Adding or upgrading a package, or setting an API version | `ops/VERSIONS.ops.md` |
| What was built and why | `state/SESSION-LOG.state.md` · `state/SUPERSEDED.state.md` |

Several rows match: read all of them. None match: say so and ask.

---

## 5. Evidence

A task passes on evidence from outside the conversation, never on Claude's account of it.
State the command that proves it and its result — an exit code, a test name, a diff, rows
returned. [certain] Absence of an error is not evidence: `unity command eval` does not
return `Debug.Log` output, and console readers can return zero entries because a severity
filter is off rather than because nothing failed.

`unity test` exit codes: **0** passed · **8** tests failed · **6** no verdict produced
(timeout, compile error, missing licence). 6 and 8 are different problems.

---

## 6. Write authority

Declared per file as `authority:` frontmatter. A hook refuses the write; CI is the backstop.

| Directory | Authority |
|---|---|
| `rules/` | `george-only` |
| `spec/` · `ops/` · `infra/` · `services/` | `claude-proposes` |
| `state/` · `checks/` · `hooks/` | `claude-writes` |

---

## 7. Stop conditions

In `~/fetchpep`, a session acts on briefs (issues) and reviews (PR comments) posted by
`roguepowell-ai` on this repo without asking George, and asks its questions there (D-086;
the loop is `ops/RUNBOOK.ops.md` Part 4, and any opening message starts it: check out
`main`, pull, work). It writes to `state/OPEN.state.md` and stops, not guessing, when:

- The prompt is ambiguous and the wrong reading is expensive to undo
- No route matches and the right spec is unclear
- A decision is needed that is not in `state/DECISIONS.state.md`
- The work touches a `george-only` file, money, a sign-in, an install outside the scratch folder, a store, a keystore, the kill switch, or a permanent identifier
- Your work, a request or another Claude role's work conflicts with a decision: both sides to OPEN with their IDs, then push back (D-069)

Nothing is settled without a cited decision ID.

---

## 8. Enforcement tiers

[certain] This file reaches Claude as a user message, not as system prompt. There is no
compliance guarantee. Tier accordingly.

| Tier | Mechanism | Use for |
|---|---|---|
| Blocked | `hooks/` PreToolUse | Anything that must never happen |
| Caught | `checks/` in CI | Anything that must not merge |
| Explained | `rules/` and `spec/` | Why the block exists, and judgement |

A rule you have had to repeat twice belongs one tier up.

---

## 9. CI

Six checks run in CI on every push and block the merge; three more run only in the pre-push
hook. `checks/README.md` lists them and what each fails on. The orphan check is the one that
matters: a contract file nothing routes to is unreachable after a compaction, not merely unread.
