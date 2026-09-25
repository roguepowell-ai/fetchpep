# The Nakama VM (D-055, D-063): one e2-small in London, running Nakama and PostgreSQL in
# containers on the same host.
#
# Container-Optimized OS rather than a general-purpose image: the whole payload is
# containers, and a read-only root with automatic updates is one fewer thing to patch. The
# service's files arrive as instance metadata and the startup script writes them out — see
# startup.sh.tftpl. Changing any of them changes the metadata, which is a diff in the plan.
#
# The VM's service account is created in infra/bootstrap, not here: granting it a
# project-level role needs the right to rewrite the project's IAM, which is not a right a
# Terraform runner should hold. This stack only reads it.

# `data.google_service_account.nakama` is declared in secrets.tf, next to the per-secret
# bindings that are the only interesting thing it has.

# -------------------------------------------------------------------- the image
# Pinned to the LTS milestone rather than a moving family, so a reboot cannot change the
# operating system underneath a running service.
data "google_compute_image" "cos" {
  family  = "cos-121-lts"
  project = "cos-cloud"
}

# ------------------------------------------------------------- the database disk
# Separate from the boot disk, and the reason is the `lifecycle` block below it.
#
# A boot disk is disposable: it holds the operating system, the containers and files that
# are rewritten from metadata at every boot. The database is not. Keeping PostgreSQL's data
# directory on its own disk means the VM can be replaced — by a new image, a machine type
# change, or a mistake — without taking the database with it.
resource "google_compute_disk" "pgdata" {
  name = "fetchpep-dev-nakama-pgdata"
  type = "pd-balanced"
  zone = local.zone
  size = var.pgdata_disk_gb

  labels = {
    service = "nakama"
    holds   = "postgres"
  }

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [google_project_service.apis]
}

# ------------------------------------------------------------------ the instance

resource "google_compute_instance" "nakama" {
  name         = local.name
  machine_type = "e2-small" # ops/COSTS.ops.md — the largest single line in the running cost
  zone         = local.zone
  description  = "Open-source Nakama and PostgreSQL 16 for the pilot (D-055, D-063)."

  tags = ["fetchpep-nakama"]

  boot_disk {
    initialize_params {
      image = data.google_compute_image.cos.self_link
      size  = 20
      type  = "pd-balanced"
      labels = {
        service = "nakama"
      }
    }
  }

  attached_disk {
    source      = google_compute_disk.pgdata.id
    device_name = "pgdata"
    mode        = "READ_WRITE"
  }

  network_interface {
    subnetwork = google_compute_subnetwork.main.id
    # No access_config block. That is what "no external IP" is: the absence of this.
  }

  service_account {
    email = data.google_service_account.nakama.email
    # The narrow scopes are obsolete once IAM is used, but the default set still includes
    # read-only storage. cloud-platform plus an account that holds almost nothing is the
    # current shape: IAM decides, not the scope.
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
      pgdata_dir      = local.pgdata_dir
      project_id      = local.project_id
      compose_version = local.compose_version
      compose_sha256  = local.compose_sha256
      secret_names    = join(" ", sort(keys(local.nakama_secrets)))
    })

    # The service, file by file. No secret is among them: nakama.yml carries placeholders
    # and the startup script fills them from Secret Manager (R-SEC-01).
    fetchpep-compose        = file("${local.service_dir}/docker-compose.yml")
    fetchpep-compose-vm     = file("${local.service_dir}/docker-compose.vm.yml")
    fetchpep-nakama-config  = file("${local.service_dir}/nakama.yml")
    fetchpep-render-config  = file("${local.service_dir}/render-config.sh")
    fetchpep-migrate-run    = file("${local.service_dir}/migrations/run.sh")
    fetchpep-migration-0001 = file("${local.service_dir}/migrations/0001_directory.sql")
    fetchpep-migration-0002 = file("${local.service_dir}/migrations/0002_shard_gi.sql")
    fetchpep-module         = file("${local.service_dir}/build/index.js")
  }

  # A stopped VM costs nothing but its disks.
  allow_stopping_for_update = true

  lifecycle {
    # `data.google_compute_image.cos` resolves the family at every plan, so the moment
    # Google publishes a new cos-121 image the plan wants a different boot image — and
    # changing a boot image replaces the instance. Without this, an unrelated plan would
    # offer to rebuild the VM. The database is on its own disk now, so that would no longer
    # lose data, but it would still be an outage nobody asked for. Moving to a new image is
    # a deliberate change: take this out, plan, read it, put it back.
    ignore_changes = [boot_disk[0].initialize_params[0].image]
  }

  # The VM is nothing without its secrets, and a boot with none fails loudly rather than
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
