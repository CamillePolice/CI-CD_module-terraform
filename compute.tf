data "template_file" "metadata_startup_script_staging" {
  template = file("start-up-script_staging.sh")
}

data "template_file" "metadata_startup_script_prod" {
  template = file("start-up-script_prod.sh")
}

data "template_file" "metadata_startup_lb" {
  template = file("start-up-script_lb.sh")
}

resource "google_compute_address" "ip_address_staging" {
  name = "ipv4-address-staging"
}

resource "google_compute_address" "ip_address_prod" {
  name = "ipv4-address-prod"
}

resource "google_compute_instance" "vm_instance" {
  name         = "staging"
  machine_type = "n1-standard-1"
  zone         = var.zone

  metadata = {
    ssh-keys = "${var.gce_ssh_user}:${var.gce_ssh_pub_key_file}"
  }

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
    }
  }

  metadata_startup_script = data.template_file.metadata_startup_script_staging.rendered

  network_interface {
    network       = google_compute_network.vpc_network.self_link
    subnetwork       = google_compute_subnetwork.vpc_subnet.self_link
    access_config {
      nat_ip = google_compute_address.ip_address_staging.address
    }
  }
}

resource "google_compute_instance" "vm_instance2" {
  name         = "production"
  machine_type = "n1-standard-1"
  zone         = var.zone

  metadata = {
    ssh-keys = "${var.gce_ssh_user}:${var.gce_ssh_pub_key_file}"
  }

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
    }
  }

  metadata_startup_script = data.template_file.metadata_startup_script_prod.rendered

  network_interface {
    network       = google_compute_network.vpc_network.self_link
    subnetwork       = google_compute_subnetwork.vpc_subnet.self_link
    access_config {
      nat_ip = google_compute_address.ip_address_prod.address
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A FIREWALL RULE TO ALLOW TRAFFIC FROM ALL ADDRESSES
# ---------------------------------------------------------------------------------------------------------------------

resource "google_compute_firewall" "firewall" {
  project = var.project_name
  name    = "${var.name}-fw"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80", "8080", "8081" , "1000-2000"]
  }

  # These IP ranges are required for health checks
  source_ranges = ["0.0.0.0/0"]

  # Target tags define the instances to which the rule applies
  target_tags = [var.name]
}

# ------------------------------------------------------------------------------
# CREATE THE INTERNAL TCP LOAD BALANCER
# ------------------------------------------------------------------------------

module "lb" {

  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "github.com/gruntwork-io/terraform-google-load-balancer.git//modules/network-load-balancer?ref=v0.2.0"
  source  = "gruntwork-io/load-balancer/google"
  version = "0.3.0"

  name = "${var.project_name}-lb"
  region  = var.region
  zone = var.zone
  project = var.project_name
}

# ------------------------------------------------------------------------------
# HTTP PROXY
# ------------------------------------------------------------------------------

resource "google_compute_target_https_proxy" "default" {
  name             = "test-proxy"
  url_map          = google_compute_url_map.default.id
  ssl_certificates = [google_compute_ssl_certificate.default.id]
}

resource "google_compute_ssl_certificate" "default" {
  name        = "ssl-certificate"
  private_key = file("./ssl-keys/cici_module.key")
  certificate = file("./ssl-keys/cici_module.crt")
}

resource "google_compute_url_map" "default" {
  name        = "url-map"
  description = "ci-ci module"

  default_service = google_compute_backend_service.default.id

  host_rule {
    hosts        = ["34.117.15.44"] // TODO(Camille): IP VM PROD
    path_matcher = "allpaths"
  }

  path_matcher {
    name            = "allpaths"
    default_service = google_compute_backend_service.default.id

    path_rule {
      paths   = ["/home"]
      service = google_compute_backend_service.default.id
    }
  }
}

resource "google_compute_backend_service" "default" {
  name        = "backend-service"
  port_name   = "http"
  protocol    = "HTTP"
  timeout_sec = 10

  health_checks = [google_compute_http_health_check.default.id]
}

resource "google_compute_http_health_check" "default" {
  name               = "http-health-check"
  request_path       = "/"
  check_interval_sec = 1
  timeout_sec        = 1
}