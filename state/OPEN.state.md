---
authority: claude-writes
---

# Open

Unresolved, ordered by what they block. Resolved items stay, annotated with the date and
the evidence, until they are moved to `state/SESSION-LOG.state.md`.

## Blocking everything

**O-1 · Build one creature by hand and time it.**
Top of the list since the first plan. Needs a sprite editor and an afternoon — no toolchain,
no accounts, no device. It is the only number that says whether the product works at any
scale. Forty minutes is a business. Four hours means the content pipeline is the product
and much of the specified architecture is solving the wrong bottleneck.

Untouched on 24 Sep while the repo, CI, ruleset, secret protection, two GCP projects and an
HCP Terraform organisation were all stood up. Every one of those is reversible in an
afternoon. O-1 is the only item that can invalidate the architecture, and it is the only
one nobody has started.

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

## Blocking any infrastructure at all

Ordered. Nothing below moves until the item above it does.

**O-31 · HCP Terraform has no VCS provider.**
Checked 24 Sep at `app.terraform.io/app/fetchpep/settings/version-control` — *"There are no
VCS providers configured in this organization"*. The organisation `fetchpep` exists and is
Terraform standalone. **This contradicts a belief held in conversation that GitHub was
already linked**; signing in to HCP Terraform *with* a GitHub account is a different thing
from connecting GitHub as a VCS provider, and only the second one makes runs happen on a
pull request. Connecting it is an OAuth grant against the GitHub account and is George's to
approve.

**O-32 · There is no `infra/` directory and no `.tf` file.**
`.claude/rules/infra.md` routes on `infra/**/*.tf`. Nothing matches it, so the rule has
never fired. A workspace created today would have nothing to plan.

**O-29 · HCP Terraform apply method — cannot be verified, because there is no workspace.**
Checked 24 Sep at `app.terraform.io/app/fetchpep/workspaces` — *"Add your first
workspace"*. The item was written as a verification; it is actually a setup step. It
becomes a verification the moment a workspace exists, and the check is unchanged: Workspace
→ Settings → General → Apply Method must read **Manual apply**, because an auto-apply
workspace connected to the repo would provision real infrastructure on merge with nobody
clicking, which `CLAUDE.md` section 2 forbids.

**O-28 · Billing kill switch does not exist, and billing is now attached.**
Confirmed attached to both projects, 24 Sep. `ops/COSTS.ops.md` says the kill switch is
built before anything that can cost money. The only failure mode in this system with no
ceiling currently has no control in front of it. It is Terraform resource number one — and
it is behind O-31 and O-32, which is the actual reason this is urgent rather than tidy.

**O-34 · Terraform CLI is extracted, not installed.**
`terraform.exe` sits loose in `Downloads\terraform_1.16.4_windows_amd64\`. It is not on
`PATH`, so `terraform` resolves from no shell. Only needed for local `plan`; HCP Terraform
runs remotely. Not a blocker, but `ops/VERSIONS.ops.md` records a version that no command
can currently confirm.

## Blocking the first build

- **O-20 · Claude Code on the Windows PC.** The build seat. Nothing in Phases 1 to 4 is
  reachable without it. Still never opened on the repo as of 24 Sep.
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

- **O-27** · **Transfer the repo to an organization**, if still wanted. The transfer changes
  the repo URL and the git remote. Cheap now — no Unity project, no LFS history. Expensive
  later
- **O-21 · Branch protection — resolved 24 Sep.** [certain] GitHub does not enforce
  rulesets *or* classic branch protection on a **private** repository on the free plan.
  Resolved by making the repo public rather than by paying: a ruleset on `main` is Active,
  bypass list empty, requiring a pull request and the `contract` status check. **Evidence:**
  on PR #1 both `contract / contract (pull_request)` and `contract / contract (push)` are
  labelled **Required** by GitHub, which is the first proof the ruleset binds rather than
  merely appearing in settings.
- **O-30 · Secret scanning and push protection — resolved 24 Sep.** Both enabled at
  Settings → Advanced Security → Secret Protection. **Evidence:** the section's control now
  reads *Disable*, and Push protection's reads *Disable push protection*. [certain]
  Server-side, so unlike `.githooks/pre-push` it cannot be bypassed with `--no-verify`.
  This item was named in the PR #1 description as having been added to this file. It had
  not been. Recorded here rather than quietly corrected.
- **O-35 · `.githooks/pre-push` has never run.** It is committed, but `core.hooksPath` is
  not set in the working copy, so GitHub Desktop pushed straight past it. One command in
  the repo root: `git config core.hooksPath .githooks`. Until then the hook is documentation.
- **O-36 · `infra/` has no declared write authority.** `CLAUDE.md` section 6 lists `rules/`,
  `spec/`, `ops/`, `state/`, `checks/` and `hooks/`. It does not list `infra/`. Terraform is
  the one directory in this repo where a Claude write can spend money, and it is the one
  directory with no authority row. `CLAUDE.md` is `george-only`.
- **O-17** · The Inkfold design system README groups `FetchPep` with two retired terms as
  things not to copy. Two stay banned; `FetchPep` is now the live codename and must be
  split out of that line
