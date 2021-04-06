resource "google_compute_firewall" "fw_access" {
  name    = "terraform-firewall"
  network = "${google_compute_network.vpc_network.name}"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "8080", "8090", "8081"]
  }

  source_ranges = ["0.0.0.0/0"]
}
