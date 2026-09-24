---
authority: claude-proposes
---

# Infrastructure

What exists, who owns it, and where the credentials live. Rules for changing it are in
`.claude/rules/infra.md`; costs are in `ops/COSTS.ops.md`.

## Accounts and identifiers

Everything registered to `roguepowell@gmail.com` until a `@inkfold.art` address exists.

### Google Cloud — created 24 Sep 2026

| | Project ID | Project number | Purpose |
|---|---|---|---|
| Development | `fetchpep-dev` | `424117215837` | Everything until there is something to ship |
| Production | `fetchpep-prod` | `207923902542` | Empty. Stays empty until a release exists |

[certain] Both identifiers are permanent. A project ID is globally unique and cannot be
changed; the number is assigned at creation. Neither is a secret — the number appears in
service account addresses and public API endpoints by design, which is why it is recorded
here in a public repository.

Codename not product name, per D-034. See D-035 and D-041.

**Region: not recorded.** See D-043 — it waits on D-042, because Firebase brings Firestore
and [certain] a Firestore location is permanent per project.

**Billing: not recorded.** See O-28.

### Other

| Service | State |
|---|---|
| GitHub | `roguepowell-ai/fetchpep`, **public**, ruleset active on `main` |
| HCP Terraform | Connected to the repo. Apply method unverified — see O-29 |
| Cloudflare, Neon, Stripe | Not created |
| Apple, Google Play | Not created |

## The rule that governs all of it

**No resource is created by hand.** Everything through Terraform, from the first one. A
resource created in a console is a resource nobody can reproduce and nobody can find again.

**The first resource is the billing kill switch.** Not the first *interesting* resource —
the first one. [certain] It is the only failure in this system with no ceiling.

## Where credentials live

Four stores. A secret lives in exactly one, and Claude holds none of them.

| Store | Holds |
|---|---|
| GitHub Actions secrets | CI only — `UNITY_LICENSE`, `UNITY_EMAIL`, `UNITY_PASSWORD` |
| HCP Terraform workspace variables | Cloud provider credentials |
| GCP Secret Manager | Runtime — database connection, Stripe key. Does not exist yet |
| A password manager | Human-held — keystore password, Apple certificate, recovery codes |

See `spec/SECURITY.spec.md` R-SEC-01.
