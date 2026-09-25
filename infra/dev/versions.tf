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

# The APIs this stack needs. George switches them on by hand before the first apply
# (`ops/RUNBOOK.ops.md` Part 5 step 0); these declarations are the record rather than the
# mechanism, and they do nothing to a service that is already on. The apply runner's custom
# role carries `serviceusage.services.enable` and deliberately not `.disable` — see
# infra/bootstrap.
#
# `pubsub.googleapis.com` is not here: the rotation topic lives in the bootstrap stack,
# which enables Pub/Sub for the kill switch already.
resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "iap.googleapis.com",
    "oslogin.googleapis.com",
    "secretmanager.googleapis.com",
    # The VM's own account holds roles/logging.logWriter and roles/monitoring.metricWriter
    # (infra/bootstrap), so the VM needs both services on to write a line or a metric.
    # `logging` is also named in kill_switch.tf — a different stack and a different state, so
    # more separate than the overlap within bootstrap, and `disable_on_destroy = false` on
    # both. `monitoring` was declared nowhere until now, which would have left a rebuild from
    # the repository alone short of it.
    "logging.googleapis.com",
    "monitoring.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}
