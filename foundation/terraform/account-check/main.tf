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
  description = "검증할 Google Cloud project ID"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "유효한 Google Cloud project ID가 필요합니다."
  }
}

provider "google" {
  project = var.project_id
}

data "google_project" "current" {
  project_id = var.project_id
}

output "project_id" {
  description = "ADC로 조회된 project ID"
  value       = data.google_project.current.project_id
}
