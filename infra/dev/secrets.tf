# The runtime secrets (D-089; spec/DATA-MODEL.spec.md, *Files and names*).
#
# **Terraform creates the containers and their rotation schedule. It never creates a
# version.** That is the whole point of this file. A `random_password` resource would put
# the value in Terraform state, and the state is in HCP Terraform, outside the UK and EU
# (D-064, O-57). A value passed in as a variable would be in the plan. Either way the secret
# would exist somewhere nobody chose, permanently (R-SEC-01).
#
# So values are created by operations, in Cloud Shell, with George signed in, and go
# straight from `openssl` into Secret Manager without touching a file, a variable, a repo or
# an agent. The command and the order are in ops/RUNBOOK.ops.md Part 5, which is also where
# the rotate procedure lives.
#
# Every value must match ^[A-Za-z0-9_-]+$. The database address is a URL, where a raw `@` or
# `:` changes which host is connected to, and `render-config.sh` substitutes with `sed`.
# That script refuses to render a value outside the set rather than corrupting the config
# quietly.
#
# **Rotation notices go to a topic, and nothing listens yet.** [certain] Secret Manager's
# rotation does not create a new version: it publishes a message saying one is due. The work
# is the rotate procedure in the runbook, run by a person. The schedule is what stops that
# being forgotten, and `rotation` cannot be set at all without a `topics` entry, which is
# why the topic exists.

# The rotation topic and its publisher grant are in **infra/bootstrap**, not here. Creating
# them from this stack would mean giving the Terraform runner Pub/Sub rights across the
# project, and `roles/pubsub.admin` reaches the kill switch's own topic, its Eventarc
# subscription and its billing publisher grant (D-070). Naming a topic costs no permission,
# so this stack only names it.
locals {
  secret_rotation_topic = "projects/${local.project_id}/topics/fetchpep-dev-secret-rotation"
}

locals {
  # Rotation periods, proposed. The reasoning is per secret, because "90 days for
  # everything" would be a number nobody chose.
  #
  # `rotate` says what a rotation costs, and the runbook's procedure follows from it.
  nakama_secrets = {
    "nakama-db-password" = {
      description = "PostgreSQL password for the nakama role"
      # 90 days. It is the one secret that a rotation can break, because the container's
      # POSTGRES_PASSWORD only takes effect at initdb; the startup script reconciles the
      # role to the current value on every boot.
      rotation_days = 90
      rotate        = "ALTER ROLE on the next boot, no downtime beyond the restart"
    }
    "nakama-server-key" = {
      description = "Nakama client server key — what a phone authenticates with"
      # 365 days, not 90. [certain] Rotating this locks out every installed client until it
      # ships a build carrying the new key, so it rotates with a release, not on a timer.
      # The schedule is the backstop that stops "with a release" meaning never.
      rotation_days = 365
      rotate        = "ships with a client release — every installed client is locked out until it does"
    }
    "nakama-http-key" = {
      description = "Nakama runtime HTTP key — the server-to-server doors (D-066)"
      # 90 days. Only the publish pipeline holds it; nothing installed depends on it.
      rotation_days = 90
      rotate        = "restart, and update whatever calls the publish door"
    }
    "nakama-console-password" = {
      description   = "Nakama console password, for the admin user"
      rotation_days = 90
      rotate        = "restart. Nobody but George reaches the console"
    }
    "nakama-session-encryption-key" = {
      description = "Signs player session tokens. Left unset, Nakama uses a published default"
      # 90 days. [certain] Rotating signs everyone out; tokens live 2 hours (nakama.yml), so
      # the cost is one sign-in.
      rotation_days = 90
      rotate        = "restart. Every player signs in again"
    }
    "nakama-session-refresh-encryption-key" = {
      description   = "Signs player refresh tokens. Left unset, Nakama uses a published default"
      rotation_days = 90
      rotate        = "restart. Every player signs in again"
    }
    "nakama-console-signing-key" = {
      description   = "Signs console tokens. Left unset, Nakama uses a published default"
      rotation_days = 90
      rotate        = "restart. The console asks for the password again"
    }
    "invite-email-hmac-key" = {
      description = "HMAC of an invited email address, shared with the website (D-080, D-090)"
      # 365 days. It is not a session key: `directory.fold_invite.hmac_key_version` records
      # which version made each row, so old invites stay checkable and a rotation does not
      # invalidate them. It also has a second holder that does not exist yet, so rotating it
      # is a two-sided step — see O-77.
      rotation_days = 365
      rotate        = "add a version, raise hmac_key_version for new invites, keep the old version readable for open ones"
    }
  }
}

resource "google_secret_manager_secret" "nakama" {
  for_each = local.nakama_secrets

  secret_id = each.key

  labels = {
    service = "nakama"
    managed = "terraform"
  }

  # Not automatic replication: that is multi-region and global. London only (D-043), and
  # spec/PRIVACY.spec.md keeps data in the UK or EU.
  replication {
    user_managed {
      replicas {
        location = local.location
      }
    }
  }

  topics {
    name = local.secret_rotation_topic
  }

  rotation {
    rotation_period = "${each.value.rotation_days * 24 * 60 * 60}s"

    # One period after the base, per secret — not the same date for all eight. With one
    # shared date the 365-day secrets would have sent their first notice on the base date,
    # which is the one thing a 365-day period is meant to avoid.
    next_rotation_time = timeadd(var.first_rotation_time, "${each.value.rotation_days * 24}h")
  }

  lifecycle {
    # Secret Manager advances `next_rotation_time` itself each time a notice fires. Without
    # this, the next plan would drag it back to the configured value and the schedule would
    # never move.
    ignore_changes = [rotation[0].next_rotation_time]
  }

  depends_on = [google_project_service.apis]
}

# The VM's service account may read each one, and nothing else about them. Not
# `secretmanager.admin`, not project-wide: one role, per secret, to one account. The account
# itself is created in infra/bootstrap — see the header there for why.
resource "google_secret_manager_secret_iam_member" "nakama_reader" {
  for_each = google_secret_manager_secret.nakama

  secret_id = each.value.id
  role      = "roles/secretmanager.secretAccessor"
  member    = data.google_service_account.nakama.member
}

data "google_service_account" "nakama" {
  account_id = "fetchpep-dev-nakama"
}
