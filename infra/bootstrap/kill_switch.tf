# The billing kill switch (D-070, brief B-001).
#
# Two budgets on the billing account, both scoped to fetchpep-dev only:
#   warn — emails the billing account's admins once spend passes var.warn_amount
#   kill — also emails, and publishes every notification to a Pub/Sub topic; a function
#          on that topic detaches billing from fetchpep-dev once actual spend passes
#          var.kill_amount
#
# Written once under D-070. After it is merged, no agent modifies this file — changing an
# amount is billing configuration, and that is George's (D-071).

# ---------------------------------------------------------------- inputs (D-071)
# Money is required and has no default. Operations passes the values at apply.

variable "billing_account" {
  description = "Billing account id attached to fetchpep-dev, in the form 000000-000000-000000."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9A-F]{6}-[0-9A-F]{6}-[0-9A-F]{6}$", var.billing_account))
    error_message = "billing_account must look like 000000-000000-000000 (no billingAccounts/ prefix)."
  }
}

variable "warn_amount" {
  description = "Monthly spend that sends a warning email, in the billing account's own currency. Whole units."
  type        = number
  nullable    = false

  validation {
    condition     = var.warn_amount > 0 && floor(var.warn_amount) == var.warn_amount
    error_message = "warn_amount must be a positive whole number."
  }
}

variable "kill_amount" {
  description = "Monthly spend past which billing is detached from fetchpep-dev, in the billing account's own currency. Whole units."
  type        = number
  nullable    = false

  validation {
    condition     = var.kill_amount > var.warn_amount && floor(var.kill_amount) == var.kill_amount
    error_message = "kill_amount must be a whole number greater than warn_amount."
  }
}

variable "dry_run" {
  description = "While true, the function logs \"would detach\" and changes nothing. George switches it off after the first test."
  type        = bool
  default     = true
}

locals {
  project_id     = "fetchpep-dev"
  project_number = "424117215837" # ops/INFRA.ops.md; public by design, permanent
  location       = "europe-west2" # D-043

  kill_budget_name = "fetchpep-dev-kill"

  # [certain] Pub/Sub budget notifications are published by this Google-owned account.
  budget_publisher = "serviceAccount:billing-budget-alert@system.gserviceaccount.com"

  # Spend is counted BEFORE credits.
  #
  # The switch exists for a runaway, and credits hide one: counted after credits, a loop
  # burning promotional or free-trial credit reads as zero, and the switch only starts
  # counting once the credit is gone and real money is moving. Billing data arrives hours
  # late, so by the time a net figure crosses the line the overrun has already happened.
  #
  # The cost of this choice is that gross spend is never below net, so the switch fires at
  # or before 30 of real money, never after. D-071 set 30 above normal running cost (the
  # e2-small at about 15.76 a month); gross cost adds whatever free-tier usage would have
  # absorbed, which at this scale is small but unmeasured until the first bill (O-23).
  credit_treatment = "EXCLUDE_ALL_CREDITS"
}

# ------------------------------------------------------------------------ APIs

resource "google_project_service" "apis" {
  for_each = toset([
    "artifactregistry.googleapis.com",
    "billingbudgets.googleapis.com",
    "cloudbilling.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "eventarc.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "pubsub.googleapis.com",
    "run.googleapis.com",
    "storage.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}

# ------------------------------------------------------------------ the topic

resource "google_pubsub_topic" "budget" {
  name = "fetchpep-dev-kill-budget"

  message_storage_policy {
    allowed_persistence_regions = [local.location]
  }

  depends_on = [google_project_service.apis]
}

resource "google_pubsub_topic_iam_member" "budget_publisher" {
  topic  = google_pubsub_topic.budget.id
  role   = "roles/pubsub.publisher"
  member = local.budget_publisher
}

# ---------------------------------------------------------------- the budgets
# No currency_code: the budget then takes the billing account's own currency (D-071).

resource "google_billing_budget" "warn" {
  billing_account = var.billing_account
  display_name    = "fetchpep-dev-warn"

  budget_filter {
    projects               = ["projects/${local.project_number}"]
    calendar_period        = "MONTH"
    credit_types_treatment = local.credit_treatment
  }

  amount {
    specified_amount {
      units = tostring(var.warn_amount)
    }
  }

  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "CURRENT_SPEND"
  }

  # No all_updates_rule: with none, crossing the threshold emails the billing account's
  # admins and users, which is George, and publishes nothing.

  depends_on = [google_project_service.apis]
}

resource "google_billing_budget" "kill" {
  billing_account = var.billing_account
  display_name    = local.kill_budget_name

  budget_filter {
    projects               = ["projects/${local.project_number}"]
    calendar_period        = "MONTH"
    credit_types_treatment = local.credit_treatment
  }

  amount {
    specified_amount {
      units = tostring(var.kill_amount)
    }
  }

  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "CURRENT_SPEND"
  }

  all_updates_rule {
    pubsub_topic                   = google_pubsub_topic.budget.id
    schema_version                 = "1.0"
    disable_default_iam_recipients = false
  }

  depends_on = [google_pubsub_topic_iam_member.budget_publisher]
}

# ------------------------------------------------------------ service accounts
# Three identities, each able to do one thing.

# Runs the function. Its only power is unlinking billing from fetchpep-dev.
resource "google_service_account" "kill_switch" {
  account_id   = "fetchpep-dev-kill-switch"
  display_name = "Billing kill switch: detaches billing from fetchpep-dev"
  depends_on   = [google_project_service.apis]
}

# [certain] resourcemanager.projects.deleteBillingAssignment is the permission that
# unlinks a project from its billing account, and it is supported in custom roles.
# Nothing here can link billing again, see the billing account, or touch any other
# project. Google's own sample grants Billing Account Administrator instead; that is the
# power to reassign or close the account, and a function has no need of it.
resource "google_project_iam_custom_role" "detach_billing" {
  role_id     = "fetchpepDevDetachBilling"
  title       = "Detach billing from this project"
  description = "Unlink the project from its billing account. Nothing else."
  permissions = ["resourcemanager.projects.deleteBillingAssignment"]
}

resource "google_project_iam_member" "kill_switch_detach" {
  project = local.project_id
  role    = google_project_iam_custom_role.detach_billing.id
  member  = google_service_account.kill_switch.member
}

# Delivers Pub/Sub messages to the function. Can invoke that one service and nothing else.
resource "google_service_account" "kill_trigger" {
  account_id   = "fetchpep-dev-kill-trigger"
  display_name = "Billing kill switch: delivers budget messages to the function"
  depends_on   = [google_project_service.apis]
}

resource "google_cloud_run_service_iam_member" "kill_trigger_invoke" {
  location = local.location
  service  = google_cloudfunctions2_function.kill_switch.service_config[0].service
  role     = "roles/run.invoker"
  member   = google_service_account.kill_trigger.member
}

# Builds the function. Named explicitly so the build depends on neither the Compute
# Engine default account (which does not exist until that API is on) nor its Editor role.
# [certain] Google documents three roles for a custom build account: log writer,
# Artifact Registry writer, and object viewer on the source, which the platform copies
# into its own gcf-v2-sources-* bucket before building.
resource "google_service_account" "kill_build" {
  account_id   = "fetchpep-dev-kill-build"
  display_name = "Billing kill switch: builds the function image"
  depends_on   = [google_project_service.apis]
}

resource "google_project_iam_member" "kill_build_logs" {
  project = local.project_id
  role    = "roles/logging.logWriter"
  member  = google_service_account.kill_build.member
}

# Object viewer at project level is what Google documents; the condition narrows it to the
# two buckets the build reads. [likely] The platform's bucket is named
# gcf-v2-sources-<project number>-<location>.
resource "google_project_iam_member" "kill_build_source" {
  project = local.project_id
  role    = "roles/storage.objectViewer"
  member  = google_service_account.kill_build.member

  condition {
    title       = "kill-switch-sources-only"
    description = "Only the kill-switch source bucket and the platform's function source bucket."
    expression  = <<-EOT
      resource.name.startsWith("projects/_/buckets/${google_storage_bucket.source.name}") ||
      resource.name.startsWith("projects/_/buckets/gcf-v2-sources-${local.project_number}-${local.location}")
    EOT
  }
}

resource "google_artifact_registry_repository" "kill_switch" {
  repository_id = "fetchpep-dev-kill-switch"
  location      = local.location
  format        = "DOCKER"
  description   = "Images of the billing kill switch function. Nothing else."

  depends_on = [google_project_service.apis]
}

# Writer on this one repository, not on every repository in the project.
resource "google_artifact_registry_repository_iam_member" "kill_build" {
  repository = google_artifact_registry_repository.kill_switch.name
  location   = local.location
  role       = "roles/artifactregistry.writer"
  member     = google_service_account.kill_build.member
}

# ------------------------------------------------------------------ the source

resource "google_storage_bucket" "source" {
  name                        = "fetchpep-dev-kill-switch-source"
  location                    = local.location
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true

  depends_on = [google_project_service.apis]
}

data "archive_file" "function" {
  type        = "zip"
  source_dir  = "${path.module}/function"
  output_path = "${path.module}/.build/kill-switch.zip"
  excludes    = ["node_modules", "kill-switch.test.cjs"]
}

# The object name carries the hash, so a change to the source redeploys the function.
resource "google_storage_bucket_object" "function" {
  bucket = google_storage_bucket.source.name
  name   = "kill-switch-${data.archive_file.function.output_md5}.zip"
  source = data.archive_file.function.output_path
}

# ---------------------------------------------------------------- the function

resource "google_cloudfunctions2_function" "kill_switch" {
  name     = "fetchpep-dev-kill-switch"
  location = local.location

  build_config {
    runtime           = "nodejs24"
    entry_point       = "killSwitch"
    service_account   = google_service_account.kill_build.id
    docker_repository = google_artifact_registry_repository.kill_switch.id

    source {
      storage_source {
        bucket = google_storage_bucket.source.name
        object = google_storage_bucket_object.function.name
      }
    }
  }

  service_config {
    min_instance_count             = 0
    max_instance_count             = 1 # infra rule 2: never the default
    available_memory               = "256M"
    timeout_seconds                = 60
    ingress_settings               = "ALLOW_INTERNAL_ONLY"
    all_traffic_on_latest_revision = true
    service_account_email          = google_service_account.kill_switch.email

    # The threshold is the function's own setting, not the amount a message carries, so
    # a message from any other budget cannot trip it.
    environment_variables = {
      PROJECT_ID  = local.project_id
      KILL_BUDGET = local.kill_budget_name
      KILL_AMOUNT = tostring(var.kill_amount)
      DRY_RUN     = var.dry_run ? "true" : "false"
    }
  }

  event_trigger {
    trigger_region        = local.location
    event_type            = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic          = google_pubsub_topic.budget.id
    retry_policy          = "RETRY_POLICY_RETRY"
    service_account_email = google_service_account.kill_trigger.email
  }

  depends_on = [
    google_project_iam_member.kill_build_logs,
    google_project_iam_member.kill_build_source,
    google_artifact_registry_repository_iam_member.kill_build,
  ]
}

# ------------------------------------------------------------------- outputs

output "function" {
  description = "Where the \"would detach\" line appears: Cloud Run functions, this name, Logs."
  value       = google_cloudfunctions2_function.kill_switch.name
}

output "topic" {
  description = "Publish a test notification here to exercise the function."
  value       = google_pubsub_topic.budget.id
}

output "dry_run" {
  value = var.dry_run
}
