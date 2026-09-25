"use strict";
// The doors (D-066, D-081). Everything a server-to-server call needs that is not specific
// to one door: who may call, and the rules the door log imposes.
//
// There are two doors and only two: `publish` (releases) and `control` (apply_control,
// D-081, not built yet). Both are logged in directory.door_log, applied or not.
/** gRPC status codes, the few this module returns. */
var CODE_INVALID_ARGUMENT = 3;
var CODE_PERMISSION_DENIED = 7;
var CODE_INTERNAL = 13;
function doorError(code, message) {
    return { message: message, code: code };
}
/**
 * A door is server to server. It is never reachable from a phone (D-066).
 *
 * The check is that the call carries no user: Nakama gives an RPC called over HTTP with the
 * runtime HTTP key an empty `ctx.userId`, and a call on a player's session always has one.
 * The HTTP key itself is checked by Nakama before this function runs — a wrong key never
 * reaches the module. So this is the second half of the control, not the whole of it: it
 * stops a signed-in client from reaching a door that Nakama would otherwise let it call.
 */
function requireServerCall(ctx, door) {
    if (ctx.userId) {
        throw doorError(CODE_PERMISSION_DENIED, door + " is a server-to-server door and is never called on a player's session");
    }
}
/** Reads back a call already logged under this idempotency key, or null if there is none. */
function previousCall(nk, idempotencyKey) {
    var rows = nk.sqlQuery("SELECT outcome, request_sha256, detail FROM directory.door_log WHERE idempotency_key = $1", [idempotencyKey]);
    if (rows.length === 0) {
        return null;
    }
    return {
        outcome: rows[0].outcome,
        request_sha256: rows[0].request_sha256,
        detail: rows[0].detail,
    };
}
/** Logs a call that was refused before anything was written. */
function logRejected(nk, door, caller, idempotencyKey, requestSha256, detail) {
    nk.sqlExec("INSERT INTO directory.door_log (door, caller, idempotency_key, request_sha256, outcome, detail)" +
        " VALUES ($1, $2, $3, $4, 'rejected', $5)", [door, caller, idempotencyKey, requestSha256, detail]);
}
/**
 * The caller recorded in the door log: a key id, never the key and never a person (D-066,
 * R-SEC-06). Nakama does not tell the module which key was used, so until there is more
 * than one publisher this is a constant naming the door's only caller.
 */
var PUBLISH_CALLER = "publish-door";
// publish_release — the publish door (D-066).
//
// The only way a creature enters the game. Server to server, never from a phone, and every
// call logged in directory.door_log whether it applied or not.
//
// The payload is a release file exactly as it sits in services/nakama/releases/. The whole
// release is applied in **one SQL statement**: the Nakama JavaScript runtime has no
// transaction handle, and a single statement is the one unit PostgreSQL will not half-apply.
// A chain of data-modifying CTEs is what makes that possible — each one feeds the next
// through RETURNING, so the release row, the phases, the species, the coats and the door-log
// row all land together or not at all.
function isNonEmptyString(v) {
    return typeof v === "string" && v.length > 0;
}
function isPositiveInteger(v) {
    return typeof v === "number" && isFinite(v) && Math.floor(v) === v && v > 0;
}
/** Returns the first thing wrong with the payload, or null if there is nothing. */
function releaseProblem(p) {
    if (!isPositiveInteger(p.release))
        return "release must be a positive whole number";
    if (!isNonEmptyString(p.note))
        return "note must say what changed";
    var lists = [
        ["phases", p.phases],
        ["species", p.species],
        ["catalogue", p.catalogue],
    ];
    for (var i = 0; i < lists.length; i++) {
        var name = lists[i][0];
        var list = lists[i][1];
        if (!list || typeof list.length !== "number" || list.length === 0) {
            return name + " must be a non-empty list";
        }
    }
    var phaseKeys = {};
    var phaseNames = {};
    for (var i = 0; i < p.phases.length; i++) {
        var ph = p.phases[i];
        if (!isNonEmptyString(ph.key))
            return "every phase needs a key";
        if (phaseKeys[ph.key])
            return "two phases share the key " + ph.key;
        phaseKeys[ph.key] = true;
        if (!isNonEmptyString(ph.name))
            return "phase " + ph.key + " needs a name";
        // The statement below matches phases back to their keys by name, so names have to be
        // distinct within a release.
        if (phaseNames[ph.name])
            return "two phases share the name " + ph.name;
        phaseNames[ph.name] = true;
        if (!isPositiveInteger(ph.places))
            return "phase " + ph.key + " needs a positive places";
    }
    var speciesKeys = {};
    for (var i = 0; i < p.species.length; i++) {
        var s = p.species[i];
        if (!isNonEmptyString(s.key))
            return "every species needs a key";
        if (speciesKeys[s.key])
            return "two species share the key " + s.key;
        speciesKeys[s.key] = true;
        if (!phaseKeys[s.phase])
            return "species " + s.key + " names an unknown phase " + s.phase;
        if (!isPositiveInteger(s.guide_number))
            return "species " + s.key + " needs a guide_number";
        if (!isNonEmptyString(s.name))
            return "species " + s.key + " needs a name";
        if (!isNonEmptyString(s.habitat_hint))
            return "species " + s.key + " needs a habitat_hint";
        if (!isNonEmptyString(s.behaviour_hint))
            return "species " + s.key + " needs a behaviour_hint";
    }
    var coatKeys = {};
    for (var i = 0; i < p.catalogue.length; i++) {
        var c = p.catalogue[i];
        if (!isNonEmptyString(c.key))
            return "every coat needs a key";
        if (coatKeys[c.key])
            return "two coats share the key " + c.key;
        coatKeys[c.key] = true;
        if (!speciesKeys[c.species])
            return "coat " + c.key + " names an unknown species " + c.species;
        // D-058 and D-078: a coat without both credits is a coat nobody can be credited for.
        if (!isNonEmptyString(c.artist))
            return "coat " + c.key + " has no artist";
        if (!isNonEmptyString(c.creator))
            return "coat " + c.key + " has no creator";
        if (!isNonEmptyString(c.sprite_ref))
            return "coat " + c.key + " has no sprite_ref";
        if (!isNonEmptyString(c.habitat))
            return "coat " + c.key + " has no habitat";
        if (!isNonEmptyString(c.rarity))
            return "coat " + c.key + " has no rarity";
    }
    return null;
}
// One statement. Read it downwards: the release row first, then everything that hangs off
// it, then the door-log row that says it happened.
var APPLY_RELEASE_SQL = "WITH rel AS (" +
    "  INSERT INTO directory.release (number, note, payload_sha256, published_by)" +
    "  VALUES ($1::int, $2::text, $3::text, $4::text)" +
    "  RETURNING number" +
    "), ph AS (" +
    "  INSERT INTO directory.phase (name, places, release_number)" +
    "  SELECT p->>'name', (p->>'places')::int, rel.number" +
    "  FROM rel, jsonb_array_elements($5::jsonb) AS p" +
    "  RETURNING id, name" +
    "), ph_key AS (" +
    "  SELECT ph.id, p->>'key' AS key" +
    "  FROM ph JOIN jsonb_array_elements($5::jsonb) AS p ON p->>'name' = ph.name" +
    "), sp AS (" +
    "  INSERT INTO directory.species" +
    "         (phase_id, guide_number, name, habitat_hint, behaviour_hint, release_number)" +
    "  SELECT ph_key.id, (s->>'guide_number')::int, s->>'name'," +
    "         s->>'habitat_hint', s->>'behaviour_hint', rel.number" +
    "  FROM rel, jsonb_array_elements($6::jsonb) AS s" +
    "  JOIN ph_key ON ph_key.key = s->>'phase'" +
    "  RETURNING id, guide_number" +
    "), sp_key AS (" +
    "  SELECT sp.id, s->>'key' AS key" +
    "  FROM sp JOIN jsonb_array_elements($6::jsonb) AS s" +
    "    ON (s->>'guide_number')::int = sp.guide_number" +
    "), cat AS (" +
    "  INSERT INTO directory.catalogue" +
    "         (species_id, coat_name, artist, creator, sprite_ref, habitat, rarity, release_number)" +
    "  SELECT sp_key.id, c->>'coat_name', c->>'artist', c->>'creator'," +
    "         c->>'sprite_ref', c->>'habitat', c->>'rarity', rel.number" +
    "  FROM rel, jsonb_array_elements($7::jsonb) AS c" +
    "  JOIN sp_key ON sp_key.key = c->>'species'" +
    "  RETURNING id" +
    "), door AS (" +
    "  INSERT INTO directory.door_log" +
    "         (door, caller, idempotency_key, request_sha256, outcome, detail)" +
    "  VALUES ('publish', $8::text, $9::text, $3::text, 'applied', $10::text)" +
    "  RETURNING id" +
    ")" +
    "SELECT (SELECT count(*) FROM ph)  AS phases," +
    "       (SELECT count(*) FROM sp)  AS species," +
    "       (SELECT count(*) FROM cat) AS coats," +
    "       (SELECT id FROM door)      AS door_log_id";
var publishRelease = function (ctx, logger, nk, payload) {
    requireServerCall(ctx, "publish_release");
    if (!payload) {
        throw doorError(CODE_INVALID_ARGUMENT, "publish_release needs a release payload");
    }
    // The hash is of the bytes that arrived, so re-sending the same file gives the same hash
    // and a changed file under a used key is visible rather than silent.
    var requestSha256 = nk.sha256Hash(payload);
    var body;
    try {
        body = JSON.parse(payload);
    }
    catch (e) {
        throw doorError(CODE_INVALID_ARGUMENT, "publish_release payload is not JSON");
    }
    if (!isNonEmptyString(body.idempotency_key)) {
        // Nothing to log against: the door log's key is the idempotency key.
        throw doorError(CODE_INVALID_ARGUMENT, "publish_release needs an idempotency_key");
    }
    var key = body.idempotency_key;
    var earlier = previousCall(nk, key);
    if (earlier) {
        // The call already happened. Say what it did and change nothing — that is what the
        // idempotency key is for. A second row cannot be written anyway: the key is unique.
        var sameBytes = earlier.request_sha256 === requestSha256;
        logger.info("publish_release: idempotency_key %s seen before, outcome %s, same payload %s", key, earlier.outcome, sameBytes ? "yes" : "no");
        if (!sameBytes) {
            throw doorError(CODE_INVALID_ARGUMENT, "idempotency_key " + key + " was used for a different payload");
        }
        return JSON.stringify({
            outcome: "duplicate",
            first_outcome: earlier.outcome,
            detail: earlier.detail,
        });
    }
    var problem = releaseProblem(body);
    if (problem) {
        logRejected(nk, "publish", PUBLISH_CALLER, key, requestSha256, problem);
        logger.warn("publish_release: rejected %s — %s", key, problem);
        return JSON.stringify({ outcome: "rejected", detail: problem });
    }
    var detail = "release " +
        body.release +
        ": " +
        body.phases.length +
        " phase(s), " +
        body.species.length +
        " species, " +
        body.catalogue.length +
        " coat(s)";
    var rows;
    try {
        rows = nk.sqlQuery(APPLY_RELEASE_SQL, [
            body.release,
            body.note,
            requestSha256,
            PUBLISH_CALLER,
            JSON.stringify(body.phases),
            JSON.stringify(body.species),
            JSON.stringify(body.catalogue),
            PUBLISH_CALLER,
            key,
            detail,
        ]);
    }
    catch (e) {
        // Nothing was written — the whole thing was one statement.
        //
        // The attempt still goes in the door log, but **not under the caller's key**. The key
        // is unique, so a row under it would be the last word on this release forever: every
        // retry of the same file would read that row back and return `duplicate`, and the only
        // way to publish would be to edit the idempotency key in a release file that is
        // supposed to be immutable. A failure that cannot be retried is worse than one that is
        // not recorded, and this way it is both retried and recorded.
        //
        // Only a validation refusal above uses up a key, because that one is the caller's
        // fault and re-sending the same bytes would fail the same way.
        var reason = "" + e;
        var attemptKey = key + "#error-" + new Date().toISOString();
        try {
            logRejected(nk, "publish", PUBLISH_CALLER, attemptKey, requestSha256, "could not apply; the key " + key + " is still free to retry: " + reason);
        }
        catch (logFailure) {
            // The database is the thing that just failed, so this can fail too. Never let it
            // replace the error that matters.
            logger.error("publish_release: could not log the failed attempt — %s", "" + logFailure);
        }
        logger.error("publish_release: %s failed to apply — %s", key, reason);
        throw doorError(CODE_INTERNAL, "publish_release could not apply the release");
    }
    var applied = rows[0];
    logger.info("publish_release: applied release %s as door_log %s — %s", body.release, applied.door_log_id, detail);
    return JSON.stringify({
        outcome: "applied",
        release: body.release,
        phases: Number(applied.phases),
        species: Number(applied.species),
        coats: Number(applied.coats),
        door_log_id: Number(applied.door_log_id),
    });
};
// read_catalogue — what is currently in the world.
//
// Every live coat with its species and phase, and the credits D-058 requires. Nothing here
// is private: the catalogue is the same for everyone, and it carries tags, never a person's
// name or age (D-020, D-056). So it is readable on a player's session as well as through
// the door, and it takes no arguments.
var READ_CATALOGUE_SQL = "SELECT c.id::text        AS catalogue_id," +
    "       c.coat_name," +
    "       c.artist," +
    "       c.creator," +
    "       c.sprite_ref," +
    "       c.habitat," +
    "       c.rarity," +
    "       c.release_number," +
    "       s.guide_number," +
    "       s.name           AS species_name," +
    "       s.habitat_hint," +
    "       s.behaviour_hint," +
    "       p.name           AS phase_name " +
    "FROM directory.catalogue c" +
    "  JOIN directory.species s ON s.id = c.species_id" +
    "  JOIN directory.phase   p ON p.id = s.phase_id " +
    "WHERE c.retired_at IS NULL AND s.retired_at IS NULL " +
    "ORDER BY s.guide_number, c.coat_name NULLS FIRST";
var readCatalogue = function (ctx, logger, nk, payload) {
    var rows = nk.sqlQuery(READ_CATALOGUE_SQL, []);
    var entries = [];
    for (var i = 0; i < rows.length; i++) {
        var r = rows[i];
        entries.push({
            catalogue_id: r.catalogue_id,
            guide_number: Number(r.guide_number),
            species: r.species_name,
            coat_name: r.coat_name,
            artist: r.artist,
            creator: r.creator,
            sprite_ref: r.sprite_ref,
            habitat: r.habitat,
            habitat_hint: r.habitat_hint,
            behaviour_hint: r.behaviour_hint,
            rarity: r.rarity,
            phase: r.phase_name,
            release: Number(r.release_number),
        });
    }
    return JSON.stringify({ count: entries.length, catalogue: entries });
};
// The game logic (D-062): TypeScript modules inside open-source Nakama, compiled to one
// JavaScript file that Nakama loads at start.
//
// Nakama refuses to start if this function is missing or throws, so a mistake here is a
// server that does not come up rather than one that comes up wrong.
function InitModule(ctx, logger, nk, initializer) {
    // RPC ids are snake_case verbs (spec/DATA-MODEL.spec.md, *Files and names*).
    initializer.registerRpc("publish_release", publishRelease);
    initializer.registerRpc("read_catalogue", readCatalogue);
    // D-079 says all game data lives in our own tables, written by this runtime. That the
    // runtime can reach them at all is the thing pass 1 has to prove, so it is checked here,
    // at start, rather than discovered on the first call: if `directory` is not there or is
    // not readable, the server does not start.
    var rows = nk.sqlQuery("SELECT count(*)::int AS applied FROM directory.schema_migration", []);
    // Nakama's logger formats with Go verbs, and a count comes back from SQL as an int64,
    // so %d rather than %s — %s prints it as `%!s(int64=2)`.
    logger.info("fetchpep: module loaded, %d migration(s) applied, 2 rpc(s) registered", rows[0].applied);
}
