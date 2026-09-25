---
authority: claude-writes
---

# checks/

The **caught** tier. Blocked things live in `hooks/`; explained things live in `rules/` and
`spec/`. See `rules/WORKING-METHOD.rule.md` for why the tiers exist.

A check blocks the merge when it runs in CI, and refuses the push when it runs in the
pre-push hook. It reads the contract as **data**, never as instructions. Six run in CI
(`.github/workflows/checks.yml`); three run only in the hook until the workflow is
extended (O-42).

## The checks

| Check | Fails when | Runs in |
|---|---|---|
| `router-size.check.sh` | `CLAUDE.md` exceeds 150 lines | CI, hook |
| `router-links.check.sh` | `CLAUDE.md` references a path that does not exist | CI, hook |
| `router-orphans.check.sh` | A contract file exists that nothing routes to | CI, hook |
| `frontmatter.check.sh` | A contract file has missing or invalid `authority:` | CI, hook |
| `banned-terms.check.sh` | A banned term appears outside the files that define it | CI, hook |
| `authority.check.sh` | A Claude-authored commit touches a `george-only` file | CI |
| `secrets.check.sh` | Anything that looks like a credential is committed | hook only |
| `versions.check.sh` | `ops/VERSIONS.ops.md` disagrees with what is actually pinned | hook only |
| `naming.check.sh` | A contract file is named outside the convention | hook only |

## Not one of the nine

`skeleton.test.mjs` is a **spec test**, not a gate. It reads Migration 0001 and 0002 out of
`spec/DATA-MODEL.spec.md` and applies them to an embedded PostgreSQL, so the spec's own
*Evidence* section can be reproduced after a merge rather than quoted from a pull request.
It is not in CI and not in the hook, because it needs PGlite, which is test-only and is
never installed into this repo (D-084 — the install goes in the developer's scratch folder):

```
cd <scratch folder> && npm install --save-exact @electric-sql/pglite@0.3.16
cd <repo> && PGLITE_DIR=<scratch folder> node checks/skeleton.test.mjs spec/DATA-MODEL.spec.md
```

## The two that matter most

**`router-orphans.check.sh`** — a contract file nothing routes to is not merely unread.
[likely] After a context compaction it is unreachable, because only the root file is
re-read and re-injected.

**`secrets.check.sh`** — [certain] a secret in git history is permanent. Rotation is the
only remedy. This check is the backstop; `hooks/guard-write.mjs` is the control.

## Where else these run

`.githooks/pre-push` runs the same eight checks before a push leaves the machine, and
refuses it on any failure. It is a POSIX `sh` shim that finds bash (on `PATH`, then
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
