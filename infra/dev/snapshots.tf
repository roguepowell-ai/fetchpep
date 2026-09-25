# Backups (D-063): a daily snapshot of the boot disk, kept for a bounded time.
#
# The boot disk is the whole of it. PostgreSQL's data directory is a docker volume on that
# disk, so a snapshot of the disk is a snapshot of the database — and of the migrations,
# the module and the rendered config with it.
#
# **Proposed retention: 14 days.** The reasoning, since the brief asks for a number rather
# than a default: the failure a snapshot has to survive is one nobody notices immediately —
# a bad migration, a deletion, a disk that goes wrong quietly. A week is short enough that
# a fortnight's holiday spans it. A month costs more than it is worth at this stage: a 30 GB
# disk with little churn snapshots to a few GB, and 14 dailies of it is well inside the
# £200 ceiling (ops/COSTS.ops.md) while 30 starts to be visible. Fourteen is also two
# weekly cycles, so a fault that only shows up on a particular day of the week is still
# recoverable. It is `var.snapshot_retention_days`, so changing it is a variable, not a
# rewrite.
#
# What this does not cover: a snapshot is not an export. It restores the whole disk, not one
# row and not one table. That is the right shape for the pilot and the wrong shape once
# there are real members — which belongs with O-66 and the retention question, not here.

resource "google_compute_resource_policy" "daily_snapshot" {
  name        = "fetchpep-dev-nakama-daily"
  region      = local.location
  description = "Daily boot-disk snapshot, kept ${var.snapshot_retention_days} days (D-063)."

  snapshot_schedule_policy {
    schedule {
      daily_schedule {
        days_in_cycle = 1
        # 03:10 UTC. Quiet, and not on the hour: every schedule in every project fires on
        # the hour, and a snapshot is cheaper when the disk is not busy.
        start_time = "03:10"
      }
    }

    retention_policy {
      max_retention_days    = var.snapshot_retention_days
      on_source_disk_delete = "KEEP_AUTO_SNAPSHOTS"
    }

    snapshot_properties {
      # London, like everything else (D-043, spec/PRIVACY.spec.md).
      storage_locations = [local.location]
      guest_flush       = false

      labels = {
        service = "nakama"
        managed = "terraform"
      }
    }
  }
}

resource "google_compute_disk_resource_policy_attachment" "nakama_boot" {
  name = google_compute_resource_policy.daily_snapshot.name
  # A Compute instance's boot disk takes the instance's name unless it is given another.
  disk = google_compute_instance.nakama.name
  zone = local.zone
}
