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
  type = string
}

variable "run_id" {
  type = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{7,19}$", var.run_id))
    error_message = "run_id는 8~20자의 소문자·숫자·하이픈이어야 합니다."
  }
}

provider "google" {
  project = var.project_id
}

resource "google_compute_network" "canary" {
  project                                   = var.project_id
  name                                      = "gcp-lab-canary-${var.run_id}"
  auto_create_subnetworks                   = false
  delete_default_routes_on_create           = true
  routing_mode                              = "REGIONAL"
  network_firewall_policy_enforcement_order = "AFTER_CLASSIC_FIREWALL"
}

output "network_name" {
  value = google_compute_network.canary.name
}
