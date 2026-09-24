---
authority: claude-proposes
---

# Privacy

[certain] Gibraltar has been subject to Gibraltar GDPR since 1 January 2021, with the
Gibraltar Regulatory Authority as supervisory authority. The UK–EU treaty means Gibraltar is
not a third country for transfers inbound from the EEA.

**Lawful basis is not settled here.** That is a decision with legal consequences and it
belongs to George, not to Claude. See O-22.

## What personal data exists

| Data | Where | Why it is sensitive |
|---|---|---|
| Steward identity | `directory` | Name, email, sign-in identifier |
| Member display name and fold | `directory` | Attribution is by name and fold |
| **Submitted photographs** | archival store | **The image itself, plus whatever metadata the camera embedded** |
| Age-verification result | `directory` | One boolean and a timestamp. Never the evidence — R-SEC-07 |
| Gameplay events | `region_*`, BigQuery | Behavioural, and linkable to a person |
| Payment records | Stripe | Stripe is the processor, not us |

## The metadata problem

A member photographs a drawing. Usually at home. [certain] Phone cameras embed GPS
coordinates, capture time and device identifiers in EXIF by default.

So every submission potentially carries **the location of the person who made it**, and the
product's own rule — keep the original untouched at archival resolution — guarantees that
data is retained.

Both halves are correct and they have to be reconciled rather than traded off:

1. The **original** is kept byte-for-byte, because it is the artwork and
   `rules/NON-NEGOTIABLES.rule.md` says never diminish a maker's drawing.
2. The original is **never served and never leaves archival storage**. Only the build
   pipeline reads it.
3. Every **derived** copy — screening copy, sprite source, anything that reaches a person
   — is re-encoded with all metadata stripped.

Invisible until it isn't, and unrecoverable afterwards.

## Erasure versus the immutable ledger

The ledger is append-only, enforced by `DO INSTEAD NOTHING` database rules. A right to
erasure request asks for deletion. **These are in direct conflict** and the conflict is
cheap to resolve now and expensive once there is a real ledger.

The standard resolution, proposed not decided:

- The ledger holds an **opaque subject id**, never a name, email or account identifier.
- The mapping from subject id to person lives in one place in `directory`.
- Erasure **severs the mapping**. The ledger keeps its rows, which are now
  unattributable, so the financial record survives and the person does not.
- Submitted artwork and anything the person authored is genuinely deleted, since it is not
  a financial record.

This has to be in the schema from the first migration. It cannot be retrofitted, because
retrofitting means rewriting an append-only table.

**O-22 blocks the schema.** See `state/OPEN.state.md`.

## Retention

Not set. Every row needs a defensible answer to "why do you still have this", and the
answer "we never deleted anything" is not one. Proposed, pending O-22:

| Data | Retention |
|---|---|
| Gameplay events | Aggregate after 90 days, discard raw |
| Submitted originals | Life of the creature, then archive |
| Rejected submissions | 30 days, then delete — a rejection is not a record worth keeping |
| Ledger | Statutory minimum, pseudonymised |
| Logs | 30 days |

## Standing constraints

- **Ages appear nowhere**, including administrative views. Already in
  `rules/NON-NEGOTIABLES.rule.md`.
- **Attribution is by name and fold, never by age.**
- Data stays in EU regions.
- Nothing personal is sent to a third party that is not a named processor.
