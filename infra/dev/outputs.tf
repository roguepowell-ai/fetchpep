# What operations needs after the apply. No secret is among them: an output is stored in
# state, and the state is in HCP Terraform (D-064, O-57).

output "instance" {
  description = "The VM's name and zone."
  value = {
    name = google_compute_instance.nakama.name
    zone = google_compute_instance.nakama.zone
  }
}

output "internal_ip" {
  description = "The VM's only address. There is no external one."
  value       = google_compute_instance.nakama.network_interface[0].network_ip
}

output "service_account" {
  description = "The VM's own identity. Reads four secrets, writes logs, nothing else."
  value       = google_service_account.nakama.email
}

output "secrets" {
  description = "The secret containers this stack created. Each needs a version added by hand before the VM will start — see the header of secrets.tf."
  value       = sort([for s in google_secret_manager_secret.nakama : s.secret_id])
}

output "reach_it" {
  description = "How to reach the console and the API. Both are on the VM's loopback only, so this is the only way."
  value       = <<-EOT
    Console (7351) and game API (7350), from Cloud Shell with George signed in:

      gcloud compute ssh ${google_compute_instance.nakama.name} \
        --zone ${google_compute_instance.nakama.zone} \
        --project ${local.project_id} \
        --tunnel-through-iap \
        -- -L 7351:localhost:7351 -L 7350:localhost:7350

    Then http://localhost:7351 for the console, and 7350 for the doors. Whoever runs it
    has to be in var.tunnel_users; the list is empty unless it was passed at apply.
  EOT
}
