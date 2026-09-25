// Skeleton test for spec/DATA-MODEL.spec.md. Written for issue #12, committed under #16.
// Reads Migration 0001 and 0002 straight out of the spec, applies them to an embedded
// PostgreSQL (PGlite, with ltree), and checks what the spec claims. It is not one of the
// ten contract checks — `checks/README.md` lists those — because it needs a package that
// is deliberately not installed here.
//
// PGlite is test-only and is never installed into this repo. D-084 covers test-only
// packages from the npm registry downloaded into the developer's scratch folder; an
// install anywhere else is a stop (`CLAUDE.md` section 7). So:
//
//   cd <scratch folder> && npm install --save-exact @electric-sql/pglite@0.3.16
//   cd <repo> && PGLITE_DIR=<scratch folder> node checks/skeleton.test.mjs spec/DATA-MODEL.spec.md
//
// PGLITE_DIR names the folder that holds the `node_modules` it went into. Without it the
// package is resolved the ordinary way, from this file's own folder upwards.

import { readFileSync } from "node:fs";
import { createHmac, randomUUID } from "node:crypto";
import { createRequire } from "node:module";
import { pathToFileURL } from "node:url";
import { dirname, join, resolve as resolvePath } from "node:path";

async function loadPglite() {
  const dir = process.env.PGLITE_DIR;
  if (!dir) {
    return [await import("@electric-sql/pglite"), await import("@electric-sql/pglite/contrib/ltree")];
  }
  const req = createRequire(pathToFileURL(join(resolvePath(dir), "package.json")));
  const dist = dirname(req.resolve("@electric-sql/pglite"));
  const url = (p) => pathToFileURL(join(dist, p)).href;
  return [await import(url("index.js")), await import(url("contrib/ltree.js"))];
}
const [{ PGlite }, { ltree }] = await loadPglite();

const spec = readFileSync(process.argv[2], "utf8");
function migration(heading) {
  const at = spec.indexOf(heading);
  if (at < 0) throw new Error(`missing heading: ${heading}`);
  const m = spec.slice(at).match(/```sql\r?\n([\s\S]*?)```/);
  return m[1];
}

const db = new PGlite({ extensions: { ltree } });
let passed = 0, failed = 0;
async function check(name, fn) {
  try { await fn(); passed++; console.log(`  ok   ${name}`); }
  catch (e) { failed++; console.log(`  FAIL ${name}: ${e.message.split("\n")[0]}`); }
}
function assert(cond, msg) { if (!cond) throw new Error(msg); }
// Runs sql in a transaction that is always rolled back. Passes only if the database refuses
// it with an error matching `expect`, so a refusal for some other reason is a failure.
async function refused(sql, params, expect) {
  await db.exec("BEGIN");
  let err = null;
  try { await db.query(sql, params); } catch (e) { err = e; }
  await db.exec("ROLLBACK");
  if (!err) throw new Error("accepted, expected refusal");
  if (!expect.test(err.message)) throw new Error(`refused for the wrong reason: ${err.message}`);
}
const one = async (sql, p = []) => (await db.query(sql, p)).rows[0];
const count = async (sql, p = []) => Number((await one(sql, p)).n);
const hmac = (email) =>
  createHmac("sha256", "test-key-not-a-secret").update(email.trim().normalize("NFC").toLowerCase()).digest();

console.log("── skeleton ──");

await check("1. migration 0001 applies", () => db.exec(migration("### Migration 0001")));
await check("2. migration 0002 applies", () => db.exec(migration("### Migration 0002")));

await check("3. seam check returns zero rows", async () =>
  assert(await count("SELECT count(*) n FROM directory.v_seam_violations") === 0, "violations"));
await check("4. seam check catches a foreign key across the seam", async () => {
  await db.exec("BEGIN");
  await db.exec("ALTER TABLE shard_gi.capture ADD CONSTRAINT x FOREIGN KEY (catalogue_id) REFERENCES directory.catalogue (id)");
  const n = await count("SELECT count(*) n FROM directory.v_seam_violations");
  await db.exec("ROLLBACK");
  assert(n === 1, `saw ${n}`);
});
await check("5. directory.fold_device no longer exists (D-076)", async () =>
  assert(await count("SELECT count(*) n FROM information_schema.tables WHERE table_schema='directory' AND table_name='fold_device'") === 0, "still there"));

// seed: the pilot release, one creature by Joshua, a tree down to a fold
const world = randomUUID(), fold = randomUUID(), steward = randomUUID(), member = randomUUID();
await db.exec(`
  INSERT INTO directory.release (number, note, payload_sha256, published_by) VALUES (1, 'seed', 'x', 'test');
  INSERT INTO directory.phase (name, places, release_number) VALUES ('Phase one', 10, 1);
  INSERT INTO directory.species (phase_id, guide_number, name, habitat_hint, behaviour_hint, release_number)
    SELECT id, 1, 'Hedge hare', 'hedgerows', 'still at dusk', 1 FROM directory.phase;
  INSERT INTO directory.catalogue (species_id, artist, creator, sprite_ref, habitat, rarity, release_number)
    SELECT id, 'Joshua', 'Joshua', 'catalogue/x.atlas.png', 'hedgerow', 'common', 1 FROM directory.species;
  INSERT INTO directory.place (id, parent_id, kind, path, name) VALUES ('${world}', NULL, 'world', 'world', 'World');
  INSERT INTO directory.place (id, parent_id, kind, path, name) VALUES ('${fold}', '${world}', 'fold', 'world.f1', 'Test fold');
  INSERT INTO directory.member (id, display_name_enc) VALUES ('${steward}', '\\x00'), ('${member}', '\\x00');
  INSERT INTO directory.item_kind (code, name, class, release_number) VALUES ('reed', 'Reed', 'material', 1), ('apple', 'Apple', 'food', 1);
  INSERT INTO directory.gear (code, name, method, release_number) VALUES ('net', 'Net', 'line', 1);
`);
const cat = (await one("SELECT id FROM directory.catalogue")).id;

await check("6. the pilot catalogue read returns the Joshua creature", async () => {
  const r = await one("SELECT artist, creator FROM directory.catalogue c JOIN directory.species s ON s.id = c.species_id");
  assert(r.artist === "Joshua" && r.creator === "Joshua", JSON.stringify(r));
});
await check("7. a second world is refused", () =>
  refused(`INSERT INTO directory.place (kind, path, name) VALUES ('world', 'w2', 'Two')`, [], /place_one_world/));
await check("8. a node with no parent is refused", () =>
  refused(`INSERT INTO directory.place (kind, path, name) VALUES ('locality', 'orphan', 'Orphan')`, [], /place_root_has_no_parent/));
await check("9. the steward is a member in their own right: one row, role steward (D-076)", async () => {
  await db.query("INSERT INTO directory.fold_membership (fold_id, member_id, role) VALUES ($1, $2, 'steward')", [fold, steward]);
  assert(await count("SELECT count(*) n FROM directory.fold_membership WHERE fold_id=$1 AND member_id=$2", [fold, steward]) === 1, "no row");
});
await check("10. a second steward for one fold is refused", () =>
  refused("INSERT INTO directory.fold_membership (fold_id, member_id, role) VALUES ($1, $2, 'steward')", [fold, member], /one_steward_per_fold/));

// invites (D-080, D-081)
const door = (await one(`INSERT INTO directory.door_log (door, caller, idempotency_key, request_sha256, outcome)
                         VALUES ('control', 'website', 'inv-1', 'x', 'applied') RETURNING id`)).id;
const h = hmac("  Member@Example.org ");
const inv = (await one(`INSERT INTO directory.fold_invite (fold_id, email_hmac, hmac_key_version, door_log_id, expires_at)
                        VALUES ($1, $2, 1, $3, now() + interval '14 days') RETURNING id`, [fold, h, door])).id;

await check("11. an invite is found by the HMAC of the signed-in email, normalised", async () =>
  assert(await count("SELECT count(*) n FROM directory.fold_invite WHERE email_hmac=$1 AND accepted_at IS NULL AND revoked_at IS NULL",
    [hmac("member@example.org")]) === 1, "no match"));
await check("12. a second open invite for the same fold and email is refused", () =>
  refused(`INSERT INTO directory.fold_invite (fold_id, email_hmac, hmac_key_version, door_log_id, expires_at)
           VALUES ($1, $2, 1, $3, now() + interval '1 day')`, [fold, h, door], /fold_invite_one_open/));
await check("13. clearing the hash of an open invite is refused (D-044)", () =>
  refused("UPDATE directory.fold_invite SET email_hmac = NULL WHERE id = $1", [inv], /fold_invite_hash_while_open/));
await check("14. accepting without naming the member is refused", () =>
  refused("UPDATE directory.fold_invite SET accepted_at = now() WHERE id = $1", [inv], /fold_invite_accept_names_member/));
await check("15. accepting names the member, clears the hash, joins the fold", async () => {
  await db.query("UPDATE directory.fold_invite SET accepted_at = now(), accepted_by = $2, email_hmac = NULL WHERE id = $1", [inv, member]);
  await db.query("INSERT INTO directory.fold_membership (fold_id, member_id, role) VALUES ($1, $2, 'member')", [fold, member]);
  await db.query(`INSERT INTO shard_gi.play_event (idempotency_key, type, member_id, fold_id) VALUES ('ev-inv', 'invite_accepted', $1, $2)`, [member, fold]);
  assert(await count("SELECT count(*) n FROM directory.fold_invite WHERE email_hmac IS NULL AND accepted_by = $1", [member]) === 1, "not accepted");
});
await check("16. an invite that expires before it was made is refused", () =>
  refused(`INSERT INTO directory.fold_invite (fold_id, email_hmac, hmac_key_version, door_log_id, invited_at, expires_at)
           VALUES ($1, $2, 1, $3, now(), now() - interval '1 day')`, [fold, hmac("x@y.z"), door], /fold_invite_expiry_after_invite/));

// play: an encounter, a catch, a name, a feed, a keep
const enc = (await one(`INSERT INTO shard_gi.encounter (member_id, place_id, method, seed, table_version, outcome, catalogue_id)
                        VALUES ($1, $2, 'line', 42, 1, 'caught', $3) RETURNING id`, [member, fold, cat])).id;
const cap = (await one(`INSERT INTO shard_gi.capture (idempotency_key, encounter_id, catalogue_id, caught_by, place_id, method)
                        VALUES ('cap-1', $1, $2, $3, $4, 'line') RETURNING id`, [enc, cat, member, fold])).id;
await db.exec(`INSERT INTO directory.name_filter (version, words, release_number) VALUES (1, ARRAY['blockedword'], 1)`);

await check("17. a pending name with no list version is accepted", () =>
  db.query("INSERT INTO shard_gi.specimen_name (capture_id, name_enc) VALUES ($1, '\\x00')", [cap]));
await check("18. a name marked ok without the list version that decided it is refused (D-077)", () =>
  refused("UPDATE shard_gi.specimen_name SET status = 'ok' WHERE capture_id = $1", [cap], /specimen_name_decided_by_a_list/));
await check("19. a name marked ok with its list version is accepted", async () => {
  await db.query("UPDATE shard_gi.specimen_name SET status = 'ok', filter_version = 1 WHERE capture_id = $1", [cap]);
  assert((await one("SELECT status FROM shard_gi.specimen_name WHERE capture_id = $1", [cap])).status === "ok", "not ok");
});
await check("20. a published word list cannot be changed or deleted", async () => {
  await db.exec("UPDATE directory.name_filter SET words = ARRAY['other'] WHERE version = 1");
  await db.exec("DELETE FROM directory.name_filter WHERE version = 1");
  const r = await one("SELECT words FROM directory.name_filter WHERE version = 1");
  assert(r && r.words[0] === "blockedword", "changed");
});

async function credit(type, key) {
  const c = await one("SELECT artist, creator FROM directory.catalogue WHERE id = $1", [cat]);   // copied at the moment
  await db.query(`INSERT INTO shard_gi.creature_interaction (idempotency_key, type, catalogue_id, capture_id, by_member, at_fold, credit_artist, credit_creator)
                  VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`, [key, type, cat, cap, member, fold, c.artist, c.creator]);
}
await check("21. feeding records artist and creator (D-078)", async () => {
  await credit("fed", "feed-1");
  const r = await one("SELECT credit_artist a, credit_creator c FROM shard_gi.creature_interaction WHERE idempotency_key = 'feed-1'");
  assert(r.a === "Joshua" && r.c === "Joshua", JSON.stringify(r));
});
await check("22. keeping records artist and creator (D-078)", async () => {
  await db.query("INSERT INTO shard_gi.pen_slot (fold_id, slot, capture_id, placed_by) VALUES ($1, 1, $2, $3)", [fold, cap, member]);
  await credit("kept", "keep-1");
  const r = await one("SELECT credit_artist a, credit_creator c FROM shard_gi.creature_interaction WHERE type = 'kept'");
  assert(r.a === "Joshua" && r.c === "Joshua", JSON.stringify(r));
});
await check("23. an unknown interaction type is refused", () =>
  refused(`INSERT INTO shard_gi.creature_interaction (idempotency_key, type, catalogue_id, by_member, at_fold, credit_artist, credit_creator)
           VALUES ('bad-1', 'petted', $1, $2, $3, 'a', 'b')`, [cat, member, fold], /creature_interaction_type_check/));

await check("24. the satchel sums its ledger", async () => {
  await db.query(`INSERT INTO shard_gi.item_ledger (idempotency_key, member_id, item_code, qty_delta, reason) VALUES
                  ('il-1', $1, 'reed', 3, 'forage'), ('il-2', $1, 'reed', -1, 'craft'), ('il-3', $1, 'apple', 2, 'forage')`, [member]);
  const r = await one("SELECT qty FROM shard_gi.satchel WHERE member_id = $1 AND item_code = 'reed'", [member]);
  assert(Number(r.qty) === 2, `reed = ${r.qty}`);
});
await check("25. update and delete on append-only tables change nothing", async () => {
  const before = await count("SELECT count(*) n FROM shard_gi.creature_interaction");
  await db.exec("UPDATE shard_gi.creature_interaction SET credit_artist = 'x'; DELETE FROM shard_gi.creature_interaction;");
  await db.exec("UPDATE directory.door_log SET outcome = 'rejected'; DELETE FROM directory.door_log;");
  await db.exec("DELETE FROM shard_gi.play_event; DELETE FROM shard_gi.capture;");
  assert(await count("SELECT count(*) n FROM shard_gi.creature_interaction") === before, "interaction changed");
  assert(await count("SELECT count(*) n FROM shard_gi.creature_interaction WHERE credit_artist = 'x'") === 0, "updated");
  assert(await count("SELECT count(*) n FROM directory.door_log WHERE outcome = 'applied'") === 1, "door_log changed");
  assert(await count("SELECT count(*) n FROM shard_gi.play_event") === 1, "play_event changed");
  assert(await count("SELECT count(*) n FROM shard_gi.capture") === 1, "capture changed");
});
await check("26. a repeated idempotency key is refused", () =>
  refused("INSERT INTO shard_gi.play_event (idempotency_key, type) VALUES ('ev-inv', 'session_started')", [], /play_event_idempotency_key_key/));
await check("27. an unknown event type is refused", () =>
  refused("INSERT INTO shard_gi.play_event (idempotency_key, type) VALUES ('ev-x', 'chat_sent')", [], /play_event_type_check/));
await check("28. a fourth recipe input is refused", () =>
  refused(`INSERT INTO directory.recipe (gear_code, inputs, release_number)
           VALUES ('net', '[{"item":"reed","qty":1},{"item":"reed","qty":1},{"item":"reed","qty":1},{"item":"reed","qty":1}]', 1)`, [], /recipe_three_at_most/));
// A real second capture, so the only thing wrong with slot 7 is the slot.
const enc2 = (await one(`INSERT INTO shard_gi.encounter (member_id, place_id, method, seed, table_version, outcome, catalogue_id)
                         VALUES ($1, $2, 'line', 43, 1, 'caught', $3) RETURNING id`, [member, fold, cat])).id;
const cap2 = (await one(`INSERT INTO shard_gi.capture (idempotency_key, encounter_id, catalogue_id, caught_by, place_id, method)
                         VALUES ('cap-2', $1, $2, $3, $4, 'line') RETURNING id`, [enc2, cat, member, fold])).id;
await check("29. a seventh pen place is refused", () =>
  refused("INSERT INTO shard_gi.pen_slot (fold_id, slot, capture_id, placed_by) VALUES ($1, 7, $2, $3)", [fold, cap2, member], /pen_slot_slot_check/));
await check("30. the same capture in slot 6 is accepted (so 29 fails on the slot alone)", () =>
  db.query("INSERT INTO shard_gi.pen_slot (fold_id, slot, capture_id, placed_by) VALUES ($1, 6, $2, $3)", [fold, cap2, member]));

console.log(`── ${passed} passed, ${failed} failed ──`);
process.exit(failed ? 1 : 0);
