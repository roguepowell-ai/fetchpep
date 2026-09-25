---
authority: claude-proposes
---

# Versions

**What is actually installed.** Not what is current, not what the documentation shows, not
what the training data is full of. This file is the answer to "which version am I writing
against", and `checks/versions.check.sh` fails the build when it disagrees with reality.

Read this before writing code against anything listed here. A rule saying "use the right
version" does not work — this does, because it is told rather than remembered.

## Pinned

| Thing | Version | Pinned where | Notes |
|---|---|---|---|
| Unity Editor | `TBD` | `ProjectSettings/ProjectVersion.txt` | Must be 6.0 LTS or later — `com.unity.pipeline` does not exist below it |
| `com.unity.pipeline` | `TBD` | `Packages/manifest.json` | **`0.x-exp`.** Surface changes monthly. Expect breakage on upgrade |
| Unity CLI | `TBD` | not pinnable | Installed from the **beta** channel |
| Node | `24.21.0` | `services/nakama/.nvmrc` · `node-version-file` in `.github/workflows/checks.yml` | What the Cloud Shell seat runs, so the bundle CI compares against is built on the same host as the one the developer builds on. Exact, not `24`: the D-097 check is a byte-for-byte comparison |
| pnpm | `TBD` | `packageManager` in `package.json` | |
| Terraform | `1.16.4` | `infra/.terraform-version` · `required_version` in each stack | Not installed on the Cloud Shell seat: the binary is fetched into the session's scratch folder, checksum-checked against HashiCorp's `SHA256SUMS`, and run from there (D-085). O-34 is the same gap on the retired PC seat |
| Terraform `hashicorp/google` | `8.4.0` | `versions.tf` · `.terraform.lock.hcl` | Locked for `linux_amd64` (Cloud Shell) and `windows_amd64` |
| Terraform `hashicorp/archive` | `2.8.1` | `versions.tf` · `.terraform.lock.hcl` | Zips the kill-switch source |
| `actions/checkout` | `v7.0.1` = `3d3c42e5aac5` | `.github/workflows/checks.yml`, by SHA | [certain] A tag is movable, so the SHA is the pin and the tag is the comment |
| `actions/setup-node` | `v7.0.0` = `820762786026` | `.github/workflows/checks.yml`, by SHA | Same |
| Cloud Run functions runtime | `nodejs24` | `infra/bootstrap/kill_switch.tf` | The kill switch |
| `@google-cloud/functions-framework` | `5.0.5` | `infra/bootstrap/function/package.json` · `package-lock.json` | The kill switch's only declared dependency. Pinned by D-073 under R-SEC-04; an upgrade is its own change, and George's after merge (D-070) |
| `@electric-sql/pglite` | `0.3.16` | `checks/skeleton.test.mjs` header · `checks/README.md` | Test-only, and the one thing here **not** installed in the repo: D-084 puts a test-only package in the developer's scratch folder, so there is no manifest to pin it in. The version is pinned by the `npm install --save-exact` line both files carry. Embeds PostgreSQL 17.5; the VM runs 16 (D-063) |
| Nakama | `3.40.0` | `services/nakama/docker-compose.yml`, exact tag | Open-source Nakama, not Heroic Cloud (D-060). Caps `name` at 16 characters and refuses to start past it |
| Postgres | `16.15` | `services/nakama/docker-compose.yml`, exact tag | On the Nakama VM (D-063), which ended the Neon project this row used to name. `@electric-sql/pglite` below embeds 17.5, so the spec test runs on a later major than the VM |
| TypeScript | `5.9.3` | `services/nakama/package.json` · `package-lock.json` | Builds the Nakama module. **Not 7.x:** TypeScript 7 removed `outFile` and `target: es5`, and Nakama loads one ES5 file |
| Docker Compose | `v5.5.1` | `infra/dev/vm_nakama.tf`, with its sha256 | Container-Optimized OS ships Docker but not Compose. The standalone binary is downloaded at boot and checksum-verified before it is made executable |
| Container-Optimized OS | `cos-121-lts` | `infra/dev/vm_nakama.tf` | The image family is the LTS milestone, not a moving one. Docker 27.5.1. Supported to March 2027 |
| dbt | `TBD` | `requirements.txt`, exact | |

`TBD` is not a placeholder to leave. Fill each one the moment that thing is installed, in
the same change that installs it.

## Rules

1. **Exact versions. No ranges, no `latest`, no `^`, no `~`.** A range means the build is
   not reproducible and a green run today says nothing about tomorrow.
2. **Lockfiles are committed.** `pnpm-lock.yaml`, `Packages/packages-lock.json`,
   `.terraform.lock.hcl`.
3. **An upgrade is its own change.** Never bundled with a feature. The diff should show
   only the version and what broke.
4. **This file is updated in the same commit as the upgrade**, or the check fails.

## API versions

Third-party APIs are pinned the same way and recorded here, because the failure is worse:
code written against the wrong API version compiles, passes review, and fails in
production.

| API | Version | Where set |
|---|---|---|
| Stripe | `TBD` | API version header, set explicitly per request |
| Google Play Developer API | `TBD` | client library version |
| Cloudflare | `TBD` | |

**Never rely on an account-level default API version.** It changes underneath you and the
change is invisible in the diff. Set it per request.

## Known version traps

- [certain] `com.unity.pipeline` is experimental. Unity has already deprecated its own
  in-Editor MCP server in favour of the CLI. Treat every upgrade as breaking.
- [certain] `unity test` exit codes: **0** passed, **8** tests failed, **6** no verdict.
  If a future version changes these, `.claude/rules/ci.md` is wrong and CI will
  misreport.
- [certain] Unity withdrew manual `.alf` activation for Personal licences. Any guide
  describing an `activation.yml` workflow predates that change.
