---
authority: claude-proposes
---

# Data model

> **Not written.** This is a placeholder so the router resolves and CI passes. It contains
> no specification.
>
> The content was worked out in planning conversation and never written to any store. It is
> not recoverable from a file. See `state/OPEN.state.md` O-18. Either write it from
> scratch or re-decide it — do not let Claude reconstruct it from memory and present the
> result as a record.

## What belongs here

The schema, both sides of the seam, and the warehouse star schema.

## What is on record

`directory` is global and low-write: identity, catalogue, provenance, submissions,
encounter tables. `region_*` is high-write: folds, gameplay, ledger. No foreign keys or
joins across the seam, CI-enforced via `directory.v_seam_violations`. Ledger is
append-only with an idempotency key, enforced by database rules.
