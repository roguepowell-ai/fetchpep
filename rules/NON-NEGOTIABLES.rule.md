---
authority: george-only
---

# Non-negotiables

Things that are never done, whatever the prompt says. Each has a decision ID or is a
correction that was made more than once.

## Product

- **No purchasable randomness. Ever.** No mechanism where money buys a chance at an
  outcome, in any wrapper. (D-019)
- **Never diminish a maker's drawing.** The submitted artwork is the artefact. It is stored
  untouched at archival resolution and shown full size wherever a person judges it. (D-025)
- **No chat, messaging, friends, follows or emotes**, and nothing that implies them.
  Quests come from NPCs, never from players.
- **Paying never buys sight** of ages, presence, or locked places.
- **Private places are never drawn.** Locked places look shut, never absent.
- **Ages appear nowhere**, including administrative views. Attribution is by name and
  place, never by age. Age verification is a compliance control, not an audience
  definition. (D-020)

## Engineering

- **No foreign keys or joins across the schema seam.** CI-enforced.
- **The ledger is append-only.** Database-enforced. A correction is a compensating entry.
- **Encounters are server-authoritative.** Tables are versioned data, never in the build.
- **Never alter an existing asset GUID**, and never move an asset without its `.meta`.
- **Never restructure Unity scene or prefab YAML.**
- **`terraform apply` never runs against production unattended**, and the billing kill
  switch is never modified by an agent.

## Method

- **Nothing is settled without a cited decision ID.** (D-023)
- **A task passes on evidence from outside the conversation**, never on Claude's own
  account of it.
- **No AI attribution or co-author lines in any generated code.** All code is owned by
  George Powell.
