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
| D-041 | *Deleted 24 Sep by George.* Its content was never recorded; the citation is removed from `ops/INFRA.ops.md`. Tombstone kept so the ID is not reused | George, 24 Sep | **Deleted** |
| D-042 | **No Firebase for now.** FCM is added when push notifications are designed. Crash reporting goes to Unity's own tooling or Sentry — O-41 | George, 24 Sep | **Decided** |
| D-043 | **London.** Google Cloud `europe-west2`; Neon `aws-eu-west-2`. Servers and database in one city | George, 24 Sep | **Decided.** `verify:` every location argument in `infra/` reads `europe-west2`; the Neon project reads `aws-eu-west-2` |
| D-044 | **Erasure by crypto-shredding.** Resolves O-22. Personal fields are encrypted under a per-person key; erasure destroys the key | George, 24 Sep | **Decided.** Key location proposed in `spec/PRIVACY.spec.md` |
| D-045 | **The game's core is exploring and encounters.** Creature creation is a separate web experience outside the app | George, 24 Sep | **Decided** |
| D-046 | **Separate accounts.** Web and game do not share sign-in. A creature crosses into the game once, by a one-way publish, and becomes a permanent fixture | George, 24 Sep | **Decided** |
| D-047 | **Game sign-in is Nakama's own** — Apple, Game Center, Google Play Games, device | George, 24 Sep | **Decided** |
| D-048 | **Makers are credited by a tag, never a real name.** Tags may be auto-generated. The creature and its tag stay after an erasure request | George, 24 Sep | **Decided.** Legal check owed under O-24 |
| D-049 | **Bundle identifier `art.inkfold.game`.** Resolves O-13. Permanent from first upload | George, 24 Sep | **Decided** |
| D-050 | **Screening rejects any drawing showing a name or signature** and asks the maker to resubmit | George, 24 Sep | **Decided** |
| D-051 | **"Region" is not a game term.** Map areas use the `place_kind` names (D-053). The shared-player instance is a **shard** in code, schemas `shard_*`. In this repo *region* means a cloud location and nothing else. Resolves Q43 / O-2 | George, 24 Sep | **Decided** |
| D-052 | **The website owns submissions, originals and screening.** Only the published creature enters the game's `directory.catalogue` | George, 24 Sep | **Decided** |
| D-053 | **The place hierarchy** is `directory.place_kind`: world, continent, country, area, locality, custom, fold. Text in `spec/DATA-MODEL.spec.md` | George — his schema, from a screenshot, 24 Sep | **Decided** |

**Numbering.** D-039 and D-040 were never assigned; the sequence goes 038 → 041. Found
24 Sep while reconciling this file against every ID cited across the contract. Do not reuse
the gap. D-041 to D-043 were cited in `ops/INFRA.ops.md` before being recorded here — the
exact failure the note at the top of this file describes, repeated inside the same day it
was written.

**D-017** is cited in `ops/SCALING.ops.md` as the single-region pilot. Under D-051 it reads
single-*shard* pilot. Same decision, corrected word; still unverified like the rest of
section 2.

## Format

See `rules/DECISION-RULES.rule.md`. Every entry carries a source. Where a decision can be
checked by a command, it carries a `verify:` line.
