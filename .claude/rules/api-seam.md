---
authority: claude-proposes
paths: ["services/api/**"]
---

# Core API — the seam

Routes to `spec/DATA-MODEL.spec.md`. Does not restate it.

## The seam

Two schema families in one Postgres instance:

- `directory` — global, low write. Identity, catalogue, provenance, submissions, encounter
  tables.
- `region_*` / `shard_*` — high write. Folds, gameplay, ledger.

**No foreign keys and no joins across the seam.** Ever. CI queries
`directory.v_seam_violations`, which must return zero rows. The seam is what makes a second
region possible later without a rewrite; a single join across it removes that option
quietly.

Cross-seam reads are two queries and a join in application code. That is the cost, and it
is the point.

## The ledger

`region_*.ledger_entry` is append-only, enforced in the database:

```sql
CREATE UNIQUE INDEX ux_ledger_idempotency ON region_gi.ledger_entry(idempotency_key);
CREATE RULE ledger_no_update AS ON UPDATE TO region_gi.ledger_entry DO INSTEAD NOTHING;
CREATE RULE ledger_no_delete AS ON DELETE TO region_gi.ledger_entry DO INSTEAD NOTHING;
```

Every write carries an idempotency key. A correction is a new compensating entry, never an
edit.

## Cloud Run

`max-instances` stays capped. [certain] The default is 100, and an instance holding an open
WebSocket bills as active for as long as it is held.
