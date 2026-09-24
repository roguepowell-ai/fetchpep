---
authority: claude-writes
---

# Open

Unresolved, ordered by what they block. Resolved items stay, annotated with the date and
the evidence, until they are moved to `state/SESSION-LOG.state.md`.

## Blocking everything

**O-18 · The specs do not exist.**
`spec/` holds eight placeholders; `PRODUCT`, `DATA-MODEL` and `PLACES` became partly written
on 24 Sep from George's decisions and his `place_kind` schema. Product, identity, brand, design, data model, places,
encounters and screening were worked out in conversation and were never written to any
store. They are not recoverable from a file. Each has to be written from scratch or
re-decided.

**O-19 · The decision log is unrecoverable.**
D-001 to D-032 exist in conversation only. `state/DECISIONS.state.md` section 2 lists the
IDs the rules files cite; each needs confirming or deleting. Until then several rules are
citing nothing.

## Blocking the schema

- **O-22 · Erasure versus the immutable ledger — resolved 24 Sep by D-044**, crypto-shredding.
  Key location proposed in `spec/PRIVACY.spec.md`: Cloud KMS, because Neon's restorable
  history would bring a deleted key back.

**O-24 · Lawful basis.**
Not settled and not Claude's to settle. Needed before any personal data is collected. The
same conversation with a lawyer should cover D-056 — whether a creature may stay after its
maker asks to be erased — and whether a **self-chosen** tag, which can identify its maker,
is allowed at all.

**O-40 · Website: the original photograph.** For the website's own spec, not the game's.
D-025 keeps each submitted original untouched; George's 26 Aug data model stores it "EXIF
stripped, auto-cropped before write". One has to give.

## Blocking launch content

**O-1 · Build one creature by hand and time it.** *Reframed 24 Sep by D-058.*
The pilot's creatures are seeded, built by hand by Joshua. How long one takes sets how many
creatures the pilot world can hold. Needs a sprite editor and an afternoon.

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

- **O-2 · Q43 — resolved 24 Sep by D-051.** The game has no regions. The shared instance is
  a shard, schemas `shard_*`; *region* means a cloud location only
- **O-45 · Where does a `custom` map sit in the place tree?** D-053 lists the kind; its
  parent is not recorded. `ltree` needs exactly one
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
- **O-43 · Is Node on the PC's `PATH`?** Never checked. `.claude/settings.json` runs
  `node hooks/guard-write.mjs` for every write; without Node the whole blocked tier does
  nothing. Check the moment Claude Code opens
- **O-44 · resolved 24 Sep by D-055.** Nakama on a VM in London for the pilot. The Heroic
  Cloud account George created (org `fetchpep-studio`, title `inkfold`) stays unused
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

- **O-13 · resolved 24 Sep by D-049.** `art.inkfold.game`
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
- **O-37 · `CLAUDE.md` says things that are no longer true.** Line 147: *"Nine checks run
  on every push and block the merge"* — CI runs six (O-42). Section 4 routes on "the
  global/regional seam" and "Folds, regions, the world map"; under D-051 those read
  "global/shard seam" and "Folds, places, the world map". It also needs the `infra/` row
  (O-36). `george-only`: Claude proposes the text, George applies it
- **O-38 · `rules/` teaches retired vocabulary.** `LANGUAGE.rule.md` lists **region** as a
  game term (D-051 removes it). `NON-NEGOTIABLES.rule.md` says attribution is "by name and
  place" (D-056 makes it tag and place). `george-only`
- **O-39 · `.claude/rules/` is out of date and cannot be written remotely.** `api-seam.md`
  says `region_*` and lists submissions in `directory` (D-051, D-052); `nakama.md` says
  "sharding on region"; `infra.md` rule 4 says EU only (D-043 is London). Apply from the
  first Claude Code session
- **O-41 · Crash reporting — Unity's own tooling or Sentry.** D-042 removed Crashlytics.
  Needed before the first build anyone else runs
- **O-42 · CI runs six of the eight checks.** `secrets`, `versions` and `naming` exist only
  in `.githooks/pre-push`, which has never run (O-35), so they gate nothing. Wiring them in
  is a workflow edit — execution-granting, so it cannot be written remotely
- **O-46 · D-039 against reality.** D-039, George's, says the repo lives at `C:\dev\fetchpep`
  and nothing goes in a cloud-synced folder. The working copy is under
  `C:\Users\laure\OneDrive\Desktop\`, and on 24 Sep George said sync is off for it and the
  note about it could go. Either D-039 is superseded (the current path stands) or the repo
  moves before a Unity project exists. George's call; free now
- **O-47 · Sign-in methods.** D-054 says the steward and every member have their own login.
  Which method each uses is open: the 26 Aug data model says Apple or Google for both; the
  design boards show the steward on email and password and members picking their name on a
  shared phone
- **O-48 · The design boards predate today's decisions.** The Atlas board says "Region —
  Cornwall" and the design system README lists *region* as vocabulary (D-051 retires it); the
  App Shell's "Who's playing" picker assumes members have no login (D-054 gives them one).
  The boards live in the Inkfold design system, which is George's to edit
- **O-17** · The Inkfold design system README groups `FetchPep` with two retired terms as
  things not to copy. Two stay banned; `FetchPep` is now the live codename and must be
  split out of that line
