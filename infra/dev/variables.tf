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
  # Container-Optimized OS disk.
  app_dir = "/var/lib/fetchpep/nakama"

  service_dir = "${path.module}/../../services/nakama"
}
