terraform {
  required_version = "~> 1.15.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.45.0"
    }
  }
}

variable "project_id" {
  type        = string
  description = "Google Cloud project ID"
}

variable "run_id" {
  type        = string
  description = "Unique run ID for the harness execution"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{6,18}[a-z0-9]$", var.run_id))
    error_message = "run_id는 8~20자의 소문자·숫자·하이픈이며 영숫자로 끝나야 합니다."
  }
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "GCP Region for regional resources"
}

variable "zone" {
  type        = string
  default     = "us-central1-c"
  description = "GCP Zone for zonal resources"
}

provider "google" {
  project = var.project_id
}

resource "google_compute_network" "privatenet" {
  project                 = var.project_id
  name                    = "privatenet-${var.run_id}"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

# 한 저장 plan에서 disabled baseline과 enabled 결과를 함께 만든다.
# 두 VM에 동일한 probe를 실행해 PGA/NAT 차이를 실제 packet path로 확인한다.
resource "google_compute_subnetwork" "control" {
  project                  = var.project_id
  name                     = "privatenet-control-${var.run_id}"
  ip_cidr_range            = "10.130.0.0/24"
  region                   = var.region
  network                  = google_compute_network.privatenet.id
  private_ip_google_access = false
}

resource "google_compute_subnetwork" "enabled" {
  project                  = var.project_id
  name                     = "privatenet-enabled-${var.run_id}"
  ip_cidr_range            = "10.130.1.0/24"
  region                   = var.region
  network                  = google_compute_network.privatenet.id
  private_ip_google_access = true
}

resource "google_compute_firewall" "iap_ssh" {
  project = var.project_id
  name    = "privatenet-iap-ssh-${var.run_id}"
  network = google_compute_network.privatenet.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["p04-iap"]
}

resource "google_storage_bucket" "pga_bucket" {
  project                     = var.project_id
  name                        = "gcp-lab-p04-${var.run_id}"
  location                    = "US"
  force_destroy               = true
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  labels = {
    harness = "gcp-lab-harness"
    phase   = "04"
    run     = var.run_id
  }
}

resource "google_storage_bucket_object" "sample_object" {
  name         = "access.svg"
  bucket       = google_storage_bucket.pga_bucket.name
  content      = "<svg xmlns='http://www.w3.org/2000/svg' width='100' height='100'><text y='50'>Private Google Access Verified</text></svg>"
  content_type = "image/svg+xml"
}

resource "google_service_account" "probe" {
  project      = var.project_id
  account_id   = "p04-${substr(var.run_id, 0, 19)}"
  display_name = "Phase 04 probe ${var.run_id}"
}

resource "google_storage_bucket_iam_member" "probe_reader" {
  bucket = google_storage_bucket.pga_bucket.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.probe.email}"
}

resource "google_compute_instance" "control" {
  project      = var.project_id
  name         = "vm-control-${var.run_id}"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["p04-iap"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.control.id
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  service_account {
    email  = google_service_account.probe.email
    scopes = ["https://www.googleapis.com/auth/devstorage.read_only"]
  }
}

resource "google_compute_instance" "enabled" {
  project      = var.project_id
  name         = "vm-enabled-${var.run_id}"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["p04-iap"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.enabled.id
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  service_account {
    email  = google_service_account.probe.email
    scopes = ["https://www.googleapis.com/auth/devstorage.read_only"]
  }
}

resource "google_compute_router" "nat_router" {
  project = var.project_id
  name    = "nat-router-${var.run_id}"
  region  = var.region
  network = google_compute_network.privatenet.name
}

resource "google_compute_router_nat" "nat_config" {
  project                            = var.project_id
  name                               = "nat-config-${var.run_id}"
  router                             = google_compute_router.nat_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.enabled.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ALL"
  }
}

output "network_name" {
  value = google_compute_network.privatenet.name
}

output "control_vm_name" {
  value = google_compute_instance.control.name
}

output "enabled_vm_name" {
  value = google_compute_instance.enabled.name
}

output "bucket_name" {
  value = google_storage_bucket.pga_bucket.name
}

output "router_name" {
  value = google_compute_router.nat_router.name
}

output "nat_name" {
  value = google_compute_router_nat.nat_config.name
}
