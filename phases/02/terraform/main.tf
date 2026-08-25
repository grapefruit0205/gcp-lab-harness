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

variable "machine_type" {
  type        = string
  default     = "e2-standard-2"
  description = "Machine type specified in the original lab"
}

provider "google" {
  project = var.project_id
}

resource "google_compute_network" "jenkins_net" {
  project                 = var.project_id
  name                    = "gcp-lab-p02-net-${var.run_id}"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "jenkins_subnet" {
  project       = var.project_id
  name          = "gcp-lab-p02-subnet-${var.run_id}"
  ip_cidr_range = "10.128.0.0/20"
  region        = var.region
  network       = google_compute_network.jenkins_net.id
}

resource "google_compute_firewall" "jenkins_firewall" {
  project = var.project_id
  name    = "gcp-lab-p02-fw-${var.run_id}"
  network = google_compute_network.jenkins_net.name

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "8080"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["jenkins-server"]
}

resource "google_service_account" "jenkins_vm" {
  project      = var.project_id
  account_id   = "p02-${substr(var.run_id, 0, 19)}"
  display_name = "Phase 02 Jenkins ${var.run_id}"
}

resource "google_compute_instance" "jenkins_vm" {
  project      = var.project_id
  name         = "jenkins-1-vm-${var.run_id}"
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "click-to-deploy-images/jenkins-v20250921"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.jenkins_subnet.id
  }

  tags = ["jenkins-server", "http-server", "https-server"]

  metadata = {
    enable-oslogin = "TRUE"
  }

  service_account {
    email  = google_service_account.jenkins_vm.email
    scopes = ["https://www.googleapis.com/auth/logging.write"]
  }
}

output "network_name" {
  value = google_compute_network.jenkins_net.name
}

output "vm_name" {
  value = google_compute_instance.jenkins_vm.name
}

output "vm_zone" {
  value = google_compute_instance.jenkins_vm.zone
}

output "service_account_email" {
  value     = google_service_account.jenkins_vm.email
  sensitive = true
}
