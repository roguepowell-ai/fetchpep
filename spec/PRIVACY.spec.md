---
authority: claude-proposes
---

# Privacy

[certain] Gibraltar has been subject to Gibraltar GDPR since 1 January 2021, with the
Gibraltar Regulatory Authority as supervisory authority. The UK–EU treaty means Gibraltar is
not a third country for transfers inbound from the EEA.

[certain] Since 15 July 2026, when the UK–EU treaty on Gibraltar took effect, transfers from
Gibraltar to the UK continue without extra safeguards — the "Gibraltar–UK data bridge" is
preserved — and transfers to the EU are permitted too. Hosting in London (D-043) relies on
that. Source: Hassans, *Data Protection Changes Now in Effect*, 2026.

**Lawful basis is not settled here.** That is a decision with legal consequences and it
belongs to George, not to Claude. See O-24.

**Two experiences, two data sets** (D-045, D-046). The website holds submissions and the
people who make them. The game holds players, and receives creatures credited by a tag. The
two do not share accounts, and personal data does not cross the one-way publish.

## What personal data exists

| Data | Side | Where | Why it is sensitive |
|---|---|---|---|
| Player sign-in identity | Game | Nakama (D-047) | Apple, Google or device identifier |
| Steward identity | Game | `directory` | Name, email, sign-in identifier |
| Maker's tag | Both | website; `directory.catalogue` | Pseudonymous by design (D-048), but a self-chosen tag can still identify someone |
| **Submitted photographs** | Website | archival store | **The image itself, plus whatever metadata the camera embedded** |
| Age-verification result | Game | `directory` | One boolean and a timestamp. Never the evidence — R-SEC-07 |
| Gameplay events | Game | `shard_*`, BigQuery | Behavioural, and linkable to a person |
| Payment records | Website | Stripe | Stripe is the processor, not us |

## The metadata problem

A maker photographs a drawing, usually at home, and submits it on the website. [certain] Phone cameras embed GPS
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

## Erasure — D-044, D-048

**Decided: crypto-shredding** (D-044, resolves O-22). The ledger is append-only, enforced by
`DO INSTEAD NOTHING` rules, so a row can never be deleted. Instead:

- Every personal field the game stores is encrypted under **that person's own key**.
- Erasure **destroys the key**. The rows remain, and are unreadable.
- This has to be in the first migration. It cannot be retrofitted, because retrofitting
  means rewriting an append-only table.

**Proposed: the keys live in Cloud KMS, not in Postgres.** [likely] Neon keeps restorable
history of the database for point-in-time recovery, so a key deleted from a table could be
brought back by a restore — and a key that can come back has not been destroyed. [likely]
Cloud KMS destroys a key version after a scheduled delay, 30 days by default and
configurable; that delay is the true erasure time and must sit inside the one-month
response window.

**What survives an erasure request** (D-048): the creature and its maker's tag both stay in
the game. The tag is not the maker's real name, and screening rejects any drawing that shows
a name or signature (D-050), so the creature carries nothing that names them.

**Two points still open:**

- **A self-chosen tag** can identify its maker — someone may pick their own name. Whether
  erasure replaces a self-chosen tag with an auto-generated one is not decided. O-24 covers
  the legal check.
- **The archival original** on the website carries the camera's metadata, often a home
  location. Whether it is kept after erasure is not decided. O-40.

## Retention

Not set. Every row needs a defensible answer to "why do you still have this", and the
answer "we never deleted anything" is not one. Proposed, not yet decided:

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
- **Attribution is by tag and place, never by real name and never by age** (D-048).
- Data stays in the EU or the UK. Hosting is London (D-043).
- Nothing personal is sent to a third party that is not a named processor.
