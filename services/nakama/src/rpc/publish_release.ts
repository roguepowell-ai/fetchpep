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

interface ReleasePhase {
  key: string;
  name: string;
  places: number;
}

interface ReleaseSpecies {
  key: string;
  phase: string;
  guide_number: number;
  name: string;
  habitat_hint: string;
  behaviour_hint: string;
}

interface ReleaseCoat {
  key: string;
  species: string;
  coat_name: string | null;
  artist: string;
  creator: string;
  sprite_ref: string;
  habitat: string;
  rarity: string;
}

interface ReleasePayload {
  idempotency_key: string;
  release: number;
  note: string;
  phases: ReleasePhase[];
  species: ReleaseSpecies[];
  catalogue: ReleaseCoat[];
}

function isNonEmptyString(v: any): boolean {
  return typeof v === "string" && v.length > 0;
}

function isPositiveInteger(v: any): boolean {
  return typeof v === "number" && isFinite(v) && Math.floor(v) === v && v > 0;
}

/** Returns the first thing wrong with the payload, or null if there is nothing. */
function releaseProblem(p: ReleasePayload): string | null {
  if (!isPositiveInteger(p.release)) return "release must be a positive whole number";
  if (!isNonEmptyString(p.note)) return "note must say what changed";

  const lists: [string, any][] = [
    ["phases", p.phases],
    ["species", p.species],
    ["catalogue", p.catalogue],
  ];
  for (let i = 0; i < lists.length; i++) {
    const name = lists[i][0];
    const list = lists[i][1];
    if (!list || typeof list.length !== "number" || list.length === 0) {
      return name + " must be a non-empty list";
    }
  }

  const phaseKeys: { [k: string]: boolean } = {};
  const phaseNames: { [k: string]: boolean } = {};
  for (let i = 0; i < p.phases.length; i++) {
    const ph = p.phases[i];
    if (!isNonEmptyString(ph.key)) return "every phase needs a key";
    if (phaseKeys[ph.key]) return "two phases share the key " + ph.key;
    phaseKeys[ph.key] = true;
    if (!isNonEmptyString(ph.name)) return "phase " + ph.key + " needs a name";
    // The statement below matches phases back to their keys by name, so names have to be
    // distinct within a release.
    if (phaseNames[ph.name]) return "two phases share the name " + ph.name;
    phaseNames[ph.name] = true;
    if (!isPositiveInteger(ph.places)) return "phase " + ph.key + " needs a positive places";
  }

  const speciesKeys: { [k: string]: boolean } = {};
  for (let i = 0; i < p.species.length; i++) {
    const s = p.species[i];
    if (!isNonEmptyString(s.key)) return "every species needs a key";
    if (speciesKeys[s.key]) return "two species share the key " + s.key;
    speciesKeys[s.key] = true;
    if (!phaseKeys[s.phase]) return "species " + s.key + " names an unknown phase " + s.phase;
    if (!isPositiveInteger(s.guide_number)) return "species " + s.key + " needs a guide_number";
    if (!isNonEmptyString(s.name)) return "species " + s.key + " needs a name";
    if (!isNonEmptyString(s.habitat_hint)) return "species " + s.key + " needs a habitat_hint";
    if (!isNonEmptyString(s.behaviour_hint)) return "species " + s.key + " needs a behaviour_hint";
  }

  const coatKeys: { [k: string]: boolean } = {};
  for (let i = 0; i < p.catalogue.length; i++) {
    const c = p.catalogue[i];
    if (!isNonEmptyString(c.key)) return "every coat needs a key";
    if (coatKeys[c.key]) return "two coats share the key " + c.key;
    coatKeys[c.key] = true;
    if (!speciesKeys[c.species]) return "coat " + c.key + " names an unknown species " + c.species;
    // D-058 and D-078: a coat without both credits is a coat nobody can be credited for.
    if (!isNonEmptyString(c.artist)) return "coat " + c.key + " has no artist";
    if (!isNonEmptyString(c.creator)) return "coat " + c.key + " has no creator";
    if (!isNonEmptyString(c.sprite_ref)) return "coat " + c.key + " has no sprite_ref";
    if (!isNonEmptyString(c.habitat)) return "coat " + c.key + " has no habitat";
    if (!isNonEmptyString(c.rarity)) return "coat " + c.key + " has no rarity";
  }

  return null;
}

// One statement. Read it downwards: the release row first, then everything that hangs off
// it, then the door-log row that says it happened.
const APPLY_RELEASE_SQL =
  "WITH rel AS (" +
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

const publishRelease: nkruntime.RpcFunction = function (ctx, logger, nk, payload) {
  requireServerCall(ctx, "publish_release");

  if (!payload) {
    throw doorError(CODE_INVALID_ARGUMENT, "publish_release needs a release payload");
  }

  // The hash is of the bytes that arrived, so re-sending the same file gives the same hash
  // and a changed file under a used key is visible rather than silent.
  const requestSha256 = nk.sha256Hash(payload);

  let body: ReleasePayload;
  try {
    body = JSON.parse(payload);
  } catch (e) {
    throw doorError(CODE_INVALID_ARGUMENT, "publish_release payload is not JSON");
  }

  if (!isNonEmptyString(body.idempotency_key)) {
    // Nothing to log against: the door log's key is the idempotency key.
    throw doorError(CODE_INVALID_ARGUMENT, "publish_release needs an idempotency_key");
  }
  const key = body.idempotency_key;

  const earlier = previousCall(nk, key);
  if (earlier) {
    // The call already happened. Say what it did and change nothing — that is what the
    // idempotency key is for. A second row cannot be written anyway: the key is unique.
    const sameBytes = earlier.request_sha256 === requestSha256;
    logger.info(
      "publish_release: idempotency_key %s seen before, outcome %s, same payload %s",
      key,
      earlier.outcome,
      sameBytes ? "yes" : "no",
    );
    if (!sameBytes) {
      throw doorError(
        CODE_INVALID_ARGUMENT,
        "idempotency_key " + key + " was used for a different payload",
      );
    }
    return JSON.stringify({
      outcome: "duplicate",
      first_outcome: earlier.outcome,
      detail: earlier.detail,
    });
  }

  const problem = releaseProblem(body);
  if (problem) {
    logRejected(nk, "publish", PUBLISH_CALLER, key, requestSha256, problem);
    logger.warn("publish_release: rejected %s — %s", key, problem);
    return JSON.stringify({ outcome: "rejected", detail: problem });
  }

  const detail =
    "release " +
    body.release +
    ": " +
    body.phases.length +
    " phase(s), " +
    body.species.length +
    " species, " +
    body.catalogue.length +
    " coat(s)";

  let rows: nkruntime.SqlQueryResult;
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
  } catch (e) {
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
    const reason = "" + e;
    const attemptKey = key + "#error-" + new Date().toISOString();
    try {
      logRejected(
        nk,
        "publish",
        PUBLISH_CALLER,
        attemptKey,
        requestSha256,
        "could not apply; the key " + key + " is still free to retry: " + reason,
      );
    } catch (logFailure) {
      // The database is the thing that just failed, so this can fail too. Never let it
      // replace the error that matters.
      logger.error("publish_release: could not log the failed attempt — %s", "" + logFailure);
    }
    logger.error("publish_release: %s failed to apply — %s", key, reason);
    throw doorError(CODE_INTERNAL, "publish_release could not apply the release");
  }

  const applied = rows[0];
  logger.info(
    "publish_release: applied release %s as door_log %s — %s",
    body.release,
    applied.door_log_id,
    detail,
  );

  return JSON.stringify({
    outcome: "applied",
    release: body.release,
    phases: Number(applied.phases),
    species: Number(applied.species),
    coats: Number(applied.coats),
    door_log_id: Number(applied.door_log_id),
  });
};
