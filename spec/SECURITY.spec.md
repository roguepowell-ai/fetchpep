---
authority: claude-proposes
---

# Security

Canonical. `.claude/rules/*` cite the `R-SEC` ids below; they do not restate them. A rule
restated in two places drifts in one of them.

## What is actually being protected

Three things, in order of how bad the loss is:

1. **People's drawings and who made them.** Submitted artwork, the identity of the person
   who submitted it, and anything that reveals where they are. Covered by
   `spec/PRIVACY.spec.md`.
2. **Money.** The ledger, Stripe keys, the billing account. An unbounded spend is the only
   failure here with no ceiling.
3. **The world's integrity.** A client that can mint creatures, move money, or see a
   private place breaks the product rather than merely costing something.

Not in scope: nation-state attackers, DDoS beyond what the edge absorbs by default.

---

## R-SEC-01 · No secret ever enters the repository

Not a key, not a token, not a connection string, not a `.ulf` licence, not a keystore
password. [certain] Once a secret is in git history it is permanent — rotating it is the
only remedy, and history rewriting does not help once the repo has been cloned or pushed.

`.gitignore` is **not** this control. It stops one filename. The controls are
`hooks/guard-write.mjs` (blocks the write) and `checks/secrets.check.sh` (blocks the merge).

Where secrets live: GitHub Actions secrets for CI, Secret Manager for runtime, a password
manager for anything a human holds.

**`.env.example` carries key names with empty values. Never values.**

## R-SEC-02 · The server never trusts a client claim

Identity, entitlement, price, quantity, place ownership, rarity, outcome. All decided
server-side. A client sends intent; the server decides what happened.

This generalises the rule already in `.claude/rules/nakama.md`: encounters are
server-authoritative because a client that can compute its own outcome can choose one. The
same reasoning covers every other field.

**Authorization is checked on every request, not at session start.** A token proves who,
not what-they-may-do-right-now.

## R-SEC-03 · Uploads are hostile until proven otherwise

A submission is a file from the public internet.

- Validate the actual content, not the extension or the declared content type.
- **Strip location and device metadata from every derived copy.** See `spec/PRIVACY.spec.md`
  — this is the highest-likelihood real-world harm in the product.
- Re-encode rather than passing the original bytes through.
- **Originals are never served.** They are archival storage, reachable only by the build
  pipeline. Public paths serve derived copies.
- Serve user content from a separate origin to the application.

## R-SEC-04 · Dependencies are pinned and reviewed

Exact versions, committed lockfiles, upgrades as their own change. See
`ops/VERSIONS.ops.md`, which is the enforced half.

A new third-party dependency in a path that touches money, identity or uploads is a
decision with an ID, not a convenience.

## R-SEC-05 · The ledger and the kill switch are structural, not procedural

Already enforced: the ledger is append-only by database rule, the idempotency key is
uniquely indexed, the billing kill switch is not modifiable by an agent. Recorded here
because they are security controls that happen to live in the schema and the infrastructure
rather than in code.

## R-SEC-06 · Logs are a data store

Anything logged is stored, often for longer than the record it describes and in a system
with different access control. Never log a token, a key, an age, a verification result, or
the contents of a submission.

## R-SEC-07 · Age verification data is never held

Stripe is the processor. The system stores **one boolean and a timestamp**. Never the
document, the number, the date of birth, or the image. `spec/IDENTITY.spec.md` covers the
mechanism; this is the constraint on it.

---

## What is enforced, and how

| Rule | Blocked | Caught | Explained |
|---|---|---|---|
| R-SEC-01 | `hooks/guard-write.mjs` | `checks/secrets.check.sh` | here |
| R-SEC-04 | — | `checks/versions.check.sh` | `ops/VERSIONS.ops.md` |
| R-SEC-05 | database rules | `checks/seam.check.sql` | `.claude/rules/api-seam.md` |
| R-SEC-02, 03, 06, 07 | — | **nothing yet** | here |

The last row is the honest one. Four of seven rules are prose only, which means they have
the failure rate prose has. They become enforceable when there is code to check.
