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

---

## Proposed skeleton — 24 Sep 2026

> **Proposal, not decision.** Written by Claude from the decisions above (D-044, D-051,
> D-053, D-058, D-062 to D-066), George's design boards (the Inkfold design system's screen
> inventory and decision notes) and his 26 Aug data model. Every table says where it comes
> from. It becomes the schema when George merges it; until then nothing here is settled.
> Tested — see *Evidence* at the end.

**Where game data lives — D-079.** Nakama holds accounts, sign-in and sessions, in its own
tables. Every piece of game data lives in `directory` and `shard_gi`, written by the
TypeScript game logic. Nakama's key-value storage is not used for game data. Unverified:
that the TypeScript runtime can write to these tables. The VM brief proves it first.

### Where it lives

```
 PostgreSQL 16 on the Nakama VM, London (D-063)
 ┌──────────────────────────────────────────────────────────────────────────────┐
 │ public      Nakama's own tables — accounts, sign-in, sessions. Nakama migrates│
 │             them; we never write to them, and no game data goes in (D-079)    │
 ├──────────────────────────────────────────────────────────────────────────────┤
 │ directory   global, low write — changes arrive through the doors (D-066)      │
 │   places ─ release ─ phase ─ species ─ catalogue ─ encounter tables           │
 │   item_kind · gear · recipe · room_kind · quest · name_filter                 │
 │   member · person_key · fold_membership · fold_invite · block                 │
 │   door_log (audit) · schema_migration · v_seam_violations                     │
 ├────────────────── THE SEAM — no foreign keys, no joins (D-051) ───────────────┤
 │ shard_gi    one shared instance, high write — written by play (D-066)         │
 │   play_event (audit of every action) · fold_state                            │
 │   encounter · roll_log · capture · specimen_name · lure                       │
 │   item_ledger → satchel (view) · member_gear                                 │
 │   pen_slot · pen_day · tray · creature_interaction · ledger_entry · gift     │
 │   quest_progress · house · room · shelf_item · member_setting                │
 │   notification · report · export_cursor                                      │
 └──────────────────────────────────────────────────────────────────────────────┘
 Outside the database: sprites in R2 (D-065) · keys in Cloud KMS (D-044) · secrets in
 Secret Manager (R-SEC-01) · release files and migrations in this repo
```

**The fold, on both sides of the seam (resolves O-56 if accepted).** `directory.place` is the
fold's record: that it exists, where it sits in the tree, its name. `shard_gi.fold_state` is
its gameplay state, keyed by the same id with no foreign key.

**Personal data (D-044).** Member ids are bare uuids everywhere. Anything that identifies a
person — display names, maker tags, specimen names, maker references in the ledger — is
stored encrypted (`*_enc` columns) under that person's key in Cloud KMS. Destroying the key
leaves every row in place and unreadable. Ages never enter this database: a member's
`capabilities` are stored, not the age behind them.

### Audit trails

| Trail | What it records | Protected by |
|---|---|---|
| `shard_gi.play_event` | Every member action, with server time and an idempotency key | Append-only rules |
| `shard_gi.roll_log` | Every encounter roll, both stages | Append-only rules |
| `shard_gi.item_ledger` | Every change to a satchel; the satchel is its sum | Append-only rules |
| `shard_gi.creature_interaction` | Every feed, with the credentials credited at the time | Append-only rules |
| `shard_gi.capture` · `shard_gi.ledger_entry` | Catches; maker credit | Append-only rules |
| `directory.door_log` | Every server-to-server call — publish or control — applied, rejected or duplicate | Append-only rules |
| `directory.release` | What was published, when, with the file's hash | Append-only rules |
| `directory.schema_migration` | Which migration files ran, with their hashes | — |
| Outside the database | Google Cloud audit logs; HCP Terraform run history; git history | The provider |

Logs are a data store (R-SEC-06): no token, key, age or verification result is ever logged.

### Files and names

Proposed. Needs `CLAUDE.md` routes and write authority for `services/` and `infra/` — O-64.

```
infra/
  bootstrap/          trust setup + billing kill switch, applied once from Cloud Shell (D-064)
    kill_switch.tf  workload_identity.tf  versions.tf
  dev/                everything else in fetchpep-dev
    network.tf  vm_nakama.tf  snapshots.tf  kms.tf  secrets.tf  tunnel.tf  r2.tf
    variables.tf  outputs.tf  versions.tf
services/nakama/
  migrations/         0001_directory.sql  0002_shard_gi.sql  — NNNN_snake_case.sql
  releases/           release-0001.json  — the seed release; one file per release
  src/                main.ts (InitModule) · rpc/<verb_noun>.ts · domain/<area>.ts
  nakama.yml          server config, no secrets
  docker-compose.yml  Nakama + PostgreSQL, image tags pinned exactly
  package.json · tsconfig.json → build/index.js (runtime.js_entrypoint)
```

- **Migrations** are numbered, run in order, and never edited once merged: a change is a new
  file. Each run is recorded in `directory.schema_migration` with its hash.
- **RPC ids** are `snake_case` verbs: `read_catalogue`, `start_encounter`, `resolve_encounter`,
  `publish_release` (server key only), `apply_control` (server key only, D-081).
- **Event types** are the list in the `play_event` check constraint. Adding one is a migration.
- **Codename vs product name** (`rules/LANGUAGE.rule.md`): infrastructure says `fetchpep` —
  VM `fetchpep-dev-nakama`, buckets `fetchpep-dev-sprites` and `fetchpep-prod-sprites`.
  Anything a player or crash report could see says Inkfold.
- **R2 object keys**: `catalogue/<catalogue_id>/<sha256-12>.atlas.png` and `.atlas.json` —
  content-hashed, so a sprite is never overwritten in place; `release/<0001>/manifest.json`.
- **Secret Manager**, eight, each with a rotation period and a rotate step (D-089;
  `infra/dev/secrets.tf` has the periods and the reasoning, `ops/RUNBOOK.ops.md` Part 5 the
  procedure). Values never in the repo, and never created by Terraform (R-SEC-01).
  - `nakama-db-password`
  - `nakama-server-key`, `nakama-http-key` — the client key and the doors
  - `nakama-console-password`
  - `nakama-session-encryption-key`, `nakama-session-refresh-encryption-key`,
    `nakama-console-signing-key` — **added 25 Sep.** Nakama has a default for each, and the
    default is in its published source. Left unset, anyone who reaches the port can forge a
    player session or an admin console token without knowing any password, which would make
    the console password decorative (R-SEC-02).
  - `invite-email-hmac-key` (D-080). Lives in `fetchpep-dev` like the others (D-090); how
    the website gets the same key is open until we know where the website runs — O-77.

### Migration 0001 — `directory`

```sql
-- 0001_directory.sql — the global schema family (D-051). Low write, one copy.
-- Proposed skeleton, spec/DATA-MODEL.spec.md. Owned by George Powell.
-- Rule: no foreign key from here into any shard_* schema, or back (D-051).

CREATE EXTENSION IF NOT EXISTS ltree;
CREATE SCHEMA directory;

-- ---------------------------------------------------------------- bookkeeping
CREATE TABLE directory.schema_migration (
    file        text        PRIMARY KEY,            -- e.g. '0001_directory.sql'
    sha256      text        NOT NULL,
    applied_at  timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------- places (D-053)
-- George's enum, exactly as written 24 Sep.
CREATE TYPE directory.place_kind AS ENUM (
    'world',        -- one row, the root
    'continent',    -- structural, seeded
    'country',      -- structural, seeded
    'area',         -- admin regions, counties, states. Seeded
    'locality',     -- cities, towns, villages. Created LAZILY on first claim
    'custom',       -- a private map someone made
    'fold'          -- the leaf. One household's place
);

CREATE TABLE directory.place (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id   uuid        REFERENCES directory.place (id),
    kind        directory.place_kind NOT NULL,
    path        ltree       NOT NULL UNIQUE,        -- ancestry; one parent per node (spec/PLACES)
    name        text        NOT NULL,               -- a fold's name is free text: checked before it goes up
    court_run   boolean     NOT NULL DEFAULT false, -- the Court's mark (design boards, Atlas)
    is_private  boolean     NOT NULL DEFAULT false, -- private folds are never drawn (NON-NEGOTIABLES)
    created_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT place_root_has_no_parent CHECK ((kind = 'world') = (parent_id IS NULL))
);
CREATE INDEX place_path_gist ON directory.place USING gist (path);
CREATE INDEX place_parent    ON directory.place (parent_id);
CREATE UNIQUE INDEX place_one_world ON directory.place ((kind)) WHERE kind = 'world';   -- one row, the root

-- ---------------------------------------------------------------- releases (D-066)
-- Every change to the catalogue arrives as a numbered release through the publish door.
CREATE TABLE directory.release (
    number          integer     PRIMARY KEY CHECK (number > 0),
    note            text        NOT NULL,           -- what changed, in words
    payload_sha256  text        NOT NULL,           -- hash of the release file that was applied
    published_by    text        NOT NULL,           -- which pipeline or key id, never a person's name
    published_at    timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------- the catalogue (D-058)
-- Phase and species come from the design boards (Species and Releases; Field Guide),
-- not from a decision. Proposed.
CREATE TABLE directory.phase (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    name            text        NOT NULL,
    places          integer     NOT NULL CHECK (places > 0),   -- a phase never grows
    opened_at       timestamptz,
    closed_at       timestamptz,
    release_number  integer     NOT NULL REFERENCES directory.release (number)
);

CREATE TABLE directory.species (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    phase_id        uuid        NOT NULL REFERENCES directory.phase (id),
    guide_number    integer     NOT NULL UNIQUE,    -- silhouettes keep their number
    name            text        NOT NULL,
    habitat_hint    text        NOT NULL,           -- shown before it is caught
    behaviour_hint  text        NOT NULL,
    release_number  integer     NOT NULL REFERENCES directory.release (number),
    retired_at      timestamptz
);

-- One row per coat: the thing a member meets and catches. D-058's credentials live here.
CREATE TABLE directory.catalogue (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    species_id      uuid        NOT NULL REFERENCES directory.species (id),
    coat_name       text,
    artist          text        NOT NULL,           -- a tag, never a real name (D-056). Pilot: 'Joshua'
    creator         text        NOT NULL,           -- a tag. Pilot: 'Joshua'
    sprite_ref      text        NOT NULL,           -- R2 object key of the atlas
    habitat         text        NOT NULL,           -- the desk's call
    rarity          text        NOT NULL,           -- the desk's call; tiers not yet specified
    release_number  integer     NOT NULL REFERENCES directory.release (number),
    retired_at      timestamptz
);
CREATE INDEX catalogue_species ON directory.catalogue (species_id);

-- ---------------------------------------------------------------- encounters (spec/ENCOUNTERS, rules/nakama)
CREATE TYPE directory.capture_method AS ENUM ('stillness', 'line', 'flush', 'lure');

-- Versioned data, never compiled into the build. Two-stage roll: tier odds, then weight.
CREATE TABLE directory.encounter_table (
    version         integer     PRIMARY KEY,
    tier_odds       jsonb       NOT NULL,           -- {"common":0.7,...}; stage one
    release_number  integer     NOT NULL REFERENCES directory.release (number),
    created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE directory.encounter_entry (
    table_version   integer     NOT NULL REFERENCES directory.encounter_table (version),
    habitat         text        NOT NULL,
    method          directory.capture_method NOT NULL,
    tier            text        NOT NULL,
    catalogue_id    uuid        NOT NULL REFERENCES directory.catalogue (id),
    weight          integer     NOT NULL CHECK (weight > 0),   -- stage two
    PRIMARY KEY (table_version, habitat, method, catalogue_id)
);

-- ---------------------------------------------------------------- things in the world (design boards)
CREATE TYPE directory.item_class AS ENUM ('material', 'food', 'bait');

CREATE TABLE directory.item_kind (
    code            text        PRIMARY KEY,        -- 'reed', 'apple', 'glass'
    name            text        NOT NULL,
    class           directory.item_class NOT NULL,
    hard            boolean     NOT NULL DEFAULT false,   -- glass: storms and neighbours only
    release_number  integer     NOT NULL REFERENCES directory.release (number)
);

-- Gear is a way of catching, not an object. 'nothing' is a real row.
CREATE TABLE directory.gear (
    code            text        PRIMARY KEY,
    name            text        NOT NULL,
    method          directory.capture_method,       -- null for 'nothing at all'
    release_number  integer     NOT NULL REFERENCES directory.release (number)
);

CREATE TABLE directory.recipe (
    gear_code       text        PRIMARY KEY REFERENCES directory.gear (code),
    inputs          jsonb       NOT NULL,           -- [{"item":"reed","qty":3}, ...]
    release_number  integer     NOT NULL REFERENCES directory.release (number),
    CONSTRAINT recipe_three_at_most CHECK (jsonb_array_length(inputs) BETWEEN 1 AND 3)
);

CREATE TABLE directory.room_kind (
    code            text        PRIMARY KEY,
    name            text        NOT NULL,
    needs           jsonb       NOT NULL,           -- materials; glass for the extra room
    release_number  integer     NOT NULL REFERENCES directory.release (number)
);

-- Quests come from NPCs, never players.
CREATE TABLE directory.quest (
    code            text        PRIMARY KEY,
    npc             text        NOT NULL,           -- 'Mrs Bewick'
    words           text        NOT NULL,           -- in the neighbour's own words
    kind            text        NOT NULL CHECK (kind IN ('materials', 'presence', 'fair')),
    needs           jsonb       NOT NULL DEFAULT '[]',
    release_number  integer     NOT NULL REFERENCES directory.release (number)
);

-- ---------------------------------------------------------------- the name filter (D-077)
-- The blocked-word list that specimen names pass before anyone outside the member sees
-- them. Proposed (D-069): it is release data, arriving through the publish door like the
-- catalogue, so it is versioned and never sits in the public repo. A version never changes
-- once published; a new list is a new version.
CREATE TABLE directory.name_filter (
    version         integer     PRIMARY KEY CHECK (version > 0),
    words           text[]      NOT NULL,           -- matched as whole words, case-folded
    release_number  integer     NOT NULL REFERENCES directory.release (number),
    created_at      timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------- game identity (D-054, D-076, D-079, D-080; O-47 open)
-- One login per member, and the login is the member (D-076): no device pairing, no picker.
-- Ages never enter the game database: capabilities are stored, not the reason for them.
CREATE TABLE directory.member (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    nakama_user_id  uuid        UNIQUE,             -- Nakama's own account row (D-079)
    display_name_enc bytea      NOT NULL,           -- encrypted under the person's key (D-044)
    tag_enc         bytea,                          -- maker tag, if they make (D-056)
    capabilities    jsonb       NOT NULL DEFAULT '{}',
    created_at      timestamptz NOT NULL DEFAULT now(),
    erased_at       timestamptz                     -- set when the key is destroyed
);

-- Key material lives in Cloud KMS. This holds only the reference (D-044, spec/PRIVACY).
CREATE TABLE directory.person_key (
    member_id       uuid        PRIMARY KEY REFERENCES directory.member (id),
    kms_key_name    text        NOT NULL,
    created_at      timestamptz NOT NULL DEFAULT now(),
    destroyed_at    timestamptz
);

CREATE TYPE directory.fold_role AS ENUM ('steward', 'member');

-- The steward administers the fold and is a member in their own right (D-076): one row, with
-- role 'steward'. Steward status and membership changes arrive through apply_control (D-081).
CREATE TABLE directory.fold_membership (
    fold_id         uuid        NOT NULL REFERENCES directory.place (id),
    member_id       uuid        NOT NULL REFERENCES directory.member (id),
    role            directory.fold_role NOT NULL,
    joined_at       timestamptz NOT NULL DEFAULT now(),
    removed_at      timestamptz,                    -- soft: their work stays in the world
    PRIMARY KEY (fold_id, member_id, joined_at)
);
CREATE UNIQUE INDEX one_steward_per_fold
    ON directory.fold_membership (fold_id) WHERE role = 'steward' AND removed_at IS NULL;

-- Blocking never erases work (Housekeeping board). Blocks arrive through apply_control (D-081).
CREATE TABLE directory.block (
    fold_id         uuid        NOT NULL REFERENCES directory.place (id),
    blocked_member  uuid        NOT NULL REFERENCES directory.member (id),
    blocked_at      timestamptz NOT NULL DEFAULT now(),
    lifted_at       timestamptz,
    PRIMARY KEY (fold_id, blocked_member, blocked_at)
);

-- ---------------------------------------------------------------- audit: the doors (D-066)
-- Every server-to-server call into the game, applied or not. 'control' is apply_control,
-- the one live door (D-081).
CREATE TABLE directory.door_log (
    id              bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    door            text        NOT NULL CHECK (door IN ('publish', 'control')),
    caller          text        NOT NULL,           -- key id, never the key
    idempotency_key text        NOT NULL UNIQUE,
    request_sha256  text        NOT NULL,
    outcome         text        NOT NULL CHECK (outcome IN ('applied', 'rejected', 'duplicate')),
    detail          text,
    received_at     timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------- invites (D-080, D-081, D-082)
-- No fold can be joined without an invite. The steward invites an email on the website; the
-- invite arrives through apply_control; a member who signs in with that email is matched.
-- Proposed (D-069, following D-044): the address is never stored. email_hmac is
-- HMAC-SHA256, under invite-email-hmac-key, of the address trimmed, NFC-normalised and
-- lower-cased, with no provider-specific rewriting. The website sends the HMAC, not the
-- address; the game computes the same HMAC from the signed-in account's email. A keyed hash
-- rather than a plain one, because an email address is guessable and a plain hash of it is
-- a lookup away from the address. A mismatch, such as a relay address, is handled by people
-- (D-082).
CREATE TABLE directory.fold_invite (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    fold_id         uuid        NOT NULL REFERENCES directory.place (id),
    email_hmac      bytea,                          -- cleared once accepted or revoked (D-044)
    hmac_key_version smallint   NOT NULL,           -- which version of the key made it
    door_log_id     bigint      NOT NULL REFERENCES directory.door_log (id),   -- the call that made it
    invited_at      timestamptz NOT NULL DEFAULT now(),
    expires_at      timestamptz NOT NULL,
    accepted_at     timestamptz,
    accepted_by     uuid        REFERENCES directory.member (id),
    revoked_at      timestamptz,
    CONSTRAINT fold_invite_expiry_after_invite CHECK (expires_at > invited_at),
    CONSTRAINT fold_invite_accept_names_member CHECK ((accepted_at IS NULL) = (accepted_by IS NULL)),
    CONSTRAINT fold_invite_hash_while_open     CHECK (email_hmac IS NOT NULL
                                                      OR accepted_at IS NOT NULL
                                                      OR revoked_at IS NOT NULL)
);
-- One open invite per fold and address; the lookup at sign-in is by address.
CREATE UNIQUE INDEX fold_invite_one_open ON directory.fold_invite (fold_id, email_hmac)
    WHERE accepted_at IS NULL AND revoked_at IS NULL;
CREATE INDEX fold_invite_lookup ON directory.fold_invite (email_hmac)
    WHERE accepted_at IS NULL AND revoked_at IS NULL;

-- ---------------------------------------------------------------- append-only, by database rule
CREATE RULE door_log_no_update AS ON UPDATE TO directory.door_log DO INSTEAD NOTHING;
CREATE RULE door_log_no_delete AS ON DELETE TO directory.door_log DO INSTEAD NOTHING;
CREATE RULE release_no_update  AS ON UPDATE TO directory.release  DO INSTEAD NOTHING;
CREATE RULE release_no_delete  AS ON DELETE TO directory.release  DO INSTEAD NOTHING;
CREATE RULE name_filter_no_update AS ON UPDATE TO directory.name_filter DO INSTEAD NOTHING;
CREATE RULE name_filter_no_delete AS ON DELETE TO directory.name_filter DO INSTEAD NOTHING;

-- ---------------------------------------------------------------- the seam check (D-051)
-- CI requires zero rows.
CREATE VIEW directory.v_seam_violations AS
SELECT c.conname  AS constraint_name,
       cn.nspname AS from_schema, cr.relname AS from_table,
       fn.nspname AS to_schema,   fr.relname AS to_table
FROM   pg_constraint c
JOIN   pg_class cr     ON cr.oid = c.conrelid
JOIN   pg_namespace cn ON cn.oid = cr.relnamespace
JOIN   pg_class fr     ON fr.oid = c.confrelid
JOIN   pg_namespace fn ON fn.oid = fr.relnamespace
WHERE  c.contype = 'f'
AND    cn.nspname <> fn.nspname
AND   (cn.nspname = 'directory' OR cn.nspname LIKE 'shard\_%')
AND   (fn.nspname = 'directory' OR fn.nspname LIKE 'shard\_%');
```

### Migration 0002 — `shard_gi`

```sql
-- 0002_shard_gi.sql — one shared instance (D-051). High write. The pilot has one: shard_gi.
-- Proposed skeleton, spec/DATA-MODEL.spec.md. Owned by George Powell.
-- Rule: ids from directory (fold, place, member, catalogue) are stored as plain uuids.
-- No foreign key crosses the seam, and no query joins across it (D-051).
-- Rule: every row about a member's play is written server-side when it happens (D-066).

CREATE SCHEMA shard_gi;

-- ---------------------------------------------------------------- the fold's live state
-- directory.place is the fold's record: that it exists, where, its name. This is its
-- gameplay state, keyed by the same id. Resolves O-56 if accepted.
CREATE TABLE shard_gi.fold_state (
    fold_id         uuid        PRIMARY KEY,        -- = directory.place.id where kind = 'fold'
    visitor_lock    text        NOT NULL DEFAULT 'when_out'      -- set by apply_control (D-081)
                                CHECK (visitor_lock IN ('open', 'when_out', 'locked')),
    plot_seed       bigint      NOT NULL,
    standing        text        NOT NULL DEFAULT 'smallholding',
    updated_at      timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------- the play record (D-066)
-- One row per member action. The audit trail of play, and what the website copies later.
CREATE TABLE shard_gi.play_event (
    id              bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,  -- increasing: the copy job's cursor
    idempotency_key text        NOT NULL UNIQUE,    -- a retried action is applied once
    type            text        NOT NULL CHECK (type IN (
                        'session_started', 'session_ended',
                        'place_entered', 'travel_started', 'travel_ended',
                        'encounter_started', 'encounter_resolved', 'encounter_blocked',
                        'lure_set', 'lure_resolved', 'specimen_named',
                        'gear_unlocked', 'pen_changed', 'gift_left', 'gift_collected',
                        'visit', 'quest_accepted', 'quest_completed', 'fair_shown',
                        'room_built', 'shelf_changed', 'setting_changed',
                        'notification_sent', 'report_filed', 'invite_accepted')),
    member_id       uuid,                           -- null only for server-clock events
    fold_id         uuid,
    place_id        uuid,
    session_id      uuid,
    at              timestamptz NOT NULL DEFAULT now(),   -- server time, never the phone's
    payload         jsonb       NOT NULL DEFAULT '{}',    -- nothing personal
    payload_enc     bytea                           -- personal fields, under the member's key (D-044)
);
CREATE INDEX play_event_member ON shard_gi.play_event (member_id, at);
CREATE INDEX play_event_fold   ON shard_gi.play_event (fold_id, at);
CREATE INDEX play_event_type   ON shard_gi.play_event (type, at);

-- ---------------------------------------------------------------- encounters and captures
-- Server-authoritative: the server issues seed and table version, then decides (rules/nakama).
CREATE TABLE shard_gi.encounter (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id       uuid        NOT NULL,
    place_id        uuid        NOT NULL,
    method          text        NOT NULL CHECK (method IN ('stillness', 'line', 'flush', 'lure')),
    seed            bigint      NOT NULL,
    table_version   integer     NOT NULL,           -- = directory.encounter_table.version
    weather         text,                           -- the only place luck is expressed
    started_at      timestamptz NOT NULL DEFAULT now(),
    resolved_at     timestamptz,
    outcome         text        CHECK (outcome IN ('caught', 'lost', 'blocked', 'abandoned')),
    catalogue_id    uuid                            -- what it was, once decided
);
CREATE INDEX encounter_member ON shard_gi.encounter (member_id, started_at);

-- Every roll, for disputes and tuning (26 Aug model). Misses since the last catch come from
-- here, for variance smoothing (spec/ENCOUNTERS).
CREATE TABLE shard_gi.roll_log (
    id              bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    encounter_id    uuid        NOT NULL REFERENCES shard_gi.encounter (id),
    stage           smallint    NOT NULL CHECK (stage IN (1, 2)),   -- tier, then weight
    base_rate       numeric     NOT NULL,
    adjustment      numeric     NOT NULL DEFAULT 0, -- smoothing applied; never shown as a number
    curve_version   text        NOT NULL,
    result          text        NOT NULL,
    rolled_at       timestamptz NOT NULL DEFAULT now()
);

-- A caught animal. D-058: creature, caught by, caught at.
CREATE TABLE shard_gi.capture (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    idempotency_key text        NOT NULL UNIQUE,
    encounter_id    uuid        NOT NULL UNIQUE REFERENCES shard_gi.encounter (id),
    catalogue_id    uuid        NOT NULL,           -- = directory.catalogue.id
    caught_by       uuid        NOT NULL,           -- = directory.member.id
    caught_at       timestamptz NOT NULL DEFAULT now(),
    place_id        uuid        NOT NULL,
    method          text        NOT NULL,
    weather         text,
    spread          jsonb       NOT NULL DEFAULT '{}'   -- described in words on screen
);
CREATE INDEX capture_member    ON shard_gi.capture (caught_by, caught_at);
CREATE INDEX capture_catalogue ON shard_gi.capture (catalogue_id);

-- The name a member gives. It passes the blocked-word list (directory.name_filter) before
-- anyone outside the member sees it (D-077). 'pending' and 'refused' are seen by the member
-- alone; 'ok' is seen by others. A refusal never shames and never says which word
-- (rules/LANGUAGE).
CREATE TABLE shard_gi.specimen_name (
    capture_id      uuid        PRIMARY KEY REFERENCES shard_gi.capture (id),
    name_enc        bytea       NOT NULL,
    status          text        NOT NULL DEFAULT 'pending'
                                CHECK (status IN ('pending', 'ok', 'refused')),
    filter_version  integer,                        -- = directory.name_filter.version that decided it
    named_at        timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT specimen_name_decided_by_a_list CHECK ((status = 'pending') = (filter_version IS NULL))
);

CREATE TABLE shard_gi.lure (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id       uuid        NOT NULL,
    place_id        uuid        NOT NULL,
    bait_code       text        NOT NULL,           -- = directory.item_kind.code
    set_at          timestamptz NOT NULL DEFAULT now(),
    resolves_at     timestamptz NOT NULL,           -- server clock, may fall after dusk
    resolved_at     timestamptz,
    outcome         text        CHECK (outcome IN ('caught', 'nothing')),
    capture_id      uuid        REFERENCES shard_gi.capture (id)
);

-- ---------------------------------------------------------------- satchel and gear
-- The satchel is the sum of its rows. Twelve slots and four spare, enforced in code.
CREATE TABLE shard_gi.item_ledger (
    id              bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    idempotency_key text        NOT NULL UNIQUE,
    member_id       uuid        NOT NULL,
    item_code       text        NOT NULL,           -- = directory.item_kind.code
    qty_delta       integer     NOT NULL CHECK (qty_delta <> 0),
    reason          text        NOT NULL CHECK (reason IN (
                        'forage', 'craft', 'feed', 'gift_given', 'gift_received',
                        'quest', 'build', 'bait', 'correction')),
    play_event_id   bigint      REFERENCES shard_gi.play_event (id),
    at              timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX item_ledger_member ON shard_gi.item_ledger (member_id, item_code);

CREATE VIEW shard_gi.satchel AS
SELECT member_id, item_code, sum(qty_delta) AS qty
FROM   shard_gi.item_ledger
GROUP  BY member_id, item_code
HAVING sum(qty_delta) <> 0;

-- Gear never wears out.
CREATE TABLE shard_gi.member_gear (
    member_id       uuid        NOT NULL,
    gear_code       text        NOT NULL,           -- = directory.gear.code
    unlocked_at     timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (member_id, gear_code)
);

-- ---------------------------------------------------------------- the pen, feeding, credit
CREATE TABLE shard_gi.pen_slot (
    fold_id         uuid        NOT NULL,
    slot            smallint    NOT NULL CHECK (slot BETWEEN 1 AND 6),   -- six places
    capture_id      uuid        NOT NULL UNIQUE REFERENCES shard_gi.capture (id),
    placed_by       uuid        NOT NULL,
    placed_at       timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (fold_id, slot)
);

-- 'Kept' is a state, so it is counted once a day (26 Aug model: snap_creature_daily).
CREATE TABLE shard_gi.pen_day (
    day             date        NOT NULL,
    fold_id         uuid        NOT NULL,
    slot            smallint    NOT NULL,
    catalogue_id    uuid        NOT NULL,
    PRIMARY KEY (day, fold_id, slot)
);

CREATE TABLE shard_gi.tray (
    fold_id         uuid        PRIMARY KEY,
    level           smallint    NOT NULL DEFAULT 0 CHECK (level >= 0),
    updated_at      timestamptz NOT NULL DEFAULT now()
);

-- What people do with a creature. When a member feeds or keeps one, both its artist and its
-- creator are recorded at that moment (D-078), copied from the catalogue's credentials: in
-- the pilot 'Joshua' has no member behind it (D-058). 'kept' is written when a capture is
-- placed in a pen slot; pen_day then counts it once a day.
CREATE TABLE shard_gi.creature_interaction (
    id              bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    idempotency_key text        NOT NULL UNIQUE,
    type            text        NOT NULL CHECK (type IN ('fed', 'fed_as_guest', 'kept')),
    catalogue_id    uuid        NOT NULL,
    capture_id      uuid        REFERENCES shard_gi.capture (id),
    by_member       uuid        NOT NULL,
    at_fold         uuid        NOT NULL,
    credit_artist   text        NOT NULL,           -- copied from the catalogue at the time
    credit_creator  text        NOT NULL,
    at              timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX creature_interaction_catalogue ON shard_gi.creature_interaction (catalogue_id, at);

-- Maker credit, as spec/DATA-MODEL has it. Whether it belongs in the game or the website
-- is open (data map, "Whose ledger").
CREATE TABLE shard_gi.ledger_entry (
    id              bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    idempotency_key text        NOT NULL UNIQUE,
    catalogue_id    uuid        NOT NULL,
    maker_enc       bytea,                          -- personal: under the maker's key (D-044)
    period_id       text        NOT NULL,
    reward_version  integer     NOT NULL,
    amount          numeric     NOT NULL,
    created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE shard_gi.gift (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    from_member     uuid        NOT NULL,
    to_fold         uuid        NOT NULL,
    items           jsonb       NOT NULL,           -- items only, never text
    left_at         timestamptz NOT NULL DEFAULT now(),
    collected_at    timestamptz
);

-- ---------------------------------------------------------------- quests, home, settings
CREATE TABLE shard_gi.quest_progress (
    member_id       uuid        NOT NULL,
    quest_code      text        NOT NULL,           -- = directory.quest.code
    accepted_at     timestamptz NOT NULL DEFAULT now(),
    completed_at    timestamptz,
    PRIMARY KEY (member_id, quest_code, accepted_at)
);

CREATE TABLE shard_gi.house (
    member_id       uuid        PRIMARY KEY,        -- one building per member (26 Aug model)
    plot_x          integer     NOT NULL,
    plot_y          integer     NOT NULL,
    exterior        text        NOT NULL
);

CREATE TABLE shard_gi.room (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id       uuid        NOT NULL REFERENCES shard_gi.house (member_id),
    room_code       text        NOT NULL,           -- = directory.room_kind.code
    floor           text        NOT NULL,           -- one of four boards; the room's identity
    position        smallint    NOT NULL,
    built_at        timestamptz NOT NULL DEFAULT now(),
    UNIQUE (member_id, position)
);

CREATE TABLE shard_gi.shelf_item (
    member_id       uuid        NOT NULL,
    position        smallint    NOT NULL,
    capture_id      uuid        REFERENCES shard_gi.capture (id),
    item_code       text,
    placed_at       timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (member_id, position),
    CHECK ((capture_id IS NULL) <> (item_code IS NULL))
);

CREATE TABLE shard_gi.member_setting (
    member_id       uuid        NOT NULL,
    key             text        NOT NULL,           -- e.g. 'tap_instead_of_hold'
    value           jsonb       NOT NULL,
    updated_at      timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (member_id, key)
);

-- At most three a week, never during play (App Shell 47). The cap is checked against this.
CREATE TABLE shard_gi.notification (
    id              bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    member_id       uuid        NOT NULL,
    kind            text        NOT NULL,
    sent_at         timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX notification_member ON shard_gi.notification (member_id, sent_at);

-- Four buttons, no free text, nobody named. A report must reach a person (D-081); how it
-- travels out is for the brief that builds the door.
CREATE TABLE shard_gi.report (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter        uuid        NOT NULL,
    category        text        NOT NULL,           -- the four buttons; wording not yet specified
    place_id        uuid        NOT NULL,
    filed_at        timestamptz NOT NULL DEFAULT now(),
    status          text        NOT NULL DEFAULT 'new' CHECK (status IN ('new', 'seen', 'closed'))
);

-- ---------------------------------------------------------------- the copy out (D-066)
-- Where the website's copy job stopped. Built with the website; the table costs nothing now.
CREATE TABLE shard_gi.export_cursor (
    consumer        text        PRIMARY KEY,
    last_event_id   bigint      NOT NULL DEFAULT 0,
    updated_at      timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------- append-only, by database rule
CREATE RULE play_event_no_update           AS ON UPDATE TO shard_gi.play_event           DO INSTEAD NOTHING;
CREATE RULE play_event_no_delete           AS ON DELETE TO shard_gi.play_event           DO INSTEAD NOTHING;
CREATE RULE roll_log_no_update             AS ON UPDATE TO shard_gi.roll_log             DO INSTEAD NOTHING;
CREATE RULE roll_log_no_delete             AS ON DELETE TO shard_gi.roll_log             DO INSTEAD NOTHING;
CREATE RULE capture_no_update              AS ON UPDATE TO shard_gi.capture              DO INSTEAD NOTHING;
CREATE RULE capture_no_delete              AS ON DELETE TO shard_gi.capture              DO INSTEAD NOTHING;
CREATE RULE item_ledger_no_update          AS ON UPDATE TO shard_gi.item_ledger          DO INSTEAD NOTHING;
CREATE RULE item_ledger_no_delete          AS ON DELETE TO shard_gi.item_ledger          DO INSTEAD NOTHING;
CREATE RULE creature_interaction_no_update AS ON UPDATE TO shard_gi.creature_interaction DO INSTEAD NOTHING;
CREATE RULE creature_interaction_no_delete AS ON DELETE TO shard_gi.creature_interaction DO INSTEAD NOTHING;
CREATE RULE ledger_no_update               AS ON UPDATE TO shard_gi.ledger_entry         DO INSTEAD NOTHING;
CREATE RULE ledger_no_delete               AS ON DELETE TO shard_gi.ledger_entry         DO INSTEAD NOTHING;
```

### What each scenario writes

From the play scenarios of 24 Sep (26 member actions from the design boards).

| Scenario | Tables | Status |
|---|---|---|
| Sign-in (no picker) | `member`, `fold_membership`, `play_event` | Tables ready. One login per member, and the login is the member (D-076); sign-in methods open (O-47) |
| Joining a fold by invite | `fold_invite`, `door_log`, `fold_membership`, `play_event` | Tables ready (D-080, D-081). The keyed hash is proposed; the door itself is not built |
| Walking, travelling | `place`, `play_event` | Covered |
| Stillness, the line, the flush | `encounter_table`, `encounter_entry`, `encounter`, `roll_log`, `capture` | Covered |
| The lure | `lure`, `item_ledger` | Covered; dusk timing and whether bait is spent open |
| Blocked | `gear`, `play_event` | Covered |
| Naming the catch | `specimen_name`, `name_filter` | Tables ready; blocked-word list (D-077). The list's words are not written |
| Foraging, crafting | `item_kind`, `item_ledger`, `recipe`, `gear`, `member_gear` | Covered |
| The pen, feeding | `pen_slot`, `pen_day`, `tray`, `creature_interaction` | Covered: artist and creator recorded on feeding and on keeping (D-078) |
| Guest at the tray, gifts | `tray`, `creature_interaction`, `gift`, `item_ledger` | Covered |
| Visiting | `fold_state`, `play_event` | Tables ready; the steward's lock arrives through `apply_control` (D-081), not built |
| Quests | `quest`, `quest_progress` | Covered |
| The fair | `play_event` | Partial: fair days are not modelled (O-65) |
| Rooms, the shelf | `room_kind`, `house`, `room`, `shelf_item` | Covered |
| Dusk, connection lost, closing | `play_event`, idempotency keys | Covered |
| Settings | `member_setting` | Covered |
| Notifications | `notification` | Table ready; no delivery channel (D-042) |
| Report a problem | `report` | Table ready; must reach a person (D-081), how it travels out not yet specified |

**Not modelled yet (O-65):** things built on the land (fences, workbench — "two tile sets,
one plot record"); where encounters sit on the map (tracks, burrows); weather; fair days;
avatar pieces unlocked by play; where NPCs stand.

### Evidence

The test is **`checks/skeleton.test.mjs`**, in this repo, so this section can be reproduced
rather than taken on trust:

```
cd <scratch folder> && npm install --save-exact @electric-sql/pglite@0.3.16
cd <repo> && PGLITE_DIR=<scratch folder> node checks/skeleton.test.mjs spec/DATA-MODEL.spec.md
```

Run 25 Sep 2026. The test reads Migration 0001 and 0002 straight out of this file and
applies them to an embedded PostgreSQL 17.5 (PGlite 0.3.16, with `ltree`). The VM will run
16; nothing used is newer than 16. PGlite is test-only and is deliberately not installed
into this repo (D-084), which is why this is not one of the nine checks — see
`checks/README.md`. It replaces the earlier 18-check test, which ran from the FetchPep
Project and was never in the repo.

**Result: 30 passed, 0 failed, exit 0.**

- **Structure:** both migrations apply; the seam check returns zero rows and catches a
  foreign key added across the seam; `directory.fold_device` is gone (D-076).
- **The place tree:** one world only; a node with no parent is refused.
- **Membership (D-076):** the steward is one membership row with role `steward`; a second
  steward for a fold is refused.
- **Invites (D-080):** an invite is found by the HMAC of the signed-in email, normalised; a
  second open invite for the same fold and email is refused; clearing an open invite's hash
  is refused; accepting without naming the member is refused; accepting names the member,
  clears the hash and joins the fold; an expiry before the invite is refused.
- **Names (D-077):** a pending name needs no list version; marking a name ok without the list
  version that decided it is refused; a published word list cannot be changed or deleted.
- **Credit (D-078):** feeding and keeping each record the Joshua creature's artist and
  creator; an unknown interaction type is refused.
- **Play:** the satchel sums its ledger; update and delete on append-only tables change
  nothing; a repeated idempotency key, an unknown event type, a fourth recipe input and a
  seventh pen place are all refused. A sixth pen place with the same capture is accepted, so
  the seventh fails on the slot alone.

Every refusal check names the constraint it expects, so a refusal for another reason fails.
**Both directions:** with the `kept` type, the name-list constraint and the word-list update
rule removed from a copy of this file, exactly checks 18, 20 and 22 fail (27 passed, 3
failed, exit 1).

Not carried over from the earlier test: "an evening of play is recorded as 29 rows". The
scenario behind that number is not in any store the developer can read.
