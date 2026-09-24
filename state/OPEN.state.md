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

## Brief B-001 — for the developer: the billing kill switch

From the project manager, 24 Sep. Developer: Claude Code on George's PC (D-069). Authorised
by D-070 — the one time an agent writes the kill switch. Closes O-28 when applied.

1. **Set up the seat.** Run `node --version`, `git --version` and
   `git config core.hooksPath .githooks` (closes O-35). Paste all three outputs in the PR.
   Then, in `.claude/rules/infra.md` under *Never*, replace the kill-switch bullet with
   (D-070): "**Touch billing configuration or the kill switch** — except its first version,
   written once under D-070 for George to review. The kill switch is the one control that
   stops an unbounded loss, so once it exists it is the one thing an agent must not be able
   to modify."
2. **Write `infra/bootstrap/`** (D-064; file names in `spec/DATA-MODEL.spec.md`,
   *Files and names*): a Cloud Billing budget on the account attached to `fetchpep-dev`,
   notifying a Pub/Sub topic; a function subscribed to it that detaches billing from
   `fetchpep-dev` when actual cost passes the budget. Every location `europe-west2` (D-043);
   names use the codename. Least privilege for the function's service account
3. **Leave the money to George.** The amounts and the billing account id are required
   variables with no default. George set the amounts in D-071: an email past 10, detach past
   30, in the billing account's own currency (leave the currency unset). Say in the PR whether
   the budget counts cost before or after credits, and why. No secret in any file
4. **A dry-run switch.** The function takes a setting that logs "would detach" instead of
   detaching, so the first test cannot switch billing off
5. **Pin versions** (`ops/VERSIONS.ops.md`, rule 1): exact provider versions, commit
   `.terraform.lock.hcl`, fill the Terraform row. Run `terraform fmt -check` and
   `terraform validate` (the extracted binary in Downloads until O-34 closes)
6. **Open a PR. Never apply** (D-067). Anything here you disagree with: D-069 — stop, push back

**Proven when:** the reviewer passes the PR against this brief; George merges; operations
applies in Cloud Shell with George signed in; a test budget notification in dry-run mode
produces the "would detach" log line; then dry-run is switched off by George.

## Blocking any infrastructure at all

Ordered. Nothing below moves until the item above it does.

- **O-50 to O-53 · resolved 24 Sep by D-062 to D-065.** Game logic in Nakama; PostgreSQL
  on the VM; HCP Terraform with one Cloud Shell bootstrap; Cloudflare Tunnel and R2

**O-54 · Nakama's own tables, or ours.** D-063 puts one PostgreSQL on the VM. Nakama
creates and migrates its own tables; the seam (D-051) and the append-only ledger need real
SQL tables. Proposed: Nakama's tables for accounts and sign-in only; `directory` and
`shard_gi` for all game data, written from the TypeScript modules. Verify how the
TypeScript runtime reaches SQL before relying on it.

**O-55 · How game identity gets into the game.** `spec/DATA-MODEL.spec.md` puts game
identity in `directory`; Nakama keeps its own accounts. D-054 gives every steward and
member a login; the steward is age-checked on the website; D-066 says nothing live between
them. Options: through the publish door in batches, or a sign-in both sides share. With O-47.

**O-56 · A fold on both sides of the seam.** A fold is the leaf of the place tree in
`directory.place` (D-053), and `spec/DATA-MODEL.spec.md` also puts folds in `shard_*`. No
joins across the seam (D-051), so one is the record and the other refers to it by ID only.

**O-58 · The game API's hostname.** D-065 needs a hostname on a domain whose DNS is on
Cloudflare. Only `art.inkfold.game` exists, and that is a bundle identifier (D-049), not a
domain anyone owns yet.

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
**Update, 24 Sep:** D-072 moves the apply to before the game goes public. During the pilot
the guard is George's existing budget alerts, which warn and do not stop spend. The code is
PR #9. This item closes when the kill switch is applied before launch, not before the VM.

**O-34 · Terraform CLI is extracted, not installed.**
`terraform.exe` sits loose in `Downloads\terraform_1.16.4_windows_amd64\`. It is not on
`PATH`, so `terraform` resolves from no shell. Only needed for local `plan`; HCP Terraform
runs remotely. Not a blocker, but `ops/VERSIONS.ops.md` records a version that no command
can currently confirm.

## Blocking the first build

- **O-20 · Claude Code on the Windows PC — seat decided 24 Sep by D-069.** The Claude desktop
  app on George's PC, in the repo folder. Closes when the first session reports
  `node --version` and `git --version` (brief B-001, step 1)
- **O-43 · Node on the PC — installed 24 Sep** (`C:\Program Files\nodejs`), with Git for Windows.
  Closes when a Claude Code session shows `node --version`: the write hook depends on it
- **O-44 · resolved 24 Sep by D-055.** Nakama on a VM in London for the pilot. The Heroic
  Cloud account George created (org `fetchpep-studio`, title `inkfold`) stays unused —
  D-060, O-49
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
- **O-36 · resolved 24 Sep by D-068.** `infra/` is `claude-proposes` in `CLAUDE.md` section 6
- **O-37 · resolved 24 Sep by D-068.** Section 9 states six checks in CI and three in the hook;
  section 4 reads "global/shard seam" and "Folds, places"
- **O-38 · `rules/` teaches retired vocabulary.** `LANGUAGE.rule.md` lists **region** as a
  game term (D-051 removes it). `NON-NEGOTIABLES.rule.md` says attribution is "by name and
  place" (D-056 makes it tag and place). `george-only`
- **O-39 · resolved 24 Sep by D-068.** `api-seam.md` (`shard_*`, no submissions, applies only
  to a website Core API), `nakama.md` (adding shards; migrations route to the data model) and
  `infra.md` rule 4 (EU or UK) updated. The remote tools cannot write under `.claude/`; George
  placed the files (commit `d8e789d`)
- **O-41 · Crash reporting — resolved 24 Sep by D-059.** Unity's built-in Diagnostics,
  Unity 6.2 or later
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
- **O-49 · The Heroic Cloud account holds a payment card and is not in the stack.** On 24
  Sep George added card details after Heroic Labs' documentation links led to its sign-up
  pages; no plan was started. An unused account with a card is a cost risk until closed.
  George removes the card or closes the account. **Evidence to close:** the billing page
  showing no plan and no card
- **O-57 · Data held outside the UK and EU.** `spec/PRIVACY.spec.md` says data stays in the
  UK or EU. Unchecked: where Unity Diagnostics keeps crash reports (D-059) and where HCP
  Terraform keeps state (D-064). R2 gets EU jurisdiction at creation (D-065)
- **O-59 · PRIVACY's reason for keys in Cloud KMS cites Neon.** It says Neon's restorable
  history would bring a deleted key back. Under D-063 the VM's disk snapshots do the same, so
  the conclusion holds and the reason needs rewording. `claude-proposes`
- **O-60 · Steward controls into the game, reports out.** The visitor lock, fold membership,
  blocks and phone pairing are set on the website; a report filed in the game must reach a
  person. D-066 says nothing live between them, and a release batch is too slow for a lock.
  Proposed: a second server-to-server door, `apply_control`, logged in `directory.door_log`.
  Needs a decision, because it is a live call from the website into the game
- **O-61 · Sign-in: the picker or a login.** D-054 gives every member a login; the App
  Shell's "Who's playing" picker assumes members have none (O-48, O-47)
- **O-62 · Specimen names are free text.** The only text a member types that others might
  see. No moderation path exists in the game. Options: names private to the fold, a word
  list, or a check. `shard_gi.specimen_name.status` is ready for whichever
- **O-63 · Who is credited when a creature is fed or kept.** D-058 gives every creature an
  artist and a creator. The proposed skeleton records both at the time of the feed
- **O-64 · resolved 24 Sep by D-068.** `services/` and `infra/` are `claude-proposes`;
  `services/nakama/migrations/` routes to `spec/DATA-MODEL.spec.md` through `nakama.md`
- **O-65 · Play the skeleton does not model yet.** Things built on the land, where encounters
  sit on the map, weather, fair days, avatar pieces unlocked by play, where NPCs stand
- **O-66 · Retention against D-066.** D-066 keeps every statistic for the website to copy;
  `spec/PRIVACY.spec.md` proposes aggregating raw gameplay events after 90 days. Reconcile
  before the first real player
- **O-17** · The Inkfold design system README groups `FetchPep` with two retired terms as
  things not to copy. Two stay banned; `FetchPep` is now the live codename and must be
  split out of that line
