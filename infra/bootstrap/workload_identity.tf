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

# ------------------------------------------------------------------------ APIs
# The two the federation itself needs. Everything in the kill switch's list is enabled by
# `google_project_service.apis` in kill_switch.tf; a second resource for the same service
# would fight it, so these are only the ones that file does not already name. The APIs
# `infra/dev` needs are enabled by `infra/dev`, which is why the runner below can do that.

resource "google_project_service" "federation" {
  for_each = toset([
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}

# ----------------------------------------------------------------- the pool
# One pool, one provider, for HCP Terraform and nothing else.

resource "google_iam_workload_identity_pool" "hcp_terraform" {
  workload_identity_pool_id = "fetchpep-hcp-tf"
  display_name              = "HCP Terraform"
  description               = "Short-lived credentials for HCP Terraform runs (D-064). No keys."

  depends_on = [google_project_service.federation]
}

resource "google_iam_workload_identity_pool_provider" "hcp_terraform" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.hcp_terraform.workload_identity_pool_id
  workload_identity_pool_provider_id = "fetchpep-hcp-tf"
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
  }

  # Belt as well as braces. The binding below already restricts which workspace may
  # impersonate the runner; this stops a token from any other organisation being exchanged
  # for a Google one at all, which is a shorter path to stop it on.
  attribute_condition = "assertion.terraform_organization_name == \"${local.tfc_organization}\""
}

# --------------------------------------------------------------- the runner
# One service account, used by HCP Terraform runs for the fetchpep-dev workspace. Its roles
# are exactly what infra/dev creates and no more — see the list below, each with what needs
# it. If an apply fails on a missing permission, the fix is another named role here, never
# roles/editor.

resource "google_service_account" "tfc_runner" {
  account_id   = "fetchpep-tfc-dev"
  display_name = "HCP Terraform runner — fetchpep-dev workspace"
  description  = "Impersonated by HCP Terraform runs through workload identity (D-064). Holds no key."
}

resource "google_project_iam_member" "tfc_runner" {
  for_each = toset([
    # infra/dev/vm_nakama.tf — the instance, its boot disk, its metadata
    "roles/compute.instanceAdmin.v1",
    # infra/dev/network.tf — the VPC, the subnet, Cloud NAT and the router
    "roles/compute.networkAdmin",
    # infra/dev/network.tf — the firewall rules
    "roles/compute.securityAdmin",
    # infra/dev/snapshots.tf — the snapshot schedule and its attachment to the boot disk
    "roles/compute.storageAdmin",
    # infra/dev/vm_nakama.tf — creating the VM's own service account
    "roles/iam.serviceAccountAdmin",
    # infra/dev/vm_nakama.tf — attaching that service account to the instance
    "roles/iam.serviceAccountUser",
    # infra/dev/secrets.tf — the secret containers and who may read each one. Never the
    # values: those are added by operations with gcloud and never pass through Terraform.
    "roles/secretmanager.admin",
    # infra/dev/versions.tf — enabling compute, secretmanager and iap in the project
    "roles/serviceusage.serviceUsageAdmin",
    # infra/dev/network.tf — who may open an IAP tunnel to the instance. The list is empty
    # unless operations passes one.
    "roles/iap.admin",
  ])

  project = local.project_id
  role    = each.value
  member  = google_service_account.tfc_runner.member
}

# Only runs in the fetchpep-dev workspace of the fetchpep organisation may become the
# runner. A token from another workspace maps to a different attribute and matches nothing.
resource "google_service_account_iam_member" "tfc_runner_impersonation" {
  service_account_id = google_service_account.tfc_runner.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.hcp_terraform.name}/attribute.terraform_workspace_name/${local.tfc_workspace}"
}

# ------------------------------------------------------------------- locals

locals {
  tfc_organization = "fetchpep" # ops/INFRA.ops.md; the HCP Terraform organisation
  tfc_workspace    = "fetchpep-dev"

  # Built by hand rather than from the resource, because the provider's own audience is
  # only known after it exists and `allowed_audiences` is an input to creating it.
  tfc_audience = "//iam.googleapis.com/projects/${local.project_number}/locations/global/workloadIdentityPools/fetchpep-hcp-tf/providers/fetchpep-hcp-tf"
}

# ------------------------------------------------------------------ outputs
# The three values George sets on the fetchpep-dev workspace in HCP Terraform. None is a
# secret: they are names and an address. The secret is the token, and that is minted per
# run and never stored.

output "tfc_workspace_variables" {
  description = "Environment variables to set on the HCP Terraform workspace fetchpep-dev."
  value = {
    TFC_GCP_PROVIDER_AUTH             = "true"
    TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL = google_service_account.tfc_runner.email
    TFC_GCP_WORKLOAD_PROVIDER_NAME    = google_iam_workload_identity_pool_provider.hcp_terraform.name
  }
}
