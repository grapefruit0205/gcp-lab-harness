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
  description = "GCP Region"
}

variable "zone" {
  type        = string
  default     = "us-central1-c"
  description = "GCP Zone"
}

provider "google" {
  project = var.project_id
}

resource "google_compute_network" "p05_net" {
  project                 = var.project_id
  name                    = "gcp-lab-p05-net-${var.run_id}"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "p05_subnet" {
  project       = var.project_id
  name          = "gcp-lab-p05-subnet-${var.run_id}"
  ip_cidr_range = "10.10.0.0/24"
  region        = var.region
  network       = google_compute_network.p05_net.id
}

resource "google_compute_firewall" "iap_linux" {
  project = var.project_id
  name    = "gcp-lab-p05-fw-ssh-${var.run_id}"
  network = google_compute_network.p05_net.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["p05-linux"]
}

resource "google_compute_firewall" "iap_windows" {
  project = var.project_id
  name    = "gcp-lab-p05-fw-rdp-${var.run_id}"
  network = google_compute_network.p05_net.name

  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["p05-windows"]
}

resource "google_service_account" "vm" {
  project      = var.project_id
  account_id   = "p05-${substr(var.run_id, 0, 19)}"
  display_name = "Phase 05 VMs ${var.run_id}"
}

locals {
  linux_startup = <<-EOT
    #!/usr/bin/env bash
    set -Eeuo pipefail
    install -d -m 0755 /var/lib/gcp-lab-harness
    printf 'ready\n' >/var/lib/gcp-lab-harness/ready
    if command -v curl >/dev/null 2>&1; then
      curl --fail --silent --show-error --max-time 5 \
        -X PUT -H 'Metadata-Flavor: Google' \
        --data 'ready' \
        'http://metadata.google.internal/computeMetadata/v1/instance/guest-attributes/gcp-lab-harness/readiness' || true
    fi
  EOT

  windows_startup = <<-EOT
    $ErrorActionPreference = "Stop"
    New-Item -ItemType Directory -Force -Path "C:\\ProgramData\\gcp-lab-harness" | Out-Null
    $serviceReady = (Get-Service -Name TermService).Status -eq "Running"
    $portReady = (Test-NetConnection -ComputerName 127.0.0.1 -Port 3389 -InformationLevel Quiet)
    if (-not ($serviceReady -and $portReady)) { throw "RDP readiness failed" }
    Set-Content -Path "C:\\ProgramData\\gcp-lab-harness\\ready.txt" -Value "ready"
    Invoke-RestMethod -Method Put -Headers @{"Metadata-Flavor"="Google"} -Uri "http://metadata.google.internal/computeMetadata/v1/instance/guest-attributes/gcp-lab-harness/readiness" -Body "rdp-ready"
  EOT
}

resource "google_compute_instance" "utility_vm" {
  project      = var.project_id
  name         = "utility-vm-${var.run_id}"
  machine_type = "e2-medium"
  zone         = var.zone
  tags         = ["p05-linux"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.p05_subnet.id
  }

  metadata = {
    enable-oslogin          = "TRUE"
    enable-guest-attributes = "TRUE"
    startup-script          = local.linux_startup
  }

  service_account {
    email  = google_service_account.vm.email
    scopes = ["https://www.googleapis.com/auth/logging.write"]
  }
}

resource "google_compute_instance" "windows_vm" {
  project      = var.project_id
  name         = "windows-vm-${var.run_id}"
  machine_type = "e2-standard-2"
  zone         = var.zone
  tags         = ["p05-windows"]

  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2022-core"
      type  = "pd-ssd"
      size  = 64
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.p05_subnet.id
  }

  metadata = {
    enable-guest-attributes    = "TRUE"
    windows-startup-script-ps1 = local.windows_startup
  }

  service_account {
    email  = google_service_account.vm.email
    scopes = ["https://www.googleapis.com/auth/logging.write"]
  }
}

resource "google_compute_instance" "custom_vm" {
  project      = var.project_id
  name         = "custom-vm-${var.run_id}"
  machine_type = "e2-custom-2-4096"
  zone         = var.zone
  tags         = ["p05-linux"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.p05_subnet.id
  }

  metadata = {
    enable-oslogin          = "TRUE"
    enable-guest-attributes = "TRUE"
    startup-script          = local.linux_startup
  }

  service_account {
    email  = google_service_account.vm.email
    scopes = ["https://www.googleapis.com/auth/logging.write"]
  }
}

output "network_name" {
  value = google_compute_network.p05_net.name
}

output "utility_vm_name" {
  value = google_compute_instance.utility_vm.name
}

output "windows_vm_name" {
  value = google_compute_instance.windows_vm.name
}

output "custom_vm_name" {
  value = google_compute_instance.custom_vm.name
}
