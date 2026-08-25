terraform {
  required_version = "~> 1.15.0"
  required_providers { google = { source = "hashicorp/google", version = "~> 7.45.0" } }
}
variable "project_id" { type = string }
variable "run_id" {
  type = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{6,18}[a-z0-9]$", var.run_id))
    error_message = "run_id 형식 오류"
  }
}
provider "google" { project = var.project_id }
resource "google_bigquery_dataset" "billing" {
  project                     = var.project_id
  dataset_id                  = "billing_${replace(var.run_id, "-", "_")}"
  friendly_name               = "Phase 10 billing fixture ${var.run_id}"
  location                    = "US"
  default_table_expiration_ms = 86400000
  delete_contents_on_destroy  = true
  labels                      = { harness = "gcp-lab-harness", phase = "10", run = var.run_id }
}
output "dataset_id" { value = google_bigquery_dataset.billing.dataset_id }
