# The trust setup (D-064): HCP Terraform runs get short-lived Google credentials through
# workload identity federation. No service account key is ever created, so there is no key
# to leak and R-SEC-01 has one fewer secret to protect.
#
# This is the other half of the bootstrap exception in ops/INFRA.ops.md. HCP Terraform
# cannot authenticate to Google until something on the Google side trusts it, and that
# something cannot be created by the run it is meant to authorise. So it is created once,
# from Cloud Shell, with George signed in — the same apply as the kill switch, and the same
# stack. Nothing else is ever applied this way.
#
# `kill_switch.tf` is not touched by this file (D-070), and `versions.tf` needs no change:
# everything here is in `hashicorp/google` 8.4.0, already pinned there.
#
# **Why the VM's own service account is created here** rather than in `infra/dev`, where
# the VM is: granting a project-level role needs `resourcemanager.projects.setIamPolicy`,
# and giving the Terraform runner that would let it rewrite the project's IAM, the kill
# switch's bindings included. The identity and its two project roles are therefore created
# by the one apply that already runs with George's own rights, and `infra/dev` only reads it.

# ------------------------------------------------------------------------ APIs
# **Every API this stack needs is declared here, including three that `kill_switch.tf` also
# names.**
#
# This file used to declare only what that one did not, and lean on its
# `google_project_service.apis` for the rest. D-099 ended that: the first apply is targeted
# at the trust resources and excludes every `kill_switch.tf` resource, `apis` among them. So
# on a fresh project nothing would enable `iam` or `cloudresourcemanager`, and the first
# service account, custom role or IAM binding would fail with SERVICE_DISABLED. What this
# stack needs, this stack declares.
#
# **In practice George switches them on by hand before the first apply** —
# `ops/RUNBOOK.ops.md` Part 5 step 0, one `gcloud services enable`. A one-time activation is
# something a person does once rather than something buried in code that runs every apply.
# These declarations are not the mechanism, then; they are the record. On a service that is
# already on they do nothing, and they mean the configuration still describes what the
# project needs, so a rebuild from the repository alone gets a working project and nobody
# has to remember step 0 to know what it did.
#
# Two Terraform resources naming one service is untidy, and it is the least bad of three:
# the alternatives were editing `kill_switch.tf` (D-070) or breaking D-099. It is safe
# because enabling a service is idempotent and each resource has its own address in state,
# so they do not fight — **and that safety rests entirely on `disable_on_destroy = false` on
# both sides.** Setting it `true` in either file would let a destroy switch off a service
# the kill switch needs. Do not.
resource "google_project_service" "federation" {
  for_each = toset([
    # Also named in kill_switch.tf. See the note above.
    "cloudresourcemanager.googleapis.com", # every google_project_iam_member call
    "iam.googleapis.com",                  # service accounts, custom roles, the WIF pool
    "pubsub.googleapis.com",               # the rotation topic
    # This stack's alone.
    "iamcredentials.googleapis.com",
    "secretmanager.googleapis.com",
    "sts.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}

# ----------------------------------------------------------------- the pool
# One pool, one provider, for HCP Terraform and nothing else.

resource "google_iam_workload_identity_pool" "hcp_terraform" {
  workload_identity_pool_id = "fetchpep-dev-hcp-tf"
  display_name              = "HCP Terraform"
  description               = "Short-lived credentials for HCP Terraform runs (D-064). No keys."

  depends_on = [google_project_service.federation]
}

resource "google_iam_workload_identity_pool_provider" "hcp_terraform" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.hcp_terraform.workload_identity_pool_id
  workload_identity_pool_provider_id = "fetchpep-dev-hcp-tf"
  display_name                       = "app.terraform.io"

  oidc {
    issuer_uri = "https://app.terraform.io"

    # The audience HCP Terraform puts in the token. It is the full provider resource name,
    # so a token minted for this provider is worthless against any other.
    allowed_audiences = [local.tfc_audience]
  }

  attribute_mapping = {
    "google.subject"                        = "assertion.sub"
    "attribute.terraform_organization_name" = "assertion.terraform_organization_name"
    "attribute.terraform_project_name"      = "assertion.terraform_project_name"
    "attribute.terraform_workspace_name"    = "assertion.terraform_workspace_name"
    "attribute.terraform_run_phase"         = "assertion.terraform_run_phase"

    # Workspace and phase together, as one attribute. A principalSet can match on one
    # attribute only, and "this workspace" is not the unit that should be trusted: a plan
    # runs on a pull request, before anyone has read it. Joined here, the two bindings below
    # can give the plan read and the apply write.
    "attribute.workspace_phase" = "assertion.terraform_workspace_name + \":\" + assertion.terraform_run_phase"
  }

  # Belt as well as braces. The bindings below already restrict which workspace and phase
  # may impersonate which account; this stops a token from any other organisation being
  # exchanged for a Google one at all, which is a shorter path to stop it on.
  attribute_condition = "assertion.terraform_organization_name == \"${local.tfc_organization}\""
}

# ------------------------------------------------------- what the runners may do
# Two custom roles rather than `roles/secretmanager.admin` and `roles/iap.admin`.
#
# `roles/secretmanager.admin` includes `versions.access` and `versions.add`, so a Terraform
# run holding it could read every secret value in the project and write new ones. That is
# exactly what D-089 and the design of `infra/dev/secrets.tf` are for — Terraform creates
# containers and never touches a value — and a role that contradicts the design is the
# wrong role, however convenient.
#
# **What this does not claim.** The apply account still reaches a value *indirectly*, two
# ways, and both are inherent to being the thing that builds the stack:
#   - `secretmanager.secrets.setIamPolicy` can grant `secretAccessor` to anything, itself
#     included, and then read;
#   - `compute.instanceAdmin.v1` can set a VM's startup script, and the VM may read the
#     secrets it is entitled to.
# So this role is a guard against a careless read, not against a determined one. What it
# does buy is that a value cannot appear in a plan, in state, or in a log by accident, which
# is the failure R-SEC-01 is about. Closing the indirect paths means an apply account that
# cannot set IAM or create instances, which is an apply account that cannot apply.

resource "google_project_iam_custom_role" "tf_apply" {
  role_id     = "fetchpepDevTfApply"
  title       = "fetchpep-dev Terraform apply"
  description = "Secret containers and IAP tunnel policy. Excludes every permission that reads or writes a secret value directly; see the comment above for what it still reaches indirectly."

  permissions = [
    "secretmanager.secrets.create",
    "secretmanager.secrets.delete",
    "secretmanager.secrets.get",
    "secretmanager.secrets.list",
    "secretmanager.secrets.update",
    "secretmanager.secrets.getIamPolicy",
    "secretmanager.secrets.setIamPolicy",
    "iap.tunnelInstances.getIamPolicy",
    "iap.tunnelInstances.setIamPolicy",

    # Enabling an API, and **not** disabling one. `roles/serviceusage.serviceUsageAdmin`
    # includes `serviceusage.services.disable`, and the kill switch needs cloudfunctions,
    # run, eventarc, pubsub and billingbudgets to be on. An account that can switch those
    # off is an account that can stop the kill switch working (D-070).
    "serviceusage.services.enable",
    "serviceusage.services.get",
    "serviceusage.services.list",
    # Enabling a service returns a long-running operation, and the provider polls it.
    "serviceusage.operations.get",
    "resourcemanager.projects.get",
  ]

  # Kept although step 0 has already enabled IAM by hand: ordering costs nothing here, and
  # it is what makes a rebuild from the repository alone work without that step.
  depends_on = [google_project_service.federation]
}

resource "google_project_iam_custom_role" "tf_plan" {
  role_id     = "fetchpepDevTfPlan"
  title       = "fetchpep-dev Terraform plan"
  description = "The read half of fetchpepDevTfApply. A plan runs before anyone has read the pull request, so it gets no write."

  permissions = [
    "secretmanager.secrets.get",
    "secretmanager.secrets.list",
    "secretmanager.secrets.getIamPolicy",
    "iap.tunnelInstances.getIamPolicy",
    "serviceusage.services.get",
    "serviceusage.services.list",
    "resourcemanager.projects.get",
  ]

  # Kept although step 0 has already enabled IAM by hand: ordering costs nothing here, and
  # it is what makes a rebuild from the repository alone work without that step.
  depends_on = [google_project_service.federation]
}

# --------------------------------------------------------------- the runners
# Two accounts, not one. HCP Terraform mints a token whose `terraform_run_phase` claim says
# which it is, and the bindings below key on that. A plan on a pull request therefore reads;
# only an apply, which is manual (O-29), writes.

resource "google_service_account" "tfc_plan" {
  account_id   = "fetchpep-dev-tfc-plan"
  display_name = "HCP Terraform — plan phase, fetchpep-dev"
  description  = "Read-only. Impersonated by plan runs through workload identity (D-064). Holds no key."

  # Kept although step 0 has already enabled IAM by hand: ordering costs nothing here, and
  # it is what makes a rebuild from the repository alone work without that step.
  depends_on = [google_project_service.federation]
}

resource "google_service_account" "tfc_apply" {
  account_id   = "fetchpep-dev-tfc-apply"
  display_name = "HCP Terraform — apply phase, fetchpep-dev"
  description  = "Creates what infra/dev declares. Impersonated by apply runs only. Holds no key."

  # Kept although step 0 has already enabled IAM by hand: ordering costs nothing here, and
  # it is what makes a rebuild from the repository alone work without that step.
  depends_on = [google_project_service.federation]
}

# A map with **literal keys**, not a set. `for_each` keys have to be known at plan time, and
# a custom role's `id` is "known after apply" on a project where it does not exist yet — so a
# set built from it cannot be keyed and the plan fails with `Invalid for_each argument`
# before it creates anything. The value may be unknown; the key may not.
resource "google_project_iam_member" "tfc_plan" {
  for_each = {
    compute_viewer = "roles/compute.viewer"
    custom         = google_project_iam_custom_role.tf_plan.id
  }

  project = local.project_id
  role    = each.value
  member  = google_service_account.tfc_plan.member
}

# Literal keys, for the reason above.
resource "google_project_iam_member" "tfc_apply" {
  for_each = {
    # infra/dev/vm_nakama.tf — the instance, its boot disk, its metadata
    instance_admin = "roles/compute.instanceAdmin.v1"
    # infra/dev/network.tf — the VPC, the subnet, Cloud NAT and the router
    network_admin = "roles/compute.networkAdmin"
    # infra/dev/network.tf — the firewall rules
    security_admin = "roles/compute.securityAdmin"
    # infra/dev/snapshots.tf — the snapshot schedule, and the data disk
    storage_admin = "roles/compute.storageAdmin"
    # infra/dev/secrets.tf — the secret containers and who may read each one, and
    # infra/dev/network.tf — who may open an IAP tunnel. Never a secret value.
    custom = google_project_iam_custom_role.tf_apply.id
  }

  project = local.project_id
  role    = each.value
  member  = google_service_account.tfc_apply.member
}

# Only a run in the fetchpep-dev workspace, in the matching phase, may become the matching
# account. A token from another workspace, or from the other phase, maps to a different
# attribute value and matches nothing.
resource "google_service_account_iam_member" "tfc_plan_impersonation" {
  service_account_id = google_service_account.tfc_plan.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.hcp_terraform.name}/attribute.workspace_phase/${local.tfc_workspace}:plan"
}

resource "google_service_account_iam_member" "tfc_apply_impersonation" {
  service_account_id = google_service_account.tfc_apply.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.hcp_terraform.name}/attribute.workspace_phase/${local.tfc_workspace}:apply"
}

# ------------------------------------------------- the secret rotation topic
# Here rather than in infra/dev, for the same reason as the VM's identity above.
#
# Secret Manager refuses to put a rotation schedule on a secret unless a Pub/Sub topic is
# named and its own service agent can publish to it. Creating that topic and that binding
# from infra/dev would mean giving the Terraform runner Pub/Sub rights across the project —
# and `roles/pubsub.admin` includes `topics.delete`, `topics.setIamPolicy` and
# `subscriptions.delete`, which reach the kill switch's budget topic, its Eventarc
# subscription and its billing publisher grant (D-070). So the topic is created by the one
# apply that already runs with George's own rights, and infra/dev only names it in a string.

resource "google_pubsub_topic" "secret_rotation" {
  name = "fetchpep-dev-secret-rotation"

  message_storage_policy {
    allowed_persistence_regions = [local.location]
  }

  # Only this file's own API resource. Depending on the kill switch's `apis` would drag a
  # `kill_switch.tf` resource into the targeted first apply, which is exactly what D-099
  # forbids — see the note above `google_project_service.federation`.
  depends_on = [google_project_service.federation]
}

# [certain] Secret Manager publishes rotation notices as its own service agent, and refuses
# to create a secret with `topics` unless that agent can already publish. The address is the
# well-known one for the service, derived from the project number. The agent has to exist
# first — `ops/RUNBOOK.ops.md` Part 5 creates it before this stack is applied.
resource "google_pubsub_topic_iam_member" "secret_manager_publisher" {
  topic  = google_pubsub_topic.secret_rotation.id
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:service-${local.project_number}@gcp-sa-secretmanager.iam.gserviceaccount.com"
}

# ------------------------------------------------------------- the VM's identity
# Created here, not in infra/dev — see the header. Its own account, not the default Compute
# service account, which is Editor on the project: that would make a compromised container
# a compromised project.

resource "google_service_account" "nakama" {
  account_id   = "fetchpep-dev-nakama"
  display_name = "Nakama VM"
  description  = "The Nakama VM's own identity. Reads its secrets and writes logs. Nothing else."

  # Kept although step 0 has already enabled IAM by hand: ordering costs nothing here, and
  # it is what makes a rebuild from the repository alone work without that step.
  depends_on = [google_project_service.federation]
}

# Logs and metrics only. Access to a secret is granted per secret, in infra/dev/secrets.tf.
resource "google_project_iam_member" "nakama" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
  ])

  project = local.project_id
  role    = each.value
  member  = google_service_account.nakama.member
}

# The apply runner may attach **this one account** to the VM it creates. Not
# `roles/iam.serviceAccountUser` across the project, which is the right to act as any
# account in it, the default Compute account included; and not
# `roles/iam.serviceAccountAdmin`, which is the right to disable or delete any account, the
# kill switch's included (D-070).
resource "google_service_account_iam_member" "runner_uses_nakama" {
  service_account_id = google_service_account.nakama.name
  role               = "roles/iam.serviceAccountUser"
  member             = google_service_account.tfc_apply.member
}

# Both phases need to read it: infra/dev looks it up with a data source.
# Literal keys again: a service account's `member` is not known until it exists.
resource "google_service_account_iam_member" "runners_view_nakama" {
  for_each = {
    plan  = google_service_account.tfc_plan.member
    apply = google_service_account.tfc_apply.member
  }

  service_account_id = google_service_account.nakama.name
  role               = "roles/iam.serviceAccountViewer"
  member             = each.value
}

# ------------------------------------------------------------------- locals

locals {
  tfc_organization = "fetchpep" # ops/INFRA.ops.md; the HCP Terraform organisation
  tfc_workspace    = "fetchpep-dev"

  # Built by hand rather than from the resource, because the provider's own audience is
  # only known after it exists and `allowed_audiences` is an input to creating it.
  tfc_audience = "//iam.googleapis.com/projects/${local.project_number}/locations/global/workloadIdentityPools/fetchpep-dev-hcp-tf/providers/fetchpep-dev-hcp-tf"
}

# ------------------------------------------------------------------ outputs
# The values George sets on the fetchpep-dev workspace in HCP Terraform. None is a secret:
# they are names and an address. The secret is the token, and that is minted per run and
# never stored.

output "tfc_workspace_variables" {
  description = "Environment variables to set on the HCP Terraform workspace fetchpep-dev."
  value = {
    TFC_GCP_PROVIDER_AUTH               = "true"
    TFC_GCP_WORKLOAD_PROVIDER_NAME      = google_iam_workload_identity_pool_provider.hcp_terraform.name
    TFC_GCP_PLAN_SERVICE_ACCOUNT_EMAIL  = google_service_account.tfc_plan.email
    TFC_GCP_APPLY_SERVICE_ACCOUNT_EMAIL = google_service_account.tfc_apply.email
  }
}

output "nakama_service_account" {
  description = "The VM's identity, created here so that infra/dev never needs project IAM rights."
  value       = google_service_account.nakama.email
}

output "secret_rotation_topic" {
  description = "Where Secret Manager sends rotation notices. infra/dev names it in a string; nothing is subscribed to it yet (O-80)."
  value       = google_pubsub_topic.secret_rotation.id
}
