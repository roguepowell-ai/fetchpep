// read_catalogue — what is currently in the world.
//
// Every live coat with its species and phase, and the credits D-058 requires. Nothing here
// is private: the catalogue is the same for everyone, and it carries tags, never a person's
// name or age (D-020, D-056). So it is readable on a player's session as well as through
// the door, and it takes no arguments.

const READ_CATALOGUE_SQL =
  "SELECT c.id::text        AS catalogue_id," +
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

const readCatalogue: nkruntime.RpcFunction = function (ctx, logger, nk, payload) {
  const rows = nk.sqlQuery(READ_CATALOGUE_SQL, []);

  const entries = [];
  for (let i = 0; i < rows.length; i++) {
    const r = rows[i];
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
