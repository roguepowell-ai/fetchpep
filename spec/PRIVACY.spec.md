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

**The game and the website are separate experiences** (D-045). The game's personal data is
below. The website's — submissions, original photographs, age verification, payments — is
listed for completeness and is specified with the website (D-052).

## What personal data exists

**The game**

| Data | Where | Why it is sensitive |
|---|---|---|
| Steward and member logins | game identity (D-054, O-47) | Sign-in identifier; age band for members, never a date of birth |
| Artist and creator on each creature | `directory.catalogue` (D-058) | Tags, never real names (D-056). Pilot: "Joshua" |
| Captures — who caught what, when | `shard_*` (D-058) | Behavioural, and linkable to a person |
| Gameplay events | `shard_*`, BigQuery | Behavioural, and linkable to a person |

**The website** — specified with the website

| Data | Why it is sensitive |
|---|---|
| **Submitted photographs** | **The image itself, plus whatever metadata the camera embedded** |
| Age-verification result | One boolean and a timestamp. Never the evidence — R-SEC-07 |
| Payment records | Stripe is the processor, not us |

## The metadata problem — website

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

## Erasure — D-044, D-056

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

**What survives an erasure request** (D-056): the creature stays in the world, so other
members' collections stay intact. The maker's tag is dropped from its credentials and the
credit becomes the fold. The family can ask for full removal instead.

**Open:** a self-chosen tag can identify its maker. D-056 drops it on erasure; whether a
self-chosen tag is allowed at all is not decided. O-24 covers the legal check.

**Website, for its own spec:** George's 26 Aug data model stores submissions "EXIF stripped,
auto-cropped before write", which contradicts keeping the original untouched (D-025). O-40.

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
- **Attribution is by tag and place, never by real name and never by age** (D-056).
- Data stays in the EU or the UK. Hosting is London (D-043).
- Nothing personal is sent to a third party that is not a named processor.
