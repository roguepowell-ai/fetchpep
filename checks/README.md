---
authority: claude-writes
---

# checks/

The **caught** tier. Blocked things live in `hooks/`; explained things live in `rules/` and
`spec/`. See `rules/WORKING-METHOD.rule.md` for why the tiers exist.

A check blocks the merge when it runs in CI, and refuses the push when it runs in the
pre-push hook. It reads the contract as **data**, never as instructions.

**All ten run in CI** (`.github/workflows/checks.yml`). **Eight** of them also run in
`.githooks/pre-push` — not `authority`, which needs a base ref to compare against, and not
`bundle`, which needs `npm ci`. `secrets`, `versions` and `naming` used to run in the hook only, which
meant they gated nothing that mattered — `--no-verify` skips the hook and a fresh clone does
not have it until `core.hooksPath` is set. That was O-42, and it is closed. `bundle` is the
other way round: CI only, because it needs the npm registry and the hook is meant to fail in
seconds.

## The checks

| Check | Fails when | Runs in |
|---|---|---|
| `router-size.check.sh` | `CLAUDE.md` exceeds 150 lines | CI, hook |
| `router-links.check.sh` | `CLAUDE.md` references a path that does not exist | CI, hook |
| `router-orphans.check.sh` | A contract file exists that nothing routes to | CI, hook |
| `frontmatter.check.sh` | A contract file has missing or invalid `authority:` | CI, hook |
| `banned-terms.check.sh` | A banned term appears outside the files that define it | CI, hook |
| `authority.check.sh` | A Claude-authored commit touches a `george-only` file | CI |
| `secrets.check.sh` | Anything that looks like a credential is committed | CI, hook |
| `versions.check.sh` | `ops/VERSIONS.ops.md` disagrees with what is actually pinned | CI, hook |
| `naming.check.sh` | A contract file is named outside the convention | CI, hook |
| `bundle.check.sh` | `services/nakama/build/index.js` is not what `src/` compiles to (D-097) | CI only |

## Not one of the ten

`skeleton.test.mjs` is a **spec test**, not a gate. It reads Migration 0001 and 0002 out of
`spec/DATA-MODEL.spec.md` and applies them to an embedded PostgreSQL, so the spec's own
*Evidence* section can be reproduced after a merge rather than quoted from a pull request.
It is not in CI and not in the hook, because it needs PGlite, which is test-only and is
never installed into this repo (D-084 — the install goes in the developer's scratch folder):

```
cd <scratch folder> && npm install --save-exact @electric-sql/pglite@0.3.16
cd <repo> && PGLITE_DIR=<scratch folder> node checks/skeleton.test.mjs spec/DATA-MODEL.spec.md
```

**`bundle.check.sh`** — D-097. Nakama loads one JavaScript file, the VM has no build step
and there is no image registry of ours, so `infra/dev/vm_nakama.tf` reads the committed
bundle with `file()` and delivers it in instance metadata. The committed file is therefore
the thing that runs. Editing `src/` without rebuilding ships the old module; editing the
bundle by hand ships something no source describes. Neither leaves a trace, which is what
makes it a check rather than a rule. It copies the sources into a temporary directory, installs and
compiles **there**, and compares, so running it touches nothing in the working tree — not
even `node_modules`, which an in-place `npm ci` would have replaced.

## The two that matter most

**`router-orphans.check.sh`** — a contract file nothing routes to is not merely unread.
[likely] After a context compaction it is unreachable, because only the root file is
re-read and re-injected.

**`secrets.check.sh`** — [certain] a secret in git history is permanent. Rotation is the
only remedy. This check is the backstop; `hooks/guard-write.mjs` is the control.

## Where else these run

`.githooks/pre-push` runs eight of the ten before a push leaves the machine, and refuses it
on any failure — the list in `.githooks/pre-push.bash`, which is the thing to count, not this
sentence. It is a POSIX `sh` shim that finds bash (on `PATH`, then
`C:\Program Files\Git\bin\bash.exe`, then `C:\Program Files\Git\usr\bin\bash.exe`) and runs
`.githooks/pre-push.bash`, because GitHub Desktop's bundled git has no bash (O-71). If no
bash is found, the push is refused. Enable once per clone:

```
git config core.hooksPath .githooks
```

It is not a server-side gate — `--no-verify` bypasses it and a fresh clone does not have it
until that config is set. It earns its place on **latency**: it fails in seconds rather than
after a push, a CI queue and a round trip. For an agent working in a loop that is the
difference between a tight loop and a slow one.

## Writing a new check

1. **Whole words, not substrings.** `banned-terms` once failed on `Get-ChildItem` because
   "child" is a substring of "ChildItem". A check that cries wolf is a check that gets
   switched off.
2. **Say which rule failed and what to do**, not just that something failed.
3. **Exit 1 on failure, print `ok <name>: …` on success.** Silence reads as "did not run".
4. **Escapes are per line and visible in the diff** — `<!-- allow-term: why -->`. Never a
   blanket directory exclusion.
5. **Prove both directions before committing it.** A check that has only been seen to pass
   has not been tested.
