---
authority: claude-proposes
---

# Places

> **Not written.** This is a placeholder so the router resolves and CI passes. It contains
> no specification.
>
> The content was worked out in planning conversation and never written to any store. It is
> not recoverable from a file. See `state/OPEN.state.md` O-18. Either write it from
> scratch or re-decide it — do not let Claude reconstruct it from memory and present the
> result as a record.

## What belongs here

The place hierarchy and how the world map is built from it.

## What is on record

A self-referencing table using Postgres `ltree` for ancestry. It is a tree — connected,
acyclic, one parent per node. A place with two parents makes it a DAG and breaks `ltree`.
Standard engineering names: `parent_id` is correct; do not force brand vocabulary into the
schema. Blocked on Q43 — whether infrastructure says `region` or `shard`.
