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
    phase   = "11"
    run     = var.run_id
  }
  instance_prefix = "nginxstack"
  startup_script  = <<-EOT
    #!/usr/bin/env bash
    set -Eeuo pipefail
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y nginx stress-ng
    printf 'phase-11 %s\n' "$(hostname)" >/var/www/html/index.html
    systemctl enable --now nginx
  EOT
}

resource "google_compute_network" "main" {
  name                    = "p11-${var.run_id}"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "main" {
  name          = "p11-${var.run_id}"
  network       = google_compute_network.main.id
  region        = var.region
  ip_cidr_range = "10.11.0.0/24"
}

resource "google_compute_firewall" "iap_ssh" {
  name          = "p11-iap-${var.run_id}"
  network       = google_compute_network.main.name
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["p11-${var.run_id}"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "uptime_http" {
  name          = "p11-uptime-${var.run_id}"
  network       = google_compute_network.main.name
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["p11-${var.run_id}"]
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}

resource "google_service_account" "fixture" {
  account_id   = "p11-${substr(var.run_id, 0, 20)}"
  display_name = "Phase 11 fixture ${var.run_id}"
}

resource "google_compute_instance" "nginx" {
  count        = 3
  name         = "${local.instance_prefix}-${count.index + 1}-${var.run_id}"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["p11-${var.run_id}"]
  labels       = local.labels

  boot_disk {
    initialize_params {
      image = data.google_compute_image.debian.self_link
      size  = 10
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.main.id
    access_config {}
  }

  service_account {
    email  = google_service_account.fixture.email
    scopes = ["https://www.googleapis.com/auth/monitoring.write"]
  }

  metadata_startup_script = local.startup_script

  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = true
    enable_vtpm                 = true
  }
}

resource "google_monitoring_dashboard" "cpu" {
  dashboard_json = jsonencode({
    displayName = "Phase 11 ${var.run_id}"
    mosaicLayout = {
      columns = 12
      tiles = [{
        height = 4
        width  = 6
        widget = {
          title = "CPU utilization"
          xyChart = {
            dataSets = [{
              plotType = "LINE"
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "metric.type=\"compute.googleapis.com/instance/cpu/utilization\" AND resource.type=\"gce_instance\" AND metadata.user_labels.run=\"${var.run_id}\""
                  aggregation = {
                    alignmentPeriod  = "60s"
                    perSeriesAligner = "ALIGN_MEAN"
                  }
                }
              }
            }]
          }
        }
      }]
    }
  })
}

resource "google_monitoring_alert_policy" "cpu" {
  display_name = "Phase 11 CPU ${var.run_id}"
  combiner     = "AND"
  enabled      = true
  user_labels  = local.labels

  conditions {
    display_name = "CPU above 10 percent"
    condition_threshold {
      filter          = "metric.type=\"compute.googleapis.com/instance/cpu/utilization\" AND resource.type=\"gce_instance\" AND metadata.user_labels.run=\"${var.run_id}\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.10
      duration        = "60s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  conditions {
    display_name = "CPU above 20 percent"
    condition_threshold {
      filter          = "metric.type=\"compute.googleapis.com/instance/cpu/utilization\" AND resource.type=\"gce_instance\" AND metadata.user_labels.run=\"${var.run_id}\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.20
      duration        = "60s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  documentation {
    content   = "Phase 11 lab policy. Notification channels are intentionally not attached."
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_group" "nginx" {
  display_name = "Phase 11 nginx ${var.run_id}"
  filter       = "resource.metadata.user_labels.run = \"${var.run_id}\""
  is_cluster   = false
}

resource "google_monitoring_uptime_check_config" "nginx" {
  display_name = "Phase 11 uptime ${var.run_id}"
  timeout      = "10s"
  period       = "60s"
  selected_regions = [
    "USA",
    "EUROPE",
    "ASIA_PACIFIC",
  ]

  http_check {
    path           = "/"
    port           = 80
    request_method = "GET"
    use_ssl        = false
    validate_ssl   = false
  }

  resource_group {
    group_id      = google_monitoring_group.nginx.name
    resource_type = "gce_instance"
  }
}

output "instance_names" {
  value = google_compute_instance.nginx[*].name
}

output "dashboard_name" { value = google_monitoring_dashboard.cpu.id }
output "policy_name" { value = google_monitoring_alert_policy.cpu.name }
output "group_name" { value = google_monitoring_group.nginx.name }
output "uptime_name" { value = google_monitoring_uptime_check_config.nginx.name }
