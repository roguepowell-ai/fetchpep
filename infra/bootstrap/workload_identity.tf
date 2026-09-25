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
# The two the federation itself needs. Everything in the kill switch's list is enabled by
# `google_project_service.apis` in kill_switch.tf; a second resource for the same service
# would fight it, so these are only the ones that file does not already name.

resource "google_project_service" "federation" {
  for_each = toset([
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

resource "google_project_iam_custom_role" "tf_apply" {
  role_id     = "fetchpepDevTfApply"
  title       = "fetchpep-dev Terraform apply"
  description = "Secret containers and IAP tunnel policy. Deliberately excludes every permission that can read or write a secret value."

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
  ]
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
  ]
}

# --------------------------------------------------------------- the runners
# Two accounts, not one. HCP Terraform mints a token whose `terraform_run_phase` claim says
# which it is, and the bindings below key on that. A plan on a pull request therefore reads;
# only an apply, which is manual (O-29), writes.

resource "google_service_account" "tfc_plan" {
  account_id   = "fetchpep-dev-tfc-plan"
  display_name = "HCP Terraform — plan phase, fetchpep-dev"
  description  = "Read-only. Impersonated by plan runs through workload identity (D-064). Holds no key."
}

resource "google_service_account" "tfc_apply" {
  account_id   = "fetchpep-dev-tfc-apply"
  display_name = "HCP Terraform — apply phase, fetchpep-dev"
  description  = "Creates what infra/dev declares. Impersonated by apply runs only. Holds no key."
}

resource "google_project_iam_member" "tfc_plan" {
  for_each = toset([
    "roles/compute.viewer",
    "roles/pubsub.viewer",
    "roles/serviceusage.serviceUsageViewer",
    google_project_iam_custom_role.tf_plan.id,
  ])

  project = local.project_id
  role    = each.value
  member  = google_service_account.tfc_plan.member
}

resource "google_project_iam_member" "tfc_apply" {
  for_each = toset([
    # infra/dev/vm_nakama.tf — the instance, its boot disk, its metadata
    "roles/compute.instanceAdmin.v1",
    # infra/dev/network.tf — the VPC, the subnet, Cloud NAT and the router
    "roles/compute.networkAdmin",
    # infra/dev/network.tf — the firewall rules
    "roles/compute.securityAdmin",
    # infra/dev/snapshots.tf — the snapshot schedule, and the data disk
    "roles/compute.storageAdmin",
    # infra/dev/secrets.tf — the rotation notification topic and its publisher binding
    "roles/pubsub.admin",
    # infra/dev/versions.tf — enabling compute, secretmanager, pubsub and iap
    "roles/serviceusage.serviceUsageAdmin",
    # infra/dev/secrets.tf — the secret containers and who may read each one, and
    # infra/dev/network.tf — who may open an IAP tunnel. Never a secret value.
    google_project_iam_custom_role.tf_apply.id,
  ])

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

# ------------------------------------------------------------- the VM's identity
# Created here, not in infra/dev — see the header. Its own account, not the default Compute
# service account, which is Editor on the project: that would make a compromised container
# a compromised project.

resource "google_service_account" "nakama" {
  account_id   = "fetchpep-dev-nakama"
  display_name = "Nakama VM"
  description  = "The Nakama VM's own identity. Reads its secrets and writes logs. Nothing else."
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
resource "google_service_account_iam_member" "runners_view_nakama" {
  for_each = toset([
    google_service_account.tfc_plan.member,
    google_service_account.tfc_apply.member,
  ])

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
