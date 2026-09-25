# Everything in fetchpep-dev that is not the bootstrap (D-064).
#
# Unlike infra/bootstrap, this stack runs **in** HCP Terraform, with credentials minted per
# run through the workload identity federation that bootstrap set up. No key exists.
#
# The apply is never an agent's and never automatic: the workspace is Manual apply (O-29),
# and operations applies it (D-067).

terraform {
  required_version = "1.16.4"

  cloud {
    organization = "fetchpep"

    workspaces {
      name = "fetchpep-dev"
    }
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "8.4.0"
    }
  }
}

provider "google" {
  project = local.project_id
  region  = local.location
  zone    = local.zone
}

# The APIs this stack needs. The runner has roles/serviceusage.serviceUsageAdmin for
# exactly this.
resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "iap.googleapis.com",
    "oslogin.googleapis.com",
    "secretmanager.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}
