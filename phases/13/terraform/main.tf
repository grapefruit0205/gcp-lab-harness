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
variable "zone" { type = string }
variable "secondary_region" { type = string }

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

data "google_compute_image" "debian" {
  family  = "debian-12"
  project = "debian-cloud"
}

locals {
  labels = {
    harness = "gcp-lab-harness"
    phase   = "13"
    run     = var.run_id
  }
  backend_startup = <<-EOT
    #!/usr/bin/env bash
    set -Eeuo pipefail
    printf '<html><body>backend=%s region=%s</body></html>\n' "$(hostname)" "$(curl -fsS -H 'Metadata-Flavor: Google' http://metadata.google.internal/computeMetadata/v1/instance/zone | awk -F/ '{print $4}')" >/var/www/html/index.html
    systemctl enable --now apache2
  EOT
}

resource "google_compute_network" "main" {
  name                    = "p13-${var.run_id}"
  auto_create_subnetworks = true
}

resource "google_compute_firewall" "health" {
  name          = "p13-health-${var.run_id}"
  network       = google_compute_network.main.name
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["p13-web-${var.run_id}"]
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}

resource "google_compute_firewall" "iap" {
  name          = "p13-iap-${var.run_id}"
  network       = google_compute_network.main.name
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["p13-iap-${var.run_id}"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_router" "nat" {
  name    = "p13-router-${var.run_id}"
  network = google_compute_network.main.id
  region  = var.region
}

resource "google_compute_router_nat" "nat" {
  name                               = "p13-nat-${var.run_id}"
  router                             = google_compute_router.nat.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_compute_instance" "builder" {
  name         = "p13-builder-${var.run_id}"
  machine_type = "e2-micro"
  zone         = var.zone
  labels       = local.labels
  tags         = ["p13-iap-${var.run_id}"]
  boot_disk {
    initialize_params {
      image = data.google_compute_image.debian.self_link
      size  = 10
      type  = "pd-balanced"
    }
  }
  network_interface { network = google_compute_network.main.id }
  metadata_startup_script = <<-EOT
    #!/usr/bin/env bash
    set -Eeuo pipefail
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y apache2 apache2-utils
    systemctl enable --now apache2
    printf '<html><body>golden-image</body></html>\n' >/var/www/html/index.html
    printf 'HARNESS_APACHE_VERSION=%s\n' "$(dpkg-query -W -f='$${Version}' apache2)" >/dev/ttyS0
    sync
    echo HARNESS_IMAGE_READY >/dev/ttyS0
  EOT
  depends_on              = [google_compute_router_nat.nat]
}

resource "terraform_data" "builder_ready" {
  triggers_replace = [google_compute_instance.builder.id]
  provisioner "local-exec" {
    command = "${path.module}/wait-builder.sh '${var.project_id}' '${var.zone}' '${google_compute_instance.builder.name}'"
  }
}

resource "google_compute_image" "webserver" {
  name        = "p13-webserver-${var.run_id}"
  source_disk = google_compute_instance.builder.boot_disk[0].source
  labels      = local.labels
  depends_on  = [terraform_data.builder_ready]
}

resource "google_compute_instance_template" "webserver" {
  name_prefix  = "p13-web-${var.run_id}-"
  machine_type = "e2-micro"
  tags         = ["p13-web-${var.run_id}"]
  labels       = local.labels
  disk {
    source_image = google_compute_image.webserver.self_link
    auto_delete  = true
    boot         = true
    disk_size_gb = 10
    disk_type    = "pd-balanced"
  }
  network_interface { network = google_compute_network.main.id }
  metadata_startup_script = local.backend_startup
  lifecycle { create_before_destroy = true }
}

resource "google_compute_health_check" "mig" {
  name                = "p13-mig-health-${var.run_id}"
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3
  http_health_check { port = 80 }
}

resource "google_compute_region_instance_group_manager" "backend" {
  for_each           = toset([var.region, var.secondary_region])
  name               = each.key == var.region ? "us-1-mig-${var.run_id}" : "notus-1-mig-${var.run_id}"
  region             = each.key
  base_instance_name = each.key == var.region ? "us-1-${var.run_id}" : "notus-1-${var.run_id}"
  target_size        = 1
  version { instance_template = google_compute_instance_template.webserver.id }
  named_port {
    name = "http"
    port = 80
  }
  auto_healing_policies {
    health_check      = google_compute_health_check.mig.id
    initial_delay_sec = 60
  }
}

resource "google_compute_region_autoscaler" "backend" {
  for_each = google_compute_region_instance_group_manager.backend
  name     = "${each.value.name}-autoscaler"
  region   = each.key
  target   = each.value.id
  autoscaling_policy {
    min_replicas    = 1
    max_replicas    = 2
    cooldown_period = 60
    load_balancing_utilization { target = 0.8 }
  }
}

resource "google_compute_health_check" "lb" {
  name                = "p13-lb-health-${var.run_id}"
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3
  http_health_check {
    port         = 80
    request_path = "/"
  }
}

resource "google_compute_backend_service" "http" {
  name                  = "p13-http-backend-${var.run_id}"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  timeout_sec           = 30
  health_checks         = [google_compute_health_check.lb.id]
  dynamic "backend" {
    for_each = google_compute_region_instance_group_manager.backend
    content {
      group                 = backend.value.instance_group
      balancing_mode        = "RATE"
      max_rate_per_instance = 50
      capacity_scaler       = 1.0
    }
  }
  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

resource "google_compute_url_map" "http" {
  name            = "p13-http-map-${var.run_id}"
  default_service = google_compute_backend_service.http.id
}

resource "google_compute_target_http_proxy" "http" {
  name    = "p13-http-proxy-${var.run_id}"
  url_map = google_compute_url_map.http.id
}

resource "google_compute_global_address" "ipv4" {
  name       = "p13-ipv4-${var.run_id}"
  ip_version = "IPV4"
}

resource "google_compute_global_address" "ipv6" {
  name       = "p13-ipv6-${var.run_id}"
  ip_version = "IPV6"
}

resource "google_compute_global_forwarding_rule" "ipv4" {
  name                  = "p13-http-ipv4-${var.run_id}"
  ip_address            = google_compute_global_address.ipv4.address
  ip_protocol           = "TCP"
  port_range            = "80"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  target                = google_compute_target_http_proxy.http.id
}

resource "google_compute_global_forwarding_rule" "ipv6" {
  name                  = "p13-http-ipv6-${var.run_id}"
  ip_address            = google_compute_global_address.ipv6.address
  ip_protocol           = "TCP"
  port_range            = "80"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  target                = google_compute_target_http_proxy.http.id
}

resource "google_compute_instance" "loadgen" {
  name         = "p13-loadgen-${var.run_id}"
  machine_type = "e2-micro"
  zone         = var.zone
  labels       = local.labels
  tags         = ["p13-iap-${var.run_id}"]
  boot_disk {
    initialize_params {
      image = data.google_compute_image.debian.self_link
      size  = 10
      type  = "pd-balanced"
    }
  }
  network_interface { network = google_compute_network.main.id }
  metadata_startup_script = <<-EOT
    #!/usr/bin/env bash
    set -Eeuo pipefail
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y apache2-utils curl
  EOT
  depends_on              = [google_compute_router_nat.nat]
}

output "ipv4_address" { value = google_compute_global_address.ipv4.address }
output "ipv6_address" { value = google_compute_global_address.ipv6.address }
output "backend_service" { value = google_compute_backend_service.http.name }
output "base_image_self_link" { value = data.google_compute_image.debian.self_link }
