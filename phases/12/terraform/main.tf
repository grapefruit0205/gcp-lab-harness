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
variable "region" { type = string }
variable "zone" { type = string }
variable "onprem_zone" {
  type = string
  validation {
    condition     = startswith(var.onprem_zone, "${var.region}-") && var.onprem_zone != var.zone
    error_message = "on-prem VM은 같은 region의 다른 zone에 배치해야 합니다."
  }
}
variable "secondary_region" { type = string }
variable "secondary_zone" { type = string }
variable "vpn_psk" {
  type      = string
  sensitive = true
  validation {
    condition     = length(var.vpn_psk) >= 40
    error_message = "VPN PSK는 40자 이상이어야 합니다."
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

data "google_compute_image" "debian" {
  family  = "debian-12"
  project = "debian-cloud"
}

locals {
  labels = {
    harness = "gcp-lab-harness"
    phase   = "12"
    run     = var.run_id
  }
  vpc_prefix     = "vpc-demo-${var.run_id}"
  onprem_prefix  = "on-prem-${var.run_id}"
  tunnel_indexes = toset(["0", "1"])
}

resource "google_compute_network" "vpc" {
  name                    = local.vpc_prefix
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

resource "google_compute_network" "onprem" {
  name                    = local.onprem_prefix
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "vpc_primary" {
  name          = "${local.vpc_prefix}-subnet1"
  network       = google_compute_network.vpc.id
  region        = var.region
  ip_cidr_range = "10.1.1.0/24"
}

resource "google_compute_subnetwork" "vpc_secondary" {
  name          = "${local.vpc_prefix}-subnet2"
  network       = google_compute_network.vpc.id
  region        = var.secondary_region
  ip_cidr_range = "10.2.1.0/24"
}

resource "google_compute_subnetwork" "onprem" {
  name          = "${local.onprem_prefix}-subnet1"
  network       = google_compute_network.onprem.id
  region        = var.region
  ip_cidr_range = "192.168.1.0/24"
}

resource "google_compute_firewall" "vpc_iap" {
  name          = "p12-vpc-iap-${var.run_id}"
  network       = google_compute_network.vpc.name
  source_ranges = ["35.235.240.0/20"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "onprem_iap" {
  name          = "p12-onprem-iap-${var.run_id}"
  network       = google_compute_network.onprem.name
  source_ranges = ["35.235.240.0/20"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "vpc_from_onprem" {
  name          = "p12-vpc-from-onprem-${var.run_id}"
  network       = google_compute_network.vpc.name
  source_ranges = [google_compute_subnetwork.onprem.ip_cidr_range]
  allow { protocol = "icmp" }
}

resource "google_compute_firewall" "onprem_from_vpc" {
  name    = "p12-onprem-from-vpc-${var.run_id}"
  network = google_compute_network.onprem.name
  source_ranges = [
    google_compute_subnetwork.vpc_primary.ip_cidr_range,
    google_compute_subnetwork.vpc_secondary.ip_cidr_range,
  ]
  allow { protocol = "icmp" }
}

resource "google_compute_instance" "vpc_primary" {
  name         = "vpc-demo-instance1-${var.run_id}"
  machine_type = "e2-micro"
  zone         = var.zone
  labels       = local.labels
  boot_disk {
    initialize_params {
      image = data.google_compute_image.debian.self_link
      size  = 10
      type  = "pd-balanced"
    }
  }
  network_interface { subnetwork = google_compute_subnetwork.vpc_primary.id }
}

resource "google_compute_instance" "vpc_secondary" {
  name         = "vpc-demo-instance2-${var.run_id}"
  machine_type = "e2-micro"
  zone         = var.secondary_zone
  labels       = local.labels
  boot_disk {
    initialize_params {
      image = data.google_compute_image.debian.self_link
      size  = 10
      type  = "pd-balanced"
    }
  }
  network_interface { subnetwork = google_compute_subnetwork.vpc_secondary.id }
}

resource "google_compute_instance" "onprem" {
  name         = "on-prem-instance1-${var.run_id}"
  machine_type = "e2-micro"
  zone         = var.onprem_zone
  labels       = local.labels
  boot_disk {
    initialize_params {
      image = data.google_compute_image.debian.self_link
      size  = 10
      type  = "pd-balanced"
    }
  }
  network_interface { subnetwork = google_compute_subnetwork.onprem.id }
}

resource "google_compute_ha_vpn_gateway" "vpc" {
  name    = "vpc-demo-vpn-gw1-${var.run_id}"
  network = google_compute_network.vpc.id
  region  = var.region
}

resource "google_compute_ha_vpn_gateway" "onprem" {
  name    = "on-prem-vpn-gw1-${var.run_id}"
  network = google_compute_network.onprem.id
  region  = var.region
}

resource "google_compute_router" "vpc" {
  name    = "vpc-demo-router1-${var.run_id}"
  network = google_compute_network.vpc.id
  region  = var.region
  bgp { asn = 65001 }
}

resource "google_compute_router" "onprem" {
  name    = "on-prem-router1-${var.run_id}"
  network = google_compute_network.onprem.id
  region  = var.region
  bgp { asn = 65002 }
}

resource "google_compute_vpn_tunnel" "vpc" {
  for_each              = local.tunnel_indexes
  name                  = "vpc-demo-tunnel${each.key}-${var.run_id}"
  region                = var.region
  vpn_gateway           = google_compute_ha_vpn_gateway.vpc.id
  vpn_gateway_interface = tonumber(each.key)
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.onprem.id
  shared_secret         = var.vpn_psk
  router                = google_compute_router.vpc.id
  ike_version           = 2
}

resource "google_compute_vpn_tunnel" "onprem" {
  for_each              = local.tunnel_indexes
  name                  = "on-prem-tunnel${each.key}-${var.run_id}"
  region                = var.region
  vpn_gateway           = google_compute_ha_vpn_gateway.onprem.id
  vpn_gateway_interface = tonumber(each.key)
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.vpc.id
  shared_secret         = var.vpn_psk
  router                = google_compute_router.onprem.id
  ike_version           = 2
}

resource "google_compute_router_interface" "vpc" {
  for_each   = local.tunnel_indexes
  name       = "if-tunnel${each.key}-to-on-prem"
  router     = google_compute_router.vpc.name
  region     = var.region
  ip_range   = each.key == "0" ? "169.254.0.1/30" : "169.254.1.1/30"
  vpn_tunnel = google_compute_vpn_tunnel.vpc[each.key].name
}

resource "google_compute_router_interface" "onprem" {
  for_each   = local.tunnel_indexes
  name       = "if-tunnel${each.key}-to-vpc-demo"
  router     = google_compute_router.onprem.name
  region     = var.region
  ip_range   = each.key == "0" ? "169.254.0.2/30" : "169.254.1.2/30"
  vpn_tunnel = google_compute_vpn_tunnel.onprem[each.key].name
}

resource "google_compute_router_peer" "vpc" {
  for_each        = local.tunnel_indexes
  name            = "bgp-on-prem-tunnel${each.key}"
  router          = google_compute_router.vpc.name
  region          = var.region
  interface       = google_compute_router_interface.vpc[each.key].name
  peer_ip_address = each.key == "0" ? "169.254.0.2" : "169.254.1.2"
  peer_asn        = 65002
}

resource "google_compute_router_peer" "onprem" {
  for_each        = local.tunnel_indexes
  name            = "bgp-vpc-demo-tunnel${each.key}"
  router          = google_compute_router.onprem.name
  region          = var.region
  interface       = google_compute_router_interface.onprem[each.key].name
  peer_ip_address = each.key == "0" ? "169.254.0.1" : "169.254.1.1"
  peer_asn        = 65001
}

output "vpc_primary_ip" { value = google_compute_instance.vpc_primary.network_interface[0].network_ip }
output "vpc_secondary_ip" { value = google_compute_instance.vpc_secondary.network_interface[0].network_ip }
output "onprem_ip" { value = google_compute_instance.onprem.network_interface[0].network_ip }
