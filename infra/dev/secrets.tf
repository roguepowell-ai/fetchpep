# The runtime secrets (spec/DATA-MODEL.spec.md, *Files and names*).
#
# **Terraform creates the containers. It never creates a version.** That is the whole point
# of this file. A `random_password` resource would put the value in Terraform state, and
# the state is in HCP Terraform, outside the UK and EU (D-064, O-57). A value passed in as
# a variable would be in the plan. Either way the secret would exist somewhere it was not
# meant to, permanently (R-SEC-01).
#
# So the values are created by operations, in Cloud Shell, with George signed in, and go
# straight from `openssl` into Secret Manager without touching a file, a variable or an
# agent:
#
#   for s in nakama-db-password nakama-server-key nakama-http-key nakama-console-password; do
#     openssl rand -base64 33 | tr -d '\n' | tr '+/' '-_' | gcloud secrets versions add "$s" --data-file=-
#   done
#
# `tr '+/' '-_'` is not decoration: every value has to match ^[A-Za-z0-9_-]+$, because the
# database address is a URL where a raw `@` or `:` changes which host is connected to, and
# because render-config.sh substitutes with sed. See its header.
#
# The VM reads them at boot with its own service account. Nobody else can: the binding
# below is per secret, to that one account.
#
# The fifth name in the spec, `invite-email-hmac-key`, is deliberately **not** here. The
# brief asks for four, and the spec leaves where that key lives to this brief — but it is
# shared with the website (D-080), and there is no website and no decision about where it
# runs. A key with one holder and no second is a key whose sharing question is still open,
# so it is asked on issue #13 rather than answered in Terraform. See O-77.

locals {
  nakama_secrets = {
    "nakama-db-password"      = "PostgreSQL password for the nakama role"
    "nakama-server-key"       = "Nakama client server key — what a phone authenticates with"
    "nakama-http-key"         = "Nakama runtime HTTP key — the server-to-server doors (D-066)"
    "nakama-console-password" = "Nakama console password, for the admin user"
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

  depends_on = [google_project_service.apis]
}

# The VM's service account may read each one, and nothing else about them. Not
# secretmanager.admin, not project-wide: one role, per secret, to one account.
resource "google_secret_manager_secret_iam_member" "nakama_reader" {
  for_each = google_secret_manager_secret.nakama

  secret_id = each.value.id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.nakama.member
}
