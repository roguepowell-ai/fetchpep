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

**O-73 · The write guard covers the Edit and Write tools, not Bash.**
[certain] `hooks/guard-write.mjs` line 20 reads
`const WRITE_TOOLS = new Set(["Write", "Edit", "MultiEdit", "NotebookEdit"])`, and every
later check returns early for any other tool. A file changed with `sed`, a heredoc or any
other shell command through the Bash tool is not seen by the guard, so the blocked tier
(`CLAUDE.md` section 8) does not apply to it — banned terms, `george-only` files and Unity
YAML are then caught only by CI and the pre-push hook. Found on PR #17, where the developer
edited files with Bash. **Until it is fixed, file changes go through the Edit and Write
tools only.** A fix means matching on Bash commands as well, which is a decision: a guard
that parses shell has its own failure mode, and refusing every write-shaped Bash command
would stop ordinary work.

**Update, 25 Sep — a second, separate hole, found and closed.** The guard was also broken by
the *working directory*, which is not the same bug and had nothing to do with Bash.
`.claude/settings.json` ran it as `node hooks/guard-write.mjs`, a relative path, so from any
subdirectory the hook failed to load — and [certain] Claude Code treats a hook that exits 1
as a non-blocking error, so **every write was allowed**. Inside the hook, two more things
were relative to the working directory. Measured from `infra/dev` against the version on
main: a `george-only` file was still **blocked** (the `rules/` prefix test failed but the
frontmatter arm reads the absolute path and caught it), and a **banned term was allowed**,
because the word list was opened by a relative path, was not found, and an empty list
matches nothing. Fixed in PR #20: the command uses `$CLAUDE_PROJECT_DIR`, and the hook
anchors on its own location instead of `process.cwd()`. Proven from four working
directories, one of them outside the repo. O-73 itself — that Bash writes are not seen at
all — stands.

**O-74 · `services/nakama/build/index.js` is committed and nothing checks it matches `src/`.**
Nakama loads one JavaScript file. The VM has no build step and there is no image registry
of ours (the kill switch's Artifact Registry repository is the kill switch's, D-070), so
`infra/dev/vm_nakama.tf` reads the built file with `file()` and delivers it in instance
metadata. That works and is reproducible — `tsconfig.json` lists its inputs in order rather
than globbing, so the same sources give the same bytes — but nothing stops someone editing
`src/` without rebuilding, and the VM would then run the older module with no sign of it.
Proposed check: run `npm run build`, fail if `git diff --exit-code build/` is non-empty. It
is a new gate, and promoting a rule up a tier is itself a decision
(`rules/WORKING-METHOD.rule.md`), so it needs an ID. The alternatives are both bigger: build
on the VM at boot, or push an image to Artifact Registry and pull it.

**O-75 · The two migrations now exist in two places.**
`spec/DATA-MODEL.spec.md` holds them as fenced SQL and `services/nakama/migrations/` holds
them as files. Brief #13 says to take the files from the spec, and they were extracted with
the same reader `checks/skeleton.test.mjs` uses, so today they are equal. Nothing keeps
them so. If they drift, the spec test proves one thing and the VM runs another. Same shape
as O-74 and the same cost: a check is a tier promotion and needs an ID. The other way out is
for the spec to point at the files instead of carrying the SQL — a bigger edit than it
sounds, because the spec's *Evidence* section reads the SQL out of itself.

**O-76 · `directory.door_log` cannot record the outcome it defines.**
`outcome` allows `'duplicate'`, and `idempotency_key` is `UNIQUE`. A second call under a key
already used therefore cannot be written at all — the index refuses the insert before the
outcome matters. `publish_release` handles it by reading the first call back and returning
`duplicate` to the caller without writing, which is the right behaviour and leaves the
`'duplicate'` value unreachable. One of the two should go: the outcome, or the unique index
in favour of one that allows repeats. Found building #13. Schema, so
`spec/DATA-MODEL.spec.md`, and a migration if it changes.

**O-77 · Where `invite-email-hmac-key` lives.**
`spec/DATA-MODEL.spec.md` names five Secret Manager secrets and leaves this one's home to
the VM brief. Brief #13 asks for four, and the four are built. The fifth is different in
kind: D-080 has the website compute the HMAC of an invited address and the game compute the
same HMAC at sign-in, so both sides need the same key — and there is no website, no decision
about where it runs, and no Cloudflare account (`ops/INFRA.ops.md`). A secret with one
holder and no second holder cannot have its sharing designed yet. Asked on issue #13.

**O-78 · Docker Hub is an unauthenticated dependency between a reboot and a running game.**
The VM pulls `heroiclabs/nakama:3.40.0` and `postgres:16.15` from Docker Hub at boot,
through Cloud NAT, with no account. [certain] Docker Hub rate-limits anonymous pulls by IP.
A reboot in a busy hour can fail to start the service, and the failure reads as a broken VM
rather than as a quota. Both tags are exact, so what is at risk is availability, not what
gets run. The fix is to mirror both images into Artifact Registry in `fetchpep-dev` and pull
from there: a new repository, a new cost line and a decision, so not in #13.

**O-79 · What `infra/dev` cannot prove without an apply.**
The developer never applies (D-067), so five things in PR #20 are reasoned from
documentation rather than seen working. Listed here so the first apply is read as a test
rather than a formality, and so a failure is recognised instead of debugged from scratch:
1. **`/var` is `noexec` on Container-Optimized OS** [certain, from the CIS benchmark for
   COS], so the Compose binary gets `app_dir/bin` its own `mount --bind` plus
   `remount,exec`. The startup script runs `docker-compose version` straight afterwards and
   exits with the mount options in the log if it did not take. Unproven until a VM boots.
2. **The apply runner's role set.** Nine roles and a custom one, chosen narrow on purpose.
   A missing permission fails the apply with the permission named. The fix is another named
   role, never `roles/editor`.
3. **The Secret Manager service agent.** `secrets.tf` grants
   `service-<number>@gcp-sa-secretmanager.iam.gserviceaccount.com` publisher on the rotation
   topic by its well-known address. [likely] The agent is created when the API is first
   enabled; if the binding is refused because it does not exist yet, the fix is to enable
   the API, wait, and re-apply.
4. **Instance metadata size.** Seven files go up as metadata, the two migrations being most
   of it — about 55 KB against a 256 KB limit per key and 512 KB in total. Comfortable, but
   it is a ceiling that grows with every migration, and migration 0003 is already coming
   (D-091).
5. **The HCP Terraform workspace's working directory** must be `infra/dev` with the whole
   repository uploaded, because `vm_nakama.tf` reads `../../services/nakama/...`. Written up
   in `ops/RUNBOOK.ops.md` Part 5, step 20.

**O-80 · Rotation notices go to a topic nothing listens to.**
D-089 gives every secret a rotation period. [certain] Secret Manager's rotation does not
create a version — it publishes a notice to `fetchpep-dev-secret-rotation` saying one is
due, and the rotation itself is the procedure in `ops/RUNBOOK.ops.md` Part 5, run by a
person. Nothing is subscribed to that topic, so the notice reaches nobody: the schedule
currently records an intention rather than prompting anyone. Same shape as O-70, where a
kill-switch error only shows in a log. Both want a notification channel, which wants an
email address in Terraform, which is one decision covering both.

## Blocking the world map

- **O-2 · Q43 — resolved 24 Sep by D-051.** The game has no regions. The shared instance is
  a shard, schemas `shard_*`; *region* means a cloud location only
- **O-45 · Where does a `custom` map sit in the place tree?** D-053 lists the kind; its
  parent is not recorded. `ltree` needs exactly one
- **O-3 · D-035 — resolved 24 Sep.** Two environments, two GCP projects, both created

## Brief B-001 — for the developer: the billing kill switch

From the project manager, 24 Sep. Developer: Claude Code on George's PC (D-069 — the seat
moved to Claude Code CLI in Cloud Shell on 25 Sep, D-085). Authorised
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

**Status, 24 Sep:** built on branch `kill-switch-b001`, not applied; per D-072, applied
before the game goes public. PR #9, opened by operations (the PR page reads *Open*). The
first review returned *changes needed*, fixed in `ada344a`; the second returned *pass with
changes*, fixed in `7d46cc1`; the third returned *pass with changes*, wording only, fixed in
the commit that adds the last row of the table below. Merge is George's. Outputs from the
developer's session:

```
node --version                   v24.21.0
git --version                    git version 2.55.0.windows.5
git config core.hooksPath        .githooks
```

`terraform fmt -check -recursive` and `terraform validate` ran three times, each on a known
tree:

| Ran on | `fmt -check` | `validate` |
|---|---|---|
| `ada344a`, checked out with `infra/` equal to HEAD (`git diff --quiet HEAD -- infra`) | no output, exit 0 | `Success! The configuration is valid.` exit 0 |
| `7d46cc1`: `kill_switch.tf` blob `d85fb0c`, `versions.tf` blob `de0e78d`, `.terraform.lock.hcl` blob `f7fe153` | no output, exit 0 | `Success! The configuration is valid.` exit 0 |
| The commit that adds this row: `kill_switch.tf` blob `40496fa`, `versions.tf` blob `de0e78d`, `.terraform.lock.hcl` blob `f7fe153` | no output, exit 0 | `Success! The configuration is valid.` exit 0 |

A commit cannot name its own hash, so the rows after the first name the blobs. To check,
`git rev-parse <commit>:infra/bootstrap/kill_switch.tf` must start with the blob in that
row, and likewise for the other two. `infra/` is unchanged between `ada344a` and `69c67b0`
(George's merge of `main` and D-073/D-074), so the first row also covers `69c67b0`.

`terraform` is `Downloads\terraform_1.16.4_windows_amd64\terraform.exe`, run in
`infra/bootstrap/` after `terraform init -backend=false` (O-34).

## Blocking any infrastructure at all

Ordered. Nothing below moves until the item above it does.

- **O-50 to O-53 · resolved 24 Sep by D-062 to D-065.** Game logic in Nakama; PostgreSQL
  on the VM; HCP Terraform with one Cloud Shell bootstrap; Cloudflare Tunnel and R2

**O-54 · Nakama's own tables, or ours — resolved 24 Sep by D-079 (split); the last part
verified 25 Sep.** Nakama holds
accounts, sign-in and sessions; all game data lives in `directory` and `shard_gi`. What
D-079 carried to the VM brief — that the TypeScript runtime can write to those tables — is
now proven, on Nakama 3.40.0 against PostgreSQL 16.15. **Evidence** (brief #13, in the PR):
the module logs `fetchpep: module loaded, 2 migration(s) applied` at start, which is a
`nk.sqlQuery` against `directory.schema_migration`; `publish_release` wrote a release, a
phase, a species, a coat and a `directory.door_log` row in one statement and returned
`{"outcome":"applied",…,"door_log_id":1}`; `read_catalogue` read them back. The three
schemas sit side by side in one database — `public` 20 tables (Nakama's own),
`directory` 20, `shard_gi` 23. The original item: D-063 puts one PostgreSQL on the VM. Nakama
creates and migrates its own tables; the seam (D-051) and the append-only ledger need real
SQL tables. Proposed: Nakama's tables for accounts and sign-in only; `directory` and
`shard_gi` for all game data, written from the TypeScript modules. Verify how the
TypeScript runtime reaches SQL before relying on it.

**O-55 · How game identity gets into the game — resolved 24 Sep by D-080 (invite by
email), through the D-081 door.** Phone pairing is no longer part of it (D-076). Sign-in
methods stay open as O-47. The original item: `spec/DATA-MODEL.spec.md` puts game
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

**O-32 · resolved.** `infra/bootstrap/` holds `versions.tf`, `kill_switch.tf` and, since
brief #13, `workload_identity.tf` — the trust setup B-001 left out. `infra/dev/` holds the
network, the VM, the snapshot schedule, the secret containers and their inputs and outputs.
Nothing is applied: both stacks are Manual apply and the apply is operations' (D-067).
**Evidence** in the #13 PR: `terraform fmt -check -recursive infra` exits 0, and
`terraform validate` returns `Success! The configuration is valid.` in both stacks.
`infra/dev/.terraform.lock.hcl` is committed, locked for `linux_amd64` and `windows_amd64`.

**O-67 · The `fetchpep-bootstrap` workspace must run in local execution mode.**
`infra/bootstrap/versions.tf` stores state in HCP Terraform (D-064) under a `cloud` block.
The workspace is created by the first `terraform init` in Cloud Shell and defaults to
remote execution. A remote run has no Google credentials and fails, which is harmless, but
it is not the bootstrap D-064 describes. Before the first plan, George sets Workspace →
Settings → General → Execution mode to **Local**. Also: O-57, because the state carries the
billing account id.

**O-68 · The kill switch depends on the Functions Framework — resolved 24 Sep by D-073
(pin 5.0.5).** The PR #9 review asked for it to be pinned (VERSIONS rule 1).
`@google-cloud/functions-framework` `5.0.5` is now declared exactly, with a committed
`package-lock.json` of 128 packages. R-SEC-04 makes a new dependency on a money path a
decision. It is not new in substance: without the declaration, the platform installs the
framework itself, at a version nobody chose. The developer proposed pinning it; George
chose "Pin 5.0.5", recorded as D-073.

**O-69 · `CLAUDE.md` section 2 has no D-070 exception — resolved 24 Sep by D-074, wording
applied.** It reads "never touch billing
configuration" without qualification, while `.claude/rules/infra.md` now carries the D-070
exception. Raised by the PR #9 review. Section 2 is the hard-stops list and George's to
word. Proposed: append "— except the kill switch's first version, written once under
D-070" to that bullet. `CLAUDE.md` is at 150 of 150 lines, so it has to fit the same line.

**O-70 · Nothing alerts when the kill switch errors.** A failed detach, or a dry run
logging `couldDetach: false`, shows only in the function's logs. A log-based alert needs a
notification channel, which needs an email address in Terraform. Deferred from B-001;
changing the kill switch after merge is George's (D-070).

**O-71 · GitHub Desktop's push fails on the pre-push hook — fix merged in PR #14; closes
on George's first successful push from GitHub Desktop, not on the merge.** The error was
`/usr/bin/env: 'bash': No such file or directory`. [certain] GitHub Desktop 3.6.6 bundles
git 2.53.0 with `usr/bin/sh.exe` and `usr/bin/env.exe` but no `bash.exe`. The developer
chose to make the hook run under that git rather than make the developer the only one who
pushes (D-069): George pushes from Desktop, and a hook that only works for one pusher gates
only that pusher. `.githooks/pre-push` is now a POSIX `sh` shim that finds bash (on `PATH`,
then `C:\Program Files\Git\bin\bash.exe`, then `C:\Program Files\Git\usr\bin\bash.exe`) and
runs the unchanged checks in
`.githooks/pre-push.bash`. If no bash is found it **refuses** the push. **Evidence**, pushing
to a local bare repository with Desktop's bundled `git.exe` in an empty environment: clean
tree → eight `ok` lines, `── all green ──`, pushed; a banned term in the tree →
`FAIL banned-terms`, `Push refused`, exit 1, not pushed; the shim with no bash reachable →
the refusal message, exit 1. **Not proven:** a push from the GitHub Desktop app itself.
George's next push from Desktop is that test.

**O-72 · The standing watch in D-075: the developer's position differs — resolved 25 Sep
by D-083, then reopened and settled the other way the same day by D-084 and D-086.**
George first chose "Watch + one line from me": the developer watches and notifies, and
George starts each piece of work with one line in the session. He then chose the standing
go-ahead — "if I approve an action with you, why get me involved" — and put it in the
contract rather than in a typed line (D-086): the developer acts on briefs and reviews by
`roguepowell-ai` without asking, and stops only for the list in `CLAUDE.md` section 7. The
developer's first reason below therefore no longer holds: a decision recorded in this repo
*can* lift the per-item go-ahead, because George is the one who recorded it. The second and
third stand as risks the contract accepts. The loop is written in `ops/RUNBOOK.ops.md`
Part 4. The positions as they were raised, under D-069:
- **D-075, step 4 and step 5 of B-002 (issue #11):** after the step-0 PR merges, the
  developer runs a standing loop and *acts* on any issue or comment by `roguepowell-ai`.
- **The developer's position:** the loop can **watch and report** (poll issues and review
  comments, then notify George in one line: "issue #12 is a brief; say *do issue #12*").
  It does **not start work** from GitHub content on its own. Each start needs George to say
  so in the session, as he did for #11 and for each PR #9 review. Reasons:
  1. The developer's operating rules treat anything read through a tool — an issue body, a
     review comment — as data, not instruction. Acting on it needs the person's go-ahead
     in the session, per action. A decision recorded in this repo cannot lift that rule,
     for the same reason text in an issue cannot.
  2. `roguepowell-ai` is not one author. Operations and the project manager post as that
     account too, so an author check proves which account posted, not that George meant
     it. A mistake or an injected instruction in either session would carry the same
     `user.login`.
  3. The repo is public, so a review quoting outside text brings that text into the loop.
- **What survives either way:** the developer pushes, opens PRs and answers reviews with
  `gh`, so George stops relaying content between sessions. What stays is one line from
  George per piece of work: "do issue #N", or "address the review on #N".

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

**O-34 · Terraform CLI is extracted, not installed — restated for the Cloud Shell seat.**
The original: `terraform.exe` sat loose in `Downloads\terraform_1.16.4_windows_amd64\` on
the PC, not on `PATH`. That seat is retired (D-085). On the Cloud Shell seat `terraform` is
not installed either — `/google/bin/terraform` is a stub that prints installation
instructions — so each session fetches `1.16.4` into its own scratch folder and checks it
against HashiCorp's `SHA256SUMS` before running it (`terraform_1.16.4_linux_amd64.zip: OK`,
25 Sep). That is a per-session download, not an install: D-085 puts installs in a scratch
folder, and an install anywhere else is a stop. So the version is confirmable by command
again, and the item is now about whether a per-session fetch is the shape George wants
rather than about a loose binary.

## Blocking the first build

- **O-20 · Claude Code on the Windows PC — resolved 24 Sep.** Seat decided by D-069.
  **Evidence:** the first session ran `node --version` → `v24.21.0` and `git --version` →
  `git version 2.55.0.windows.5` (brief B-001, step 1; outputs under B-001 above)
- **O-43 · Node on the PC — resolved 24 Sep.** **Evidence:** `node --version` → `v24.21.0`
  from a Claude Code session. Whether the write hook fires is not evidenced by this: no
  write in that session was one the hook would refuse
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
- **O-35 · `.githooks/pre-push` — resolved 24 Sep.** `git config core.hooksPath .githooks`
  run in the working copy; `git config core.hooksPath` now returns `.githooks`. **Evidence
  it runs:** the push of `kill-switch-b001` printed `── contract checks ──`, eight `ok`
  lines and `── all green ──` before the remote accepted it. Per clone: a fresh clone still
  has to run the same command
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
  shared phone. Since 25 Sep: there is no picker (D-076), and whatever the methods are, a
  member is matched to an invite by the email their account carries. A relay address that
  doesn't match is handled by people, not code (D-082)
- **O-48 · The design boards predate today's decisions.** The Atlas board says "Region —
  Cornwall" and the design system README lists *region* as vocabulary (D-051 retires it); the
  App Shell's "Who's playing" picker assumes members have no login (D-054 gives them one).
  **D-076 removes the picker:** one login per member, no switching between members on a
  device, no phone pairing. The boards live in the Inkfold design system, which is George's
  to edit
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
- **O-60 · Steward controls into the game, reports out — resolved 24 Sep by D-081.** One
  narrow live door, `apply_control`, logged in `directory.door_log`. How reports travel out
  is left to the brief that builds the door. The original item: the visitor lock, fold membership,
  blocks and phone pairing are set on the website; a report filed in the game must reach a
  person. D-066 says nothing live between them, and a release batch is too slow for a lock.
  Proposed: a second server-to-server door, `apply_control`, logged in `directory.door_log`.
  Needs a decision, because it is a live call from the website into the game
- **O-61 · Sign-in: the picker or a login — resolved 24 Sep by D-076 (a login).** The
  original item: D-054 gives every member a login; the App Shell's "Who's playing" picker
  assumes members have none (O-48, O-47)
- **O-62 · Specimen names are free text — resolved 24 Sep by D-077 (blocked-word list).**
  `spec/DATA-MODEL.spec.md` proposes `directory.name_filter`, versioned release data, with
  `specimen_name.filter_version` recording which list decided each name. The list's words
  are not written. The original item: the only text a member types that others might see.
  No moderation path exists in the game. Options: names private to the fold, a word list,
  or a check
- **O-63 · Who is credited when a creature is fed or kept — resolved 24 Sep by D-078
  (both).** D-078 says "the skeleton already does this". That was true for feeding and not
  for keeping, so `creature_interaction` gains a `kept` row, written when a capture goes into
  a pen slot. The original item: D-058 gives every creature an artist and a creator. The
  proposed skeleton records both at the time of the feed
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
