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
variable "region" { type = string }
variable "zone" { type = string }
variable "identity_mode" {
  type    = string
  default = "two-users"
  validation {
    condition     = var.identity_mode == "two-users"
    error_message = "Phase 07은 실제 사용자 두 계정 인증만 허용합니다."
  }
}
variable "user1" {
  type = string
  validation {
    condition     = can(regex("^[^[:space:]@]+@[^[:space:]@]+\\.[^[:space:]@]+$", var.user1)) && !endswith(lower(var.user1), ".gserviceaccount.com")
    error_message = "user1은 실제 Google 사용자 이메일이어야 합니다."
  }
}
variable "user2" {
  type = string
  validation {
    condition     = can(regex("^[^[:space:]@]+@[^[:space:]@]+\\.[^[:space:]@]+$", var.user2)) && !endswith(lower(var.user2), ".gserviceaccount.com") && lower(var.user2) != lower(var.user1)
    error_message = "user2는 user1과 다른 실제 Google 사용자 이메일이어야 합니다."
  }
}
variable "run_id" {
  type = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{6,18}[a-z0-9]$", var.run_id))
    error_message = "run_id 형식이 올바르지 않습니다."
  }
}

provider "google" { project = var.project_id }

resource "google_project_service" "resource_manager" {
  project                    = var.project_id
  service                    = "cloudresourcemanager.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
}

resource "google_compute_network" "iam" {
  project                 = var.project_id
  name                    = "p07-net-${var.run_id}"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "iam" {
  project                  = var.project_id
  name                     = "p07-subnet-${var.run_id}"
  region                   = var.region
  network                  = google_compute_network.iam.id
  ip_cidr_range            = "10.27.0.0/24"
  private_ip_google_access = true
}

resource "google_compute_firewall" "iap_ssh" {
  project   = var.project_id
  name      = "p07-iap-ssh-${var.run_id}"
  network   = google_compute_network.iam.name
  direction = "INGRESS"
  disabled  = false
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["p07-iam-probe"]
}

resource "google_service_account" "workload" {
  depends_on   = [google_project_service.resource_manager]
  project      = var.project_id
  account_id   = "p07-w-${var.run_id}"
  display_name = "Phase 07 read-bucket-objects ${var.run_id}"
}

resource "google_storage_bucket" "iam" {
  project                     = var.project_id
  name                        = "gcp-lab-p07-${var.run_id}"
  location                    = "US"
  storage_class               = "STANDARD"
  force_destroy               = true
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  soft_delete_policy {
    retention_duration_seconds = 0
  }
  labels = {
    harness = "gcp-lab-harness"
    phase   = "07"
    run     = var.run_id
  }
}

resource "google_storage_bucket_object" "sample" {
  name         = "sample.txt"
  bucket       = google_storage_bucket.iam.name
  content      = "Phase 07 IAM fixture ${var.run_id}\n"
  content_type = "text/plain"
}

resource "google_project_iam_member" "workload_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.workload.email}"
}

output "identity_mode" { value = var.identity_mode }
output "workload_service_account" { value = google_service_account.workload.email }
output "bucket_name" { value = google_storage_bucket.iam.name }
output "subnetwork_name" { value = google_compute_subnetwork.iam.name }
