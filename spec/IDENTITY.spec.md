---
authority: claude-proposes
---

# Identity

> **Not written.** This is a placeholder so the router resolves and CI passes. It contains
> no specification.
>
> The content was worked out in planning conversation and never written to any store. It is
> not recoverable from a file. See `state/OPEN.state.md` O-18. Either write it from
> scratch or re-decide it — do not let Claude reconstruct it from memory and present the
> result as a record.

## What belongs here

Accounts, roles, authentication, age verification, and what each role may see or do.
Where a role or payment grants power, the interface says so plainly.

## What is on record

Apple and Google sign-in. Age verification via Stripe, using a voided authorisation rather
than charge-and-refund — [likely] a refund keeps the processing fee, roughly 20-22p each,
about £1,100 across 5,000 stewards. Verify before building. Ages appear nowhere.
