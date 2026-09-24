---
authority: claude-proposes
---

# Encounters

> **Not written.** This is a placeholder so the router resolves and CI passes. It contains
> no specification.
>
> The content was worked out in planning conversation and never written to any store. It is
> not recoverable from a file. See `state/OPEN.state.md` O-18. Either write it from
> scratch or re-decide it — do not let Claude reconstruct it from memory and present the
> result as a record.

## What belongs here

Encounter logic, rarity tiers, weighting, and variance smoothing.

## What is on record

Server-authoritative, client-deterministic: the server issues a seed and a table version.
Two-stage roll — fixed tier probability, then weight within tier. Tables are served as
versioned data, never compiled into the build. Variance smoothing raises the chance after
consecutive misses, so a run of nothing does not become compulsive. No purchasable randomness, ever.
