---
authority: claude-proposes
paths: ["infra/**/*.tf"]
---

# Infrastructure

Routes to `ops/INFRA.ops.md` and `ops/COSTS.ops.md`. Does not restate them.

## Never

- **`terraform apply` against production.** Plan only. The apply is a human action.
- **Touch billing configuration or the kill switch** — except its first version,
  written once under D-070 for George to review. The kill switch is the one control that
  stops an unbounded loss, so once it exists it is the one thing an agent must not be able
  to modify.

## Rules

1. Every resource in Terraform from the first commit. A resource created by hand is a
   resource nobody can reproduce.
2. `max-instances` is set explicitly on every Cloud Run service. The default is 100.
3. Spend limits set explicitly on every managed service, at creation.
4. EU or UK locations only; this project uses London, `europe-west2` (D-043). [certain]
   Gibraltar has been subject to Gibraltar GDPR since 1 Jan 2021, with the GRA as
   supervisory authority, and Gibraltar-to-UK transfers need no extra safeguards since
   15 July 2026 (`spec/PRIVACY.spec.md`).
5. Egress is the unbounded cost, not compute. Cloudflare sits in front; R2 has zero egress.

## Naming

Infrastructure identifiers use the **codename**: `fetchpep`. [certain] The GCP project ID
is permanent and globally unique — it cannot be renamed after creation.