---
authority: claude-writes
---

# Open

Unresolved, ordered by what they block.

## Blocking everything

**O-1 · Build one creature by hand and time it.**
Top of the list since the first plan. Needs a sprite editor and an afternoon — no toolchain,
no accounts, no device. It is the only number that says whether the product works at any
scale. Forty minutes is a business. Four hours means the content pipeline is the product
and much of the specified architecture is solving the wrong bottleneck.

**O-18 · The specs do not exist.**
`spec/` holds eight placeholders. Product, identity, brand, design, data model, places,
encounters and screening were worked out in conversation and were never written to any
store. They are not recoverable from a file. Each has to be written from scratch or
re-decided.

**O-19 · The decision log is unrecoverable.**
D-001 to D-032 exist in conversation only. `state/DECISIONS.state.md` section 2 lists the
IDs the rules files cite; each needs confirming or deleting. Until then several rules are
citing nothing.

## Blocking the schema

**O-22 · Erasure versus the immutable ledger.**
The ledger is append-only by database rule. Gibraltar GDPR includes a right to erasure.
These conflict. `spec/PRIVACY.spec.md` proposes the standard resolution — the ledger holds
an opaque subject id, the mapping to a person lives once in `directory`, and erasure severs
the mapping — but it is **proposed, not decided**, and it has to be in the first migration.
It cannot be retrofitted, because retrofitting means rewriting an append-only table.

**O-24 · Lawful basis.**
Not settled and not Claude's to settle. Needed before any personal data is collected.

## Blocking nothing yet, but cheap now

**O-23 · Tripwire thresholds.**
`ops/SCALING.ops.md` has five `TBD` rows. Each needs a measured number, not an estimate.
The one that matters is time-to-build-one-creature, which is O-1.

**O-25 · Four security rules are prose only.**
R-SEC-02 (never trust a client claim), R-SEC-03 (uploads are hostile), R-SEC-06 (logs are a
data store) and R-SEC-07 (never hold verification data) have no check behind them, so they
have the failure rate prose has. They become enforceable when there is code to check.

**O-26 · `rules/` needs the R-SEC pointers.**
`spec/SECURITY.spec.md` is canonical, but `rules/NON-NEGOTIABLES.rule.md` does not point at
it. `rules/` is `george-only`, so Claude proposed and George applies. Text in the session
log for 24 Sep.

## Blocking the world map

- **O-2 · Q43 — does infrastructure say `region` or `shard`?** Free today, expensive once
  Terraform and the schema exist.
- **O-3 · D-035 — resolved 24 Sep.** Two environments, two GCP projects, both created
- **O-29 · HCP Terraform apply method unverified.** [likely] workspaces default to manual
  apply, but with the repo connected an auto-apply workspace would provision real
  infrastructure on merge with nobody clicking — which `CLAUDE.md` section 2 forbids.
  Workspace → Settings → General → Apply Method must read **Manual apply**
- **O-28 · Billing kill switch does not exist.** `ops/COSTS.ops.md` says it is built before
  anything that can cost money. Two GCP projects now exist. If billing is attached to
  either, the only failure in this system with no ceiling has no control in front of it

## Blocking the first build

- **O-20 · Claude Code on the Windows PC.** The build seat. Nothing in Phases 1 to 4 is
  reachable without it. Expected at the weekend.
- **O-4 · Is there an iPhone?** Without one the TestFlight gate is unreachable.
- **O-5 · Android test device.** Not bought. Physical supply chain plus a customs question.
- **O-6 · Apple Developer enrolment.** Failed once on a restricted network, cause unknown.

## Verifications — free, each can invalidate part of the plan

- **O-8** · Apple paid-app territories — is Gibraltar supported?
- **O-9** · Unity Personal revenue threshold; Build Automation free allocation
- **O-10** · Gibraltar-issued card accepted by Apple, Google, Unity?
- **O-11** · Gibraltar import duty on electronics
- **O-12** · Does a Unity Personal `.ulf` activate on GameCI Linux runners under Unity 6?
  Prove on a hello-world project first

## Permanent from first upload

- **O-13** · Bundle identifier. Proposed `art.inkfold.game`. Cannot be changed
- **O-14** · Keystore and certificate backup policy. Two backups, one offline, day one

## Housekeeping

- **O-21** · Branch protection on `main`. **Corrected 24 Sep:** [certain] GitHub does not
  enforce rulesets *or* classic branch protection on a **private** repository on the free
  plan — both settings pages carry the banner, and a rule created there appears in settings
  while blocking nothing. An imagined control is worse than a missing one. Resolved by
  moving to GitHub Team (~£4/month). Until that lands, `.githooks/pre-push` is the
  substitute: local, fast, bypassable with `--no-verify`
- **O-27** · **Transfer the repo to an organization.** GitHub Team is an org plan and
  `roguepowell-ai` is a personal account. The transfer changes the repo URL and the git
  remote. Cheap now — two commits, no Unity project, no LFS history. Expensive later
- **O-17** · The Inkfold design system README groups `FetchPep` with two retired terms as
  things not to copy. Two stay banned; `FetchPep` is now the live codename and must be
  split out of that line
