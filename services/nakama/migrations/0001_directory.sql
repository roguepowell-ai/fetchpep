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
