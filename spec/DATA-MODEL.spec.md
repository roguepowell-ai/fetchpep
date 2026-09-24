---
authority: claude-proposes
---

# Data model

> **Partly written.** The place hierarchy, the schema split and the creature credentials
> below are on record, with decision IDs. Everything else that belongs here was worked out in planning conversation
> and never written to any store — see `state/OPEN.state.md` O-18. Do not let Claude
> reconstruct the rest from memory and present it as a record.

## What belongs here

The game's schema, both sides of the seam, and the warehouse star schema. The website's
data is specified with the website (D-045, D-052).

## The place hierarchy — D-053

George's schema, transcribed exactly from his screenshot of 24 Sep:

```sql
CREATE TYPE directory.place_kind AS ENUM (
    'world',        -- one row, the root
    'continent',    -- structural, seeded
    'country',      -- structural, seeded
    'area',         -- admin regions, counties, states. Seeded
    'locality',     -- cities, towns, villages. Created LAZILY on first claim
    'custom',       -- a private map someone made
    'fold'          -- the leaf. One household's place
);
```

The comment on `area` uses *regions* in its everyday sense — an administrative area of a
country. That is the only place the word appears in the game's data, and it is not a game
term (D-051). Tree structure and ancestry are in `spec/PLACES.spec.md`.

## Two schema families — D-051

| Family | Scope | Write rate | Holds |
|---|---|---|---|
| `directory` | Global, one | Low | Game identity, the place tree, the creature catalogue with its credentials (D-058), encounter tables |
| `shard_*` — e.g. `shard_gi` | One per shared-player instance | High | Folds, gameplay, ledger |

A **shard** is the instance players share. Players never see the word; they see the
instance's name. *Region* in this repo means a cloud location only.

**No foreign keys and no joins across the seam.** CI-enforced via
`directory.v_seam_violations`, which must return zero rows. The seam is what makes a second
shard possible later without a rewrite.

## Creatures and captures — D-058

The game's catalogue does not record where a creature came from. It records credentials:

| Record | Fields the game needs |
|---|---|
| Creature (`directory.catalogue`) | artist · creator · sprite reference · habitat · rarity |
| Capture (`shard_*`) | creature · caught by (member) · caught at (capture time) |

Pilot creatures are seeded; artist and creator are both **Joshua**. Artist and creator are
credentials, not links to member accounts — a seeded creature has no member behind it.
George's 26 Aug data model tied a creature's maker to a `member_id`; D-058 does not, and
that model is kept in the FetchPep Project as source, not as the game's schema.

Submissions, original photographs and screening are not in the game's database (D-052).

## The ledger

`shard_*.ledger_entry` is append-only with an idempotency key, enforced by database rules
(`DO INSTEAD NOTHING` on update and delete). A correction is a compensating entry.

Personal fields in the ledger are encrypted under a per-person key, and erasure destroys
the key (D-044). This has to be in the first migration: retrofitting it means rewriting an
append-only table. Key handling is in `spec/PRIVACY.spec.md`.
