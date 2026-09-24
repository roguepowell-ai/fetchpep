# The bootstrap stack: trust setup and the billing kill switch (D-064).
# Applied once from Cloud Shell with George signed in (D-067, D-070). Never by an agent.

terraform {
  required_version = "1.16.4"

  # State lives in HCP Terraform (D-064). The workspace runs in local execution mode:
  # the plan and apply happen in Cloud Shell under George's own Google sign-in, and only
  # the state is stored remotely. No cloud key exists anywhere.
  cloud {
    organization = "fetchpep"

    workspaces {
      name = "fetchpep-bootstrap"
    }
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "8.4.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "2.8.1"
    }
  }
}

provider "google" {
  project = local.project_id
  region  = local.location

  # Budgets are an account-level API. Applied with a person's credentials rather than a
  # service account, the calls need a project to bill quota against, or they are refused.
  user_project_override = true
  billing_project       = local.project_id
}
