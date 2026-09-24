---
authority: claude-writes
---

# Decisions

> **This log is incomplete and the gap is the point.**
>
> Decisions D-001 to D-032 were made during planning and were never written to any store
> that survives. They exist in conversation only. They are **not** reproduced here from
> memory: a reconstructed log reads exactly like a real one and there is no way to tell an
> accurate entry from an invented one afterwards.
>
> Section 2 lists the IDs that other contract files cite. Each is **unverified**. Confirm,
> correct or delete each one, then move it into section 1.

## 1. Confirmed

| ID | Decision | Source | Date |
|---|---|---|---|
| — | Nothing yet | | |

## 2. Cited but unverified

These IDs appear in `rules/NON-NEGOTIABLES.rule.md`, `rules/LANGUAGE.rule.md` and
`rules/DECISION-RULES.rule.md`. Claude wrote those citations from planning conversation, not
from a record. Until George confirms each, **the citation is not evidence** and the rule it
supports is standing on nothing.

| ID | What the rules files claim it says |
|---|---|
| D-019 | No purchasable randomness, ever |
| D-020 | Users, members, stewards. Age verification is a compliance control, not an audience definition |
| D-023 | Claude may not call anything settled without citing a decision ID |
| D-024 | `fold` replaces the retired term |   <!-- allow-term: none needed -->
| D-025 | Never diminish a maker's drawing |
| D-029 | One banned term removed from the list as too common in English to grep for |
| D-034 | Inkfold is the product name, FetchPep the internal codename |

Other IDs referenced in planning without a written record: D-017 single-region pilot,
D-021 solo developer through pilot, D-022 £200/month ceiling, D-026 named Inkfold /
inkfold.art, D-027 no browser-playable client, D-030 Gibraltar cannot be a Play merchant,
D-031 pilot ships free, D-032 revenue is web-side via Stripe only.

## 3. New — 24 September 2026

| ID | Decision | Source | Status |
|---|---|---|---|
| D-033 | Unity 6 LTS + C# supersedes Godot 4 + GDScript | George, after research | Agreed. Godot entry is in `SUPERSEDED.state.md` |
| D-035 | Two deployed backend environments: dev and prod, one GCP project each | George, 24 Sep — created `fetchpep-dev` and `fetchpep-prod` | **Resolved.** `verify:` both project IDs resolve in the Cloud console project picker |
| D-036 | Logic in plain C# classes, MonoBehaviour as a thin shell, assembly definition per feature | Claude-proposed, pending | **Open.** Sets the ceiling on verification speed |
| D-037 | Enforcement is tiered: hooks block, CI catches, prose explains | Claude-proposed, pending | Written, not yet in effect |
| D-038 | `CLAUDE.md` is a directory, not a rulebook. Capped at 150 lines, CI-enforced | Claude-proposed, George accepted | In effect |
| D-039 | The repo and Unity project live at `C:\dev\fetchpep` on the build machine. Nothing to do with this project goes in a cloud-synced folder | George — recorded in the FetchPep Project, `claude/DECISIONS-2026-09-24.md`, never copied here | **Contradicted by reality — O-46.** The working copy is at `C:\Users\laure\OneDrive\Desktop\dev\github\fetchpep`; George says sync is off for that folder |
| D-041 | *Deleted 24 Sep by George.* Its content was never recorded; the citation is removed from `ops/INFRA.ops.md`. Tombstone kept so the ID is not reused | George, 24 Sep | **Deleted** |
| D-042 | **No Firebase for now.** FCM is added when push notifications are designed. Crash reporting goes to Unity's own tooling or Sentry — O-41 | George, 24 Sep | **Decided** |
| D-043 | **London.** Google Cloud `europe-west2`; Neon `aws-eu-west-2` for the build (D-057). Servers and database in one city | George, 24 Sep | **Decided.** The Neon clause no longer applies to the game — D-063 puts the game database on the VM in London. `verify:` every location argument in `infra/` reads `europe-west2` |
| D-044 | **Erasure by crypto-shredding.** Resolves O-22. Personal fields are encrypted under a per-person key; erasure destroys the key | George, 24 Sep | **Decided.** Key location proposed in `spec/PRIVACY.spec.md` |
| D-045 | **The game's core is exploring and encounters.** The game and the website are separate experiences, specified and built separately | George, 24 Sep | **Decided** |
| D-049 | **Bundle identifier `art.inkfold.game`.** Resolves O-13. Permanent from first upload | George, 24 Sep | **Decided** |
| D-050 | **Screening rejects any drawing showing a name or signature** and asks the maker to resubmit | George, 24 Sep | **Decided** |
| D-051 | **"Region" is not a game term.** Map areas use the `place_kind` names (D-053). The shared-player instance is a **shard** in code, schemas `shard_*`. In this repo *region* means a cloud location and nothing else. Resolves Q43 / O-2 | George, 24 Sep | **Decided** |
| D-052 | **Submissions, original photographs and screening belong to the website.** The game never handles them | George, 24 Sep | **Decided** |
| D-053 | **The place hierarchy** is `directory.place_kind`: world, continent, country, area, locality, custom, fold. Text in `spec/DATA-MODEL.spec.md` | George — his schema, from a screenshot, 24 Sep | **Decided** |
| D-054 | **The steward and every member each have their own login and identity.** One age-verified steward per fold; members join a fold by invite. Supersedes D-046 and D-047 | George, 24 Sep | **Decided.** Sign-in methods open — O-47 |
| D-055 | **Nakama runs on a VM in London for the pilot.** Open-source, single node, managed by Terraform. Resolves O-44. Matches the App Shell board's designed downtime | George, 24 Sep | **Decided** |
| D-056 | **Makers are credited by a tag, never a real name**; tags may be auto-generated. **On erasure the animal stays, the maker's tag is dropped and the credit becomes the fold.** The family may ask for full removal. Supersedes D-048 — this is the Housekeeping board's rule | George, 24 Sep | **Decided** |
| D-057 | **Neon for the build; reviewed before real players arrive.** Cloud SQL in London is the alternative. Replaces the 26 Aug data model's note "System of record in Cloud SQL" | George, 24 Sep | **Superseded for the game by D-063**, same day. It was made for a Core API that D-062 removes from the game. It may still apply to the website, which is specified separately (D-045) |
| D-058 | **Creatures are source-agnostic in the game.** The game holds a catalogue of creatures and does not care where they came from. Every creature carries its **artist** and **creator**; every capture records **who caught it and when**. Pilot creatures are seeded, with artist and creator both **Joshua** | George, 24 Sep | **Decided** |
| D-059 | **Crash reporting is Unity's built-in Diagnostics.** Unity is a new set-up, so the project starts on a Unity 6 release at or above 6.2 — Diagnostics is available only to projects created on 6.2 or later. Prefer the current Unity 6 LTS over the newest release: GameCI images (O-12) [likely] lag new releases. Resolves O-41; narrows D-042 | George, 24 Sep | **Decided.** Unverified: limits on Unity Personal and iOS coverage — Unity's Diagnostics page states neither. `verify:` a deliberate test crash appears in the Unity Dashboard (definition of ready, layer 10) |
| D-060 | **Heroic Cloud is not used.** Heroic Labs' paid hosting quoted **$420 per average month** for the dev tier, non-scalable, zone "EU West" not London. Over the £200 ceiling (D-022) on its own. Nakama is the open-source server (Apache-2.0, £0) run on our own VM — D-055 stands. Say *open-source Nakama* or *Heroic Cloud*, never bare "Nakama", wherever cost is in question | George, 24 Sep | **Decided.** Recorded with the number so it is not reopened without it. The account still exists — O-49 |
| D-061 | **Inkfold is not made for a young audience.** Apple's Kids Category and Google Play's Designed for Families programme do not apply | George, 24 Sep | **Decided.** Age verification stays a compliance control (D-020, unverified), not an audience definition |
| D-062 | **Game logic runs as TypeScript modules inside open-source Nakama.** No separate Core API for the game; Cloud Run is not used for the game. Resolves O-50 | Claude-proposed, George accepted — "yes to stack", 24 Sep | **Decided** |
| D-063 | **The game's database is PostgreSQL 16 on the Nakama VM in London**, backed up by scheduled disk snapshots managed in Terraform. Supersedes D-057 for the game. Resolves O-51 | Claude-proposed, George accepted — "yes to stack", 24 Sep | **Decided.** Which tables Nakama owns and which are ours is open — O-54 |
| D-064 | **Terraform state and runs live in HCP Terraform.** One bootstrap stack — the trust setup and the billing kill switch — is applied once from Google Cloud Shell, replacing "locally" in the exception proposed in `ops/INFRA.ops.md`. No cloud keys: runs use short-lived tokens through workload identity. Resolves O-52 | Claude-proposed, George accepted — "yes to stack", 24 Sep | **Decided.** Needs O-31 (George connects GitHub to HCP Terraform). Where HCP Terraform stores state is unchecked — O-57 |
| D-065 | **Phones reach Nakama through a Cloudflare Tunnel** — no inbound ports on the VM, TLS by Cloudflare — **and sprites are served from Cloudflare R2**, created with EU jurisdiction. Resolves O-53 | Claude-proposed, George accepted — "yes to stack", 24 Sep | **Decided.** Needs a hostname on a domain whose DNS is on Cloudflare — O-58 |
| D-066 | **Game and website never talk live.** Creatures enter the game only as numbered releases through one server-to-server publish door; the phone can never call it. Every capture and statistic is written server-side to the game database as it happens — at the latest by the end of the session — as its own append-only row with who and when, so it is there to call on once the app is closed. The website pulls copies later; how fresh the website is does not matter, keep the copy cheap | George, 24 Sep ("keeping the data fresh in the database is" what matters); publish door and numbered releases Claude-proposed, George accepted | **Decided** |
| D-067 | **Roles.** George is owner and director: decides, merges, pays, signs in. The Claude chat in the FetchPep Project is project manager: keeps the record, writes briefs with a "proven when" line, checks evidence. Claude Code is developer: code on a branch, never applies or merges. A fresh Claude session per PR is reviewer. The Claude desktop app is operations: applies what is merged and returns evidence | Claude-proposed, George accepted — "yes to … roles", 24 Sep | **Decided.** Boundaries in the FetchPep Project, `claude/ROLES-proposed.md`. Reviewer checklist not written yet |
| D-068 | **`CLAUDE.md` changes approved.** Section 6: `infra/` and `services/` join `spec/` and `ops/` as `claude-proposes` — Claude writes on a branch, George's merge is the approval. Section 4: "global/shard seam", "Folds, places". Section 9: six checks in CI, three in the pre-push hook. The matching `.claude/rules/` edits (`nakama.md`, `infra.md`, `api-seam.md`) are approved too, but cannot be written remotely — George applies them (O-39). Resolves O-36, O-37, O-64 | George, 24 Sep — "i approve changes to the claude.md file and you can update rest of files for this". Text proposed by Claude in the FetchPep Project, `claude/CLAUDE-md-proposed-changes.md`; applied by Claude at George's instruction | **Decided.** `CLAUDE.md` is George's file; this entry is the record that he authorised Claude to edit it. `verify:` `checks/router-size.check.sh` reports 149/150 |

**Numbering.** D-040 has no record in the repo or the Project; do not reuse it. D-039
exists only in the Project and is copied above. An earlier version of this note said D-039
was never assigned — the reconciliation had searched the repo and not the Project, which is
the store-register rule broken by the note written to enforce it. D-041 to D-043 were cited
in `ops/INFRA.ops.md` before being recorded here.

**D-046, D-047 and D-048** were decided and superseded on the same day. They are in
`state/SUPERSEDED.state.md`.

**D-017** is cited in `ops/SCALING.ops.md` as the single-region pilot. Under D-051 it reads
single-*shard* pilot. Same decision, corrected word; still unverified like the rest of
section 2.

## Format

See `rules/DECISION-RULES.rule.md`. Every entry carries a source. Where a decision can be
checked by a command, it carries a `verify:` line.
