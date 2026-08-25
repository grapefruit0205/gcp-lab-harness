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
variable "runner_member" {
  type = string
  validation {
    condition     = can(regex("^(user|serviceAccount):[^[:space:]]+$", var.runner_member))
    error_message = "runner_member는 user: 또는 serviceAccount: 형식이어야 합니다."
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

resource "google_compute_network" "iam" {
  project                 = var.project_id
  name                    = "p07-net-${var.run_id}"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "iam" {
  project       = var.project_id
  name          = "p07-subnet-${var.run_id}"
  region        = var.region
  network       = google_compute_network.iam.id
  ip_cidr_range = "10.27.0.0/24"
}

resource "google_compute_firewall" "iap_ssh" {
  project = var.project_id
  name    = "p07-iap-ssh-${var.run_id}"
  network = google_compute_network.iam.name
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["p07-iam-probe"]
}

locals {
  accounts = {
    actor1   = "p07-a-${substr(var.run_id, 0, 19)}"
    actor2   = "p07-b-${substr(var.run_id, 0, 19)}"
    workload = "p07-w-${substr(var.run_id, 0, 19)}"
  }
}

resource "google_service_account" "test" {
  for_each     = local.accounts
  project      = var.project_id
  account_id   = each.value
  display_name = "Phase 07 ${each.key} ${var.run_id}"
}

resource "google_service_account_iam_member" "runner_impersonation" {
  for_each           = google_service_account.test
  service_account_id = each.value.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = var.runner_member
}

resource "google_storage_bucket" "iam" {
  project                     = var.project_id
  name                        = "gcp-lab-p07-${var.run_id}"
  location                    = "US"
  force_destroy               = true
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
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

resource "google_storage_bucket_iam_member" "workload_viewer" {
  bucket = google_storage_bucket.iam.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.test["workload"].email}"
}

output "test_actor_1" { value = google_service_account.test["actor1"].email }
output "test_actor_2" { value = google_service_account.test["actor2"].email }
output "workload_service_account" { value = google_service_account.test["workload"].email }
output "bucket_name" { value = google_storage_bucket.iam.name }
output "subnetwork_name" { value = google_compute_subnetwork.iam.name }
