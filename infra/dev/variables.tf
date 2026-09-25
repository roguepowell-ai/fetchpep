# Inputs and the fixed names.
#
# Nothing here is a secret and nothing here is money. The secret *values* are added to
# Secret Manager by operations with gcloud and never reach Terraform, so they never reach
# HCP Terraform's state either (R-SEC-01, and O-57 — the state is held outside the UK).

variable "snapshot_retention_days" {
  description = "How long a daily boot-disk snapshot is kept before it is deleted."
  type        = number
  default     = 14

  validation {
    condition     = var.snapshot_retention_days >= 7 && floor(var.snapshot_retention_days) == var.snapshot_retention_days
    error_message = "snapshot_retention_days must be a whole number of at least 7."
  }
}

variable "first_rotation_time" {
  description = <<-EOT
    When the first rotation notice fires, RFC 3339 and in the future at apply time. Secret
    Manager moves it on by each secret's period after that, and `ignore_changes` in
    secrets.tf keeps Terraform from dragging it back. It is an input rather than a computed
    value because `timestamp()` would make every plan show a change.
  EOT
  type        = string
  default     = "2026-12-01T03:00:00Z"

  validation {
    condition     = can(formatdate("YYYY-MM-DD", var.first_rotation_time))
    error_message = "first_rotation_time must be an RFC 3339 timestamp, for example 2026-12-01T03:00:00Z."
  }
}

variable "pgdata_disk_gb" {
  description = "Size of the PostgreSQL data disk. Separate from the boot disk so that replacing the VM cannot destroy the database."
  type        = number
  default     = 20

  validation {
    condition     = var.pgdata_disk_gb >= 10
    error_message = "pgdata_disk_gb must be at least 10."
  }
}

variable "tunnel_users" {
  description = <<-EOT
    Principals who may open an IAP tunnel to the VM, each in IAM form, for example
    "user:someone@example.com". Empty by default: nobody reaches the VM until operations
    passes a list at apply. This is the only way in — the VM has no external IP and the
    only inbound rule is SSH from Google's IAP range.
  EOT
  type        = list(string)
  default     = []
}

locals {
  project_id     = "fetchpep-dev" # ops/INFRA.ops.md; permanent, public by design
  project_number = "424117215837" # same
  location       = "europe-west2" # London, D-043
  zone           = "europe-west2-a"

  # Infrastructure names use the codename, never the product name (D-034,
  # `.claude/rules/infra.md`).
  name = "fetchpep-dev-nakama"

  # [certain] IAP TCP forwarding always comes from this range. It is Google's, fixed, and
  # documented; it is not a guess and not a customer address.
  iap_range = "35.235.240.0/20"

  # Where the service lives on the VM. /var is the writable, persistent part of a
  # Container-Optimized OS disk — and [certain] it is mounted `noexec`, which is why the
  # startup script gives `app_dir/bin` its own exec bind-mount rather than assuming it can
  # run what it downloads there.
  app_dir = "/var/lib/fetchpep/nakama"

  # The PostgreSQL data directory, on its own disk. Not under app_dir: app_dir is on the
  # boot disk, and a boot disk is a thing that gets replaced.
  pgdata_dir = "/var/lib/fetchpep/pgdata"

  service_dir = "${path.module}/../../services/nakama"
}
