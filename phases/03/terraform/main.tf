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
    error_message = "run_id는 8~20자의 소문자·숫자·하이픈이며 영숫자로 끝나야 합니다."
  }
}
variable "region" { type = string }
variable "zone" { type = string }
variable "secondary_zone" { type = string }
variable "client_source_cidr" {
  type = string
  validation {
    condition     = can(cidrhost(var.client_source_cidr, 0)) && var.client_source_cidr != "0.0.0.0/0" && var.client_source_cidr != "::/0"
    error_message = "client_source_cidr는 public 전체가 아닌 제한 CIDR이어야 합니다."
  }
}

provider "google" { project = var.project_id }

resource "google_compute_network" "auto" {
  project                 = var.project_id
  name                    = "mynetwork-${var.run_id}"
  auto_create_subnetworks = true
}

resource "google_compute_network" "management" {
  project                 = var.project_id
  name                    = "managementnet-${var.run_id}"
  auto_create_subnetworks = false
}

resource "google_compute_network" "private" {
  project                 = var.project_id
  name                    = "privatenet-${var.run_id}"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "management" {
  project       = var.project_id
  name          = "managementsubnet-${var.run_id}"
  region        = var.region
  network       = google_compute_network.management.id
  ip_cidr_range = "10.130.0.0/20"
}

resource "google_compute_subnetwork" "private" {
  project       = var.project_id
  name          = "privatesubnet-${var.run_id}"
  region        = var.region
  network       = google_compute_network.private.id
  ip_cidr_range = "172.16.0.0/24"
}

resource "google_service_account" "vm" {
  project      = var.project_id
  account_id   = "p03-${substr(var.run_id, 0, 19)}"
  display_name = "Phase 03 network probes ${var.run_id}"
}

locals {
  networks = {
    auto = {
      network = google_compute_network.auto.name
      tag     = "p03-auto"
    }
    management = {
      network = google_compute_network.management.name
      tag     = "p03-management"
    }
    private = {
      network = google_compute_network.private.name
      tag     = "p03-private"
    }
  }
}

resource "google_compute_firewall" "iap_ssh" {
  for_each = local.networks
  project  = var.project_id
  name     = "${each.key}-iap-ssh-${var.run_id}"
  network  = each.value.network
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["35.235.240.0/20"]
  target_tags   = [each.value.tag]
}

resource "google_compute_firewall" "external_icmp" {
  for_each = local.networks
  project  = var.project_id
  name     = "${each.key}-client-icmp-${var.run_id}"
  network  = each.value.network
  allow {
    protocol = "icmp"
  }
  source_ranges = [var.client_source_cidr]
  target_tags   = [each.value.tag]
}

resource "google_compute_firewall" "auto_internal_icmp" {
  project = var.project_id
  name    = "auto-internal-icmp-${var.run_id}"
  network = google_compute_network.auto.name
  allow {
    protocol = "icmp"
  }
  source_ranges = ["10.128.0.0/9"]
  target_tags   = ["p03-auto"]
}

resource "google_compute_instance" "auto_us" {
  project      = var.project_id
  name         = "mynet-us-vm-${var.run_id}"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["p03-auto"]
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }
  network_interface {
    network = google_compute_network.auto.id
    access_config {}
  }
  metadata = { enable-oslogin = "TRUE" }
  service_account {
    email  = google_service_account.vm.email
    scopes = ["https://www.googleapis.com/auth/logging.write"]
  }
}

resource "google_compute_instance" "auto_eu" {
  project      = var.project_id
  name         = "mynet-eu-vm-${var.run_id}"
  machine_type = "e2-micro"
  zone         = var.secondary_zone
  tags         = ["p03-auto"]
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }
  network_interface {
    network = google_compute_network.auto.id
    access_config {}
  }
  metadata = { enable-oslogin = "TRUE" }
  service_account {
    email  = google_service_account.vm.email
    scopes = ["https://www.googleapis.com/auth/logging.write"]
  }
}

resource "google_compute_instance" "management" {
  project      = var.project_id
  name         = "managementnet-vm-${var.run_id}"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["p03-management"]
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.management.id
    access_config {}
  }
  metadata = { enable-oslogin = "TRUE" }
  service_account {
    email  = google_service_account.vm.email
    scopes = ["https://www.googleapis.com/auth/logging.write"]
  }
}

resource "google_compute_instance" "private" {
  project      = var.project_id
  name         = "privatenet-vm-${var.run_id}"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["p03-private"]
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.private.id
    access_config {}
  }
  metadata = { enable-oslogin = "TRUE" }
  service_account {
    email  = google_service_account.vm.email
    scopes = ["https://www.googleapis.com/auth/logging.write"]
  }
}
