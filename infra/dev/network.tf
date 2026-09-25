# The network the VM sits on. Nothing here is reachable from the internet.
#
# The shape: one VPC, one subnet, no external IP on anything. Outbound works through Cloud
# NAT, which is one-way — it lets the VM pull an image and reach Secret Manager, and gives
# nobody a way back in. The only inbound rule allows SSH from Google's IAP range, and even
# that reaches only a principal in `var.tunnel_users`, which is empty until operations
# passes one.
#
# The default network is not used. It comes with permissive rules nobody chose, including
# SSH from anywhere.

resource "google_compute_network" "main" {
  name                    = "fetchpep-dev"
  auto_create_subnetworks = false
  description             = "The only network in fetchpep-dev. No external addresses."

  depends_on = [google_project_service.apis]
}

resource "google_compute_subnetwork" "main" {
  name          = "fetchpep-dev-${local.location}"
  network       = google_compute_network.main.id
  region        = local.location
  ip_cidr_range = "10.20.0.0/24"

  # Logs are a data store (R-SEC-06). Flow logs record who talked to whom, so they are on
  # at a low sample rate and without payload metadata: enough to answer "did anything reach
  # this VM", not a second copy of the traffic.
  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.1
    metadata             = "EXCLUDE_ALL_METADATA"
  }

  private_ip_google_access = true
}

# ------------------------------------------------------------------ outbound
# The VM has no external IP, so without this it cannot pull an image or read a secret.
# NAT is outbound only: it creates no inbound path.

resource "google_compute_router" "nat" {
  name    = "fetchpep-dev-nat"
  network = google_compute_network.main.id
  region  = local.location
}

resource "google_compute_router_nat" "nat" {
  name                               = "fetchpep-dev-nat"
  router                             = google_compute_router.nat.name
  region                             = local.location
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.main.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# ------------------------------------------------------------------- inbound
# One rule. Everything else falls through to the implied deny.

resource "google_compute_firewall" "ssh_from_iap" {
  name        = "fetchpep-dev-ssh-from-iap"
  network     = google_compute_network.main.name
  description = "SSH, from Google's IAP forwarding range only. The only way to the VM."
  direction   = "INGRESS"
  priority    = 1000

  source_ranges = [local.iap_range]
  target_tags   = ["fetchpep-nakama"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Written out rather than left to the implied rule, so that a later rule cannot be added
# above it by accident and so the intent is visible in the plan. Priority 65534 is below
# anything anyone would write by hand.
resource "google_compute_firewall" "deny_all_ingress" {
  name        = "fetchpep-dev-deny-ingress"
  network     = google_compute_network.main.name
  description = "Everything else in. Stated, not implied."
  direction   = "INGRESS"
  priority    = 65534

  source_ranges = ["0.0.0.0/0"]

  deny {
    protocol = "all"
  }

  log_config {
    metadata = "EXCLUDE_ALL_METADATA"
  }
}

# --------------------------------------------------------------- who gets in
# Empty by default. A person reaches the VM with:
#
#   gcloud compute ssh fetchpep-dev-nakama --zone europe-west2-a --tunnel-through-iap \
#     -- -L 7351:localhost:7351
#
# The port-forward is what reaches the console and the API, because both are published on
# the VM's loopback only (services/nakama/docker-compose.yml).

resource "google_iap_tunnel_instance_iam_member" "tunnel" {
  for_each = toset(var.tunnel_users)

  project  = local.project_id
  zone     = local.zone
  instance = google_compute_instance.nakama.name
  role     = "roles/iap.tunnelResourceAccessor"
  member   = each.value
}
