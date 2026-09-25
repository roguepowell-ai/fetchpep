#!/bin/sh
# Applies our migrations in order and records each one in directory.schema_migration with
# its hash, as spec/DATA-MODEL.spec.md requires. Runs in the postgres image, which already
# has psql; PG* come from the environment (docker-compose.yml).
#
# A migration and the row recording it go in one transaction, so a half-applied migration
# cannot be recorded as applied, and an applied one cannot go unrecorded.
#
# A migration is never edited once merged. This enforces it: a file whose hash differs from
# the recorded one stops the run rather than being reapplied or silently ignored.
set -eu

cd "$(dirname "$0")"

applied=0
skipped=0

for f in [0-9][0-9][0-9][0-9]_*.sql; do
  sha=$(sha256sum "$f" | cut -d' ' -f1)

  # The table does not exist until 0001 has run, so a failure here means "not yet applied".
  recorded=$(psql -tAX -c \
    "SELECT sha256 FROM directory.schema_migration WHERE file = '$f'" 2>/dev/null || true)

  if [ -n "$recorded" ]; then
    if [ "$recorded" != "$sha" ]; then
      echo "FAIL migrations: $f was applied as $recorded but is now $sha."
      echo "      A merged migration is never edited. Add a new numbered file instead."
      exit 1
    fi
    echo "  skip  $f (applied)"
    skipped=$((skipped + 1))
    continue
  fi

  echo "  apply $f"
  psql -X -v ON_ERROR_STOP=1 --single-transaction \
    -f "$f" \
    -c "INSERT INTO directory.schema_migration (file, sha256) VALUES ('$f', '$sha')"
  applied=$((applied + 1))
done

echo "ok migrations: $applied applied, $skipped already there"

# The seam is a rule the database can check for itself (D-051). Zero rows or nothing ran.
violations=$(psql -tAX -c "SELECT count(*) FROM directory.v_seam_violations")
if [ "$violations" != "0" ]; then
  echo "FAIL migrations: $violations foreign key(s) cross the schema seam (D-051):"
  psql -X -c "SELECT * FROM directory.v_seam_violations"
  exit 1
fi
echo "ok migrations: no foreign key crosses the seam (D-051)"
