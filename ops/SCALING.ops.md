---
authority: claude-proposes
---

# Scaling

You cannot write a rule that makes a good scaling decision. What you can write is the
**trigger** — the number that says a decision made for ten users is now being applied to
ten thousand, and which decision to reopen.

Every row below names a measurement, a threshold, and the decision ID it invalidates. A
threshold with no decision attached is trivia.

**A tripwire is not a plan.** Crossing one means reopen the decision, not execute a
migration. The point is to notice, not to pre-build.

## Tripwires

| Measure | Threshold | Reopen | Why that number |
|---|---|---|---|
| Concurrent players in one shard | **TBD** | D-017 single-shard pilot | [certain] Open-source Nakama does not cluster. It scales vertically, then by adding shards. The ceiling is one VM's. Heroic Cloud changes this — O-44 |
| Nakama VM CPU, sustained | 70% | D-017 | Vertical headroom gone before it is gone |
| Monthly spend | £150 of the £200 ceiling | D-022 | Leaves a month to act rather than a week |
| Cloud Run concurrent instances | 60% of the cap | — | The cap is the control; approaching it means the cap is wrong or traffic is |
| Postgres size | 60% of the Neon plan | — | |
| R2 Class B operations / month | **TBD** | — | Egress is free, reads are not. Atlas bundling is the lever |
| Submissions / week | Exceeds what one person can screen | D-021 solo developer | The content pipeline is the bottleneck, not the servers |
| Time to build one creature | Whatever O-1 measures | D-045 | Sets how fast the website can supply the game with creatures |
| BigQuery bytes scanned / month | **TBD** | — | A missing partition filter shows up here first |

`TBD` means nobody has measured it yet, not that it does not matter. Fill each one the
first time there is a real number, not an estimate.

## The one that matters

**Time to build one creature** sets how fast the website can supply the game. Under D-045
creature creation is a separate web experience, so this number no longer decides what the
product is — but a game with too few creatures has too little to encounter. It has been
open since the first plan.

## What not to do

- **Do not build for the threshold before crossing it.** The seam in the schema exists so
  a second shard is possible, not so it is imminent. Premature sharding costs more than
  late sharding.
- **Do not raise a threshold to avoid the conversation.** If a number is consistently
  wrong, change it with a decision ID and a reason.
- **Do not add a tripwire with no decision attached.** It becomes a dashboard nobody reads.
