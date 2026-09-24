---
authority: claude-proposes
---

# Infrastructure

> **Not written.** This is a placeholder so the router resolves and CI passes. It contains
> no specification.
>
> The content was worked out in planning conversation and never written to any store. It is
> not recoverable from a file. See `state/OPEN.state.md` O-18. Either write it from
> scratch or re-decide it — do not let Claude reconstruct it from memory and present the
> result as a record.

## What belongs here

What runs where, which account owns it, and where the credentials live.

## What is on record

GCP in an EU region, Neon for Postgres in EU, Cloudflare in front with R2 for assets,
Nakama on a Compute Engine VM, Core API on Cloud Run, BigQuery and dbt for the warehouse.
Everything in Terraform from the first commit. Infrastructure identifiers use the codename
`fetchpep`; the GCP project ID is permanent and cannot be renamed.
