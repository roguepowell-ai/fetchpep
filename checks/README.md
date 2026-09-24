---
authority: claude-writes
---

# checks/

The **caught** tier. Blocked things live in `hooks/`; explained things live in `rules/` and
`spec/`. See `rules/WORKING-METHOD.rule.md` for why the tiers exist.

A check runs in CI on every push and blocks the merge. It reads the contract as **data**,
never as instructions.

## The checks

| Check | Fails when |
|---|---|
| `router-size.check.sh` | `CLAUDE.md` exceeds 150 lines |
| `router-links.check.sh` | `CLAUDE.md` references a path that does not exist |
| `router-orphans.check.sh` | A contract file exists that nothing routes to |
| `frontmatter.check.sh` | A contract file has missing or invalid `authority:` |
| `banned-terms.check.sh` | A banned term appears outside the files that define it |
| `authority.check.sh` | A Claude-authored commit touches a `george-only` file |
| `secrets.check.sh` | Anything that looks like a credential is committed |
| `versions.check.sh` | `ops/VERSIONS.ops.md` disagrees with what is actually pinned |
| `naming.check.sh` | A contract file is named outside the convention |

## The two that matter most

**`router-orphans.check.sh`** — a contract file nothing routes to is not merely unread.
[likely] After a context compaction it is unreachable, because only the root file is
re-read and re-injected.

**`secrets.check.sh`** — [certain] a secret in git history is permanent. Rotation is the
only remedy. This check is the backstop; `hooks/guard-write.mjs` is the control.

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
