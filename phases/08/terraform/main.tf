terraform {
  required_version = "~> 1.15.0"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 7.45.0" }
  }
}
variable "project_id" { type = string }
variable "run_id" {
  type = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{6,18}[a-z0-9]$", var.run_id))
    error_message = "run_id 형식이 올바르지 않습니다."
  }
}
provider "google" { project = var.project_id }
resource "google_storage_bucket" "lab" {
  project                     = var.project_id
  name                        = "gcp-lab-p08-${var.run_id}"
  location                    = "US"
  force_destroy               = true
  uniform_bucket_level_access = false
  public_access_prevention    = "inherited"
  versioning { enabled = true }
  lifecycle_rule {
    condition { age = 31 }
    action { type = "Delete" }
  }
  labels = { harness = "gcp-lab-harness", phase = "08", run = var.run_id }
}
output "bucket_name" { value = google_storage_bucket.lab.name }
