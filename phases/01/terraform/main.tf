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
  description = "Unique run ID"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{6,18}[a-z0-9]$", var.run_id))
    error_message = "run_id는 8~20자의 소문자·숫자·하이픈이며 영숫자로 끝나야 합니다."
  }
}

provider "google" {
  project = var.project_id
}

resource "google_storage_bucket" "console_equivalent" {
  project                     = var.project_id
  name                        = "gcp-lab-p01-console-${var.run_id}"
  location                    = "US"
  storage_class               = "STANDARD"
  force_destroy               = true
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  labels = {
    harness = "gcp-lab-harness"
    phase   = "01"
    run     = var.run_id
  }
}

resource "google_storage_bucket" "shell_equivalent" {
  project                     = var.project_id
  name                        = "gcp-lab-p01-shell-${var.run_id}"
  location                    = "US"
  storage_class               = "STANDARD"
  force_destroy               = true
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  labels = {
    harness = "gcp-lab-harness"
    phase   = "01"
    run     = var.run_id
  }
}

output "console_bucket_name" {
  value = google_storage_bucket.console_equivalent.name
}

output "shell_bucket_name" {
  value = google_storage_bucket.shell_equivalent.name
}
