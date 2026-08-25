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
variable "run_id" {
  type = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{6,18}[a-z0-9]$", var.run_id))
    error_message = "run_id 형식 오류"
  }
}
variable "zone_one" { type = string }
variable "zone_two" { type = string }

provider "google" { project = var.project_id }

data "google_compute_image" "debian" {
  family  = "debian-12"
  project = "debian-cloud"
}

locals {
  labels = {
    harness = "gcp-lab-harness"
    phase   = "15"
    run     = var.run_id
  }
}

resource "google_compute_network" "mynetwork" {
  name                    = "mynetwork-${var.run_id}"
  auto_create_subnetworks = true
}

resource "google_compute_firewall" "mynetwork_lab" {
  name    = "mynetwork-allow-http-ssh-rdp-icmp-${var.run_id}"
  network = google_compute_network.mynetwork.self_link
  allow {
    protocol = "tcp"
    ports    = ["22", "80", "3389"]
  }
  allow { protocol = "icmp" }
  source_ranges = [
    "10.0.0.0/8",
    "172.16.0.0/12",
    "192.168.0.0/16",
    "35.235.240.0/20",
  ]
}

module "mynet_vm_1" {
  source           = "./modules/instance"
  instance_name    = "mynet-vm-1-${var.run_id}"
  instance_zone    = var.zone_one
  instance_network = google_compute_network.mynetwork.self_link
  source_image     = data.google_compute_image.debian.self_link
  labels           = local.labels
}

module "mynet_vm_2" {
  source           = "./modules/instance"
  instance_name    = "mynet-vm-2-${var.run_id}"
  instance_zone    = var.zone_two
  instance_network = google_compute_network.mynetwork.self_link
  source_image     = data.google_compute_image.debian.self_link
  labels           = local.labels
}

output "vm_one_name" { value = module.mynet_vm_1.name }
output "vm_two_name" { value = module.mynet_vm_2.name }
output "vm_two_internal_ip" { value = module.mynet_vm_2.internal_ip }
