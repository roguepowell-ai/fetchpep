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

Codename not product name, per D-034. Two environments, per D-035.

**Billing: attached to both projects, 24 Sep.** The kill switch does not exist. See O-28.

### Region — D-043

**London.** Google Cloud `europe-west2` for every resource that takes a location; Neon
`aws-eu-west-2` for the build, reviewed before real players arrive (D-057). [certain] Neon offers only two European regions, Frankfurt and London, both
on AWS — so the database city fixes the server city, and London puts both in one place.

*Region* here means a cloud location and nothing else. The game has no regions (D-051).

`.claude/rules/infra.md` rule 4 reads **EU or UK** since 24 Sep (D-068). [certain]
Gibraltar-to-UK transfers need no extra safeguards since 15 July 2026 — see
`spec/PRIVACY.spec.md`.

No Firebase for now (D-042), so nothing in the stack locks a location except what Terraform
creates. [certain] A Firestore database's location cannot be changed once provisioned — if a
later Firebase setup offers to create one, the answer is no without a decision.

### Other

| Service | State — verified 24 Sep |
|---|---|
| GitHub | `roguepowell-ai/fetchpep`, **public**. Ruleset on `main` binding: `contract` shows **Required** on PRs. Secret scanning and push protection on |
| HCP Terraform | Organisation `fetchpep` exists. **No VCS provider connected, no workspace.** See O-31, O-29 |
| Heroic Cloud | Account created by George, 24 Sep — org `fetchpep-studio`, title `inkfold`. **Unused:** Nakama runs on a VM in London for the pilot (D-055) |
| Cloudflare, Neon, Stripe | Not created |
| Apple, Google Play | Not created |

**Correction.** Until 24 Sep this table said HCP Terraform was *"Connected to the repo"*.
It was not. The organisation's VCS provider page reads *"There are no VCS providers
configured in this organization"*. Signing in to HCP Terraform with a GitHub account is not
the same as connecting GitHub as a VCS provider.

## The rule that governs all of it

**No resource is created by hand.** Everything through Terraform, from the first one. A
resource created in a console is a resource nobody can reproduce and nobody can find again.

**The first resource is the billing kill switch.** Not the first *interesting* resource —
the first one. [certain] It is the only failure in this system with no ceiling.

**Proposed: the bootstrap exception, stated rather than improvised.** HCP Terraform cannot
authenticate to GCP until something on the GCP side trusts it, and that something cannot be
created by the run it is meant to authorise. Without a written exception, the rule above is
either broken silently on day one or never satisfiable. Proposal: one small stack,
`infra/bootstrap/`, holding only the trust setup and the kill switch, applied **once, locally,
by George**, with its code committed like everything else. Every later resource goes through
HCP Terraform. Needs O-34 (Terraform on `PATH`) and the Google Cloud CLI.

## Where credentials live

Four stores. A secret lives in exactly one, and Claude holds none of them.

| Store | Holds |
|---|---|
| GitHub Actions secrets | CI only — `UNITY_LICENSE`, `UNITY_EMAIL`, `UNITY_PASSWORD` |
| HCP Terraform workspace variables | Cloud provider access — see below |
| GCP Secret Manager | Runtime — database connection, Stripe key. Does not exist yet |
| A password manager | Human-held — keystore password, Apple certificate, recovery codes |

**Proposed: no cloud key at all.** [certain] HCP Terraform supports dynamic provider
credentials for Google Cloud through workload identity federation — each run gets a
short-lived token, and no service account key is ever created. The workspace then holds
configuration, not a secret: `TFC_GCP_PROVIDER_AUTH`, `TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL`,
and the workload provider name. The GCP side needs a workload identity pool, an OIDC
provider for `app.terraform.io`, a service account and its bindings — which is exactly what
`infra/bootstrap/` would hold.

A key that never exists cannot be leaked, and R-SEC-01 then has one fewer secret to protect.

See `spec/SECURITY.spec.md` R-SEC-01.
