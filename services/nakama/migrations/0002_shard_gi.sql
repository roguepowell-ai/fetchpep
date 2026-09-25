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
