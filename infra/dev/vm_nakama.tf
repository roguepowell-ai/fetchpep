# The Nakama VM (D-055, D-063): one e2-small in London, running Nakama and PostgreSQL in
# containers on the same host.
#
# Container-Optimized OS rather than a general-purpose image: the whole payload is
# containers, and a read-only root with automatic updates is one fewer thing to patch. The
# service's files arrive as instance metadata and the startup script writes them out — see
# startup.sh.tftpl. Changing any of them changes the metadata, which is a diff in the plan.

# ------------------------------------------------------------ the VM's identity
# Its own service account, not the default one. The default Compute service account is
# Editor on the whole project, which would make a compromised container a compromised
# project.

resource "google_service_account" "nakama" {
  account_id   = "fetchpep-dev-nakama"
  display_name = "Nakama VM"
  description  = "The Nakama VM's own identity. Reads four secrets and writes logs. Nothing else."
}

# Logs and metrics only. No storage, no compute, no project-wide secret access — that is
# granted per secret in secrets.tf.
resource "google_project_iam_member" "nakama" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
  ])

  project = local.project_id
  role    = each.value
  member  = google_service_account.nakama.member
}

# -------------------------------------------------------------------- the image
# Pinned to the LTS milestone rather than a moving family, so a reboot cannot change the
# operating system underneath a running service. Moving milestone is a change with a diff.
data "google_compute_image" "cos" {
  family  = "cos-121-lts"
  project = "cos-cloud"
}

# ------------------------------------------------------------------ the instance

resource "google_compute_instance" "nakama" {
  name         = local.name
  machine_type = "e2-small" # ops/COSTS.ops.md — this line is ~100% of the running cost
  zone         = local.zone
  description  = "Open-source Nakama and PostgreSQL 16 for the pilot (D-055, D-063)."

  tags = ["fetchpep-nakama"]

  boot_disk {
    initialize_params {
      image = data.google_compute_image.cos.self_link
      size  = 30
      type  = "pd-balanced"
      labels = {
        service = "nakama"
      }
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.main.id
    # No access_config block. That is what "no external IP" is: the absence of this.
  }

  service_account {
    email = google_service_account.nakama.email
    # The narrow scopes are obsolete once IAM is used, but the default set still includes
    # read-only storage. cloud-platform plus a service account that holds almost nothing is
    # the current shape: IAM decides, not the scope.
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata = {
    # SSH by IAM, through IAP. No project-wide SSH keys.
    enable-oslogin         = "TRUE"
    block-project-ssh-keys = "TRUE"

    # The serial console is a way in that bypasses IAP and OS Login. Off.
    serial-port-enable = "FALSE"

    # Container-Optimized OS: take the automatic updates.
    cos-update-strategy = "update_enabled"

    startup-script = templatefile("${path.module}/startup.sh.tftpl", {
      app_dir         = local.app_dir
      project_id      = local.project_id
      compose_version = local.compose_version
      compose_sha256  = local.compose_sha256
    })

    # The service, file by file. No secret is among them: nakama.yml carries placeholders
    # and the startup script fills them from Secret Manager (R-SEC-01).
    fetchpep-compose        = file("${local.service_dir}/docker-compose.yml")
    fetchpep-nakama-config  = file("${local.service_dir}/nakama.yml")
    fetchpep-render-config  = file("${local.service_dir}/render-config.sh")
    fetchpep-migrate-run    = file("${local.service_dir}/migrations/run.sh")
    fetchpep-migration-0001 = file("${local.service_dir}/migrations/0001_directory.sql")
    fetchpep-migration-0002 = file("${local.service_dir}/migrations/0002_shard_gi.sql")
    fetchpep-module         = file("${local.service_dir}/build/index.js")
  }

  # A stopped VM costs nothing but its disk. Nothing here holds state that a restart loses:
  # the database is on the boot disk and the disk survives.
  allow_stopping_for_update = true

  # The VM is nothing without them, and a boot with no secrets fails loudly rather than
  # starting an open server.
  depends_on = [
    google_secret_manager_secret_iam_member.nakama_reader,
    google_compute_router_nat.nat,
  ]
}

locals {
  # Container-Optimized OS ships Docker but not Compose. Exact version and checksum, both
  # from the release this was written against (ops/VERSIONS.ops.md).
  compose_version = "v5.5.1"
  compose_sha256  = "db1889184726840f75c4f9c001048430d4f25b3be3cb084d3ddd762bc0aed576"
}
