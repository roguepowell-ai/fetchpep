---
authority: claude-proposes
paths: ["warehouse/**"]
---

# Warehouse

Routes to `spec/DATA-MODEL.spec.md`. Does not restate it.

## Rules

1. **`require_partition_filter = TRUE` on every partitioned table.** An unfiltered scan of
   a large table is the single easiest way to produce a surprising bill.
2. Star schema. SCD2 on dimensions that change.
3. **Money flows OLAP to OLTP and never back.** The warehouse reads from production; it
   does not write to it. A number computed here that becomes a balance there is a
   reconciliation problem with no owner.
4. dbt models are tested. An untested model is a confident number of unknown provenance.
