terraform {
  required_version = "~> 1.15.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.45.0"
    }
  }
}

variable "project_id" { type = string }
variable "run_id" {
  type = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{6,18}[a-z0-9]$", var.run_id))
    error_message = "run_id 형식 오류"
  }
}
variable "region" { type = string }
variable "zone_one" { type = string }
variable "zone_two" { type = string }

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_compute_image" "debian" {
  family  = "debian-12"
  project = "debian-cloud"
}

locals {
  labels = {
    harness = "gcp-lab-harness"
    phase   = "14"
    run     = var.run_id
  }
  startup_script = <<-EOT
    #!/usr/bin/env bash
    set -Eeuo pipefail
    export DEBIAN_FRONTEND=noninteractive
    apt_retry() { for attempt in $(seq 1 6); do if timeout 180 "$@"; then return 0; fi; sleep 10; done; return 1; }
    apt_retry apt-get update
    apt_retry apt-get install -y apache2 libapache2-mod-php curl
    internal_ip="$(curl -fsS -H 'Metadata-Flavor: Google' http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)"
    zone="$(curl -fsS -H 'Metadata-Flavor: Google' http://metadata.google.internal/computeMetadata/v1/instance/zone | awk -F/ '{print $4}')"
    printf '%s' "$zone" >/var/www/p14-zone
    printf '%s\n' '<?php printf("<h1>Internal Load Balancing Lab</h1><h2>Client IP</h2>%s<h2>Hostname</h2>backend=%s<h2>Server Location</h2>%s", htmlspecialchars($_SERVER["REMOTE_ADDR"]), htmlspecialchars(gethostname()), htmlspecialchars(file_get_contents("/var/www/p14-zone"))); ?>' >/var/www/html/index.php
    printf 'DirectoryIndex index.php\n' >/etc/apache2/conf-available/p14-index.conf
    a2enconf p14-index
    systemctl enable --now apache2
  EOT
}

resource "google_compute_network" "main" {
  name                    = "my-internal-app-${var.run_id}"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "a" {
  name          = "subnet-a-${var.run_id}"
  network       = google_compute_network.main.id
  region        = var.region
  ip_cidr_range = "10.10.20.0/24"
}

resource "google_compute_subnetwork" "b" {
  name          = "subnet-b-${var.run_id}"
  network       = google_compute_network.main.id
  region        = var.region
  ip_cidr_range = "10.10.30.0/24"
}

resource "google_compute_firewall" "internal_icmp" {
  name          = "p14-internal-icmp-${var.run_id}"
  network       = google_compute_network.main.name
  source_ranges = ["10.10.0.0/16"]
  allow { protocol = "icmp" }
}

resource "google_compute_firewall" "iap_ssh" {
  name          = "p14-iap-ssh-${var.run_id}"
  network       = google_compute_network.main.name
  source_ranges = ["35.235.240.0/20"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "internal_http" {
  name          = "p14-internal-http-${var.run_id}"
  network       = google_compute_network.main.name
  source_ranges = ["10.10.0.0/16"]
  target_tags   = ["backend-service-${var.run_id}"]
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}

resource "google_compute_firewall" "health" {
  name          = "p14-health-${var.run_id}"
  network       = google_compute_network.main.name
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["backend-service-${var.run_id}"]
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}

resource "google_compute_router" "nat" {
  name    = "p14-router-${var.run_id}"
  network = google_compute_network.main.id
  region  = var.region
}

resource "google_compute_router_nat" "nat" {
  name                               = "p14-nat-${var.run_id}"
  router                             = google_compute_router.nat.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_compute_region_instance_template" "a" {
  name_prefix  = "p14-template-a-${var.run_id}-"
  region       = var.region
  machine_type = "e2-micro"
  tags         = ["backend-service-${var.run_id}"]
  labels       = local.labels
  disk {
    source_image = data.google_compute_image.debian.self_link
    auto_delete  = true
    boot         = true
    disk_size_gb = 10
    disk_type    = "pd-balanced"
  }
  network_interface { subnetwork = google_compute_subnetwork.a.id }
  metadata_startup_script = local.startup_script
  lifecycle { create_before_destroy = true }
}

resource "google_compute_region_instance_template" "b" {
  name_prefix  = "p14-template-b-${var.run_id}-"
  region       = var.region
  machine_type = "e2-micro"
  tags         = ["backend-service-${var.run_id}"]
  labels       = local.labels
  disk {
    source_image = data.google_compute_image.debian.self_link
    auto_delete  = true
    boot         = true
    disk_size_gb = 10
    disk_type    = "pd-balanced"
  }
  network_interface { subnetwork = google_compute_subnetwork.b.id }
  metadata_startup_script = local.startup_script
  lifecycle { create_before_destroy = true }
}

resource "google_compute_instance_group_manager" "a" {
  depends_on         = [google_compute_router_nat.nat]
  name               = "instance-group-1-${var.run_id}"
  zone               = var.zone_one
  base_instance_name = "p14-group1-${var.run_id}"
  target_size        = 1
  version { instance_template = google_compute_region_instance_template.a.id }
  named_port {
    name = "http"
    port = 80
  }
}

resource "google_compute_instance_group_manager" "b" {
  depends_on         = [google_compute_router_nat.nat]
  name               = "instance-group-2-${var.run_id}"
  zone               = var.zone_two
  base_instance_name = "p14-group2-${var.run_id}"
  target_size        = 1
  version { instance_template = google_compute_region_instance_template.b.id }
  named_port {
    name = "http"
    port = 80
  }
}

resource "google_compute_instance" "utility" {
  name         = "utility-vm-${var.run_id}"
  machine_type = "e2-micro"
  zone         = var.zone_one
  labels       = local.labels
  boot_disk {
    initialize_params {
      image = data.google_compute_image.debian.self_link
      size  = 10
      type  = "pd-balanced"
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.a.id
    network_ip = "10.10.20.50"
  }
  metadata_startup_script = <<-EOT
    #!/usr/bin/env bash
    set -Eeuo pipefail
    export DEBIAN_FRONTEND=noninteractive
    for attempt in $(seq 1 6); do if timeout 180 apt-get update && timeout 180 apt-get install -y curl; then break; fi; sleep 10; done
    command -v curl
  EOT
  depends_on              = [google_compute_router_nat.nat]
}

resource "google_compute_region_health_check" "ilb" {
  name                = "my-ilb-health-check-${var.run_id}"
  region              = var.region
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3
  tcp_health_check { port = 80 }
}

resource "google_compute_region_backend_service" "ilb" {
  name                  = "my-ilb-backend-${var.run_id}"
  region                = var.region
  protocol              = "TCP"
  load_balancing_scheme = "INTERNAL"
  health_checks         = [google_compute_region_health_check.ilb.id]
  backend { group = google_compute_instance_group_manager.a.instance_group }
  backend { group = google_compute_instance_group_manager.b.instance_group }
}

resource "google_compute_address" "ilb" {
  name         = "my-ilb-ip-${var.run_id}"
  region       = var.region
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.b.id
  address      = "10.10.30.5"
}

resource "google_compute_forwarding_rule" "ilb" {
  name                  = "my-ilb-${var.run_id}"
  region                = var.region
  load_balancing_scheme = "INTERNAL"
  network               = google_compute_network.main.id
  subnetwork            = google_compute_subnetwork.b.id
  backend_service       = google_compute_region_backend_service.ilb.id
  ip_address            = google_compute_address.ilb.address
  ip_protocol           = "TCP"
  ports                 = ["80"]
  allow_global_access   = false
}

output "ilb_address" { value = google_compute_address.ilb.address }
output "zone_one" { value = var.zone_one }
output "zone_two" { value = var.zone_two }
