terraform {
  required_version = "~> 1.15.0"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 7.45.0" }
  }
}
variable "project_id" { type = string }
variable "region" { type = string }
variable "zone" { type = string }
variable "run_id" {
  type = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{6,18}[a-z0-9]$", var.run_id))
    error_message = "run_id 형식 오류"
  }
}
variable "client_source_cidr" {
  type = string
  validation {
    condition     = can(cidrhost(var.client_source_cidr, 0)) && !contains(["0.0.0.0/0", "::/0"], var.client_source_cidr)
    error_message = "제한된 client CIDR가 필요합니다."
  }
}
variable "wordpress_url" { type = string }
variable "wordpress_sha256" { type = string }
variable "proxy_url" { type = string }
variable "proxy_sha256" { type = string }
variable "wp_cli_url" { type = string }
variable "wp_cli_sha256" { type = string }
provider "google" { project = var.project_id }

data "google_compute_image" "debian" {
  family  = "debian-12"
  project = "debian-cloud"
}

resource "google_compute_network" "sql" {
  project                 = var.project_id
  name                    = "p09-net-${var.run_id}"
  auto_create_subnetworks = false
}
resource "google_compute_subnetwork" "sql" {
  project       = var.project_id
  name          = "p09-subnet-${var.run_id}"
  region        = var.region
  network       = google_compute_network.sql.id
  ip_cidr_range = "10.29.0.0/24"
}
resource "google_compute_global_address" "private_services" {
  project       = var.project_id
  name          = "p09-psa-${var.run_id}"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 24
  network       = google_compute_network.sql.id
}
resource "google_service_networking_connection" "private_services" {
  network                 = google_compute_network.sql.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services.name]
}
resource "google_compute_firewall" "iap" {
  project = var.project_id
  name    = "p09-iap-ssh-${var.run_id}"
  network = google_compute_network.sql.name
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["p09-wordpress"]
}
resource "google_compute_firewall" "http" {
  project = var.project_id
  name    = "p09-http-${var.run_id}"
  network = google_compute_network.sql.name
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  source_ranges = [var.client_source_cidr]
  target_tags   = ["p09-wordpress"]
}
resource "google_service_account" "proxy" {
  project      = var.project_id
  account_id   = "p09-proxy-${substr(var.run_id, 0, 15)}"
  display_name = "Phase 09 proxy ${var.run_id}"
}
resource "google_service_account" "private" {
  project      = var.project_id
  account_id   = "p09-private-${substr(var.run_id, 0, 13)}"
  display_name = "Phase 09 private ${var.run_id}"
}
resource "google_project_iam_member" "proxy_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.proxy.email}"
}
resource "google_sql_database_instance" "wordpress" {
  project             = var.project_id
  name                = "wordpress-db-${var.run_id}"
  region              = var.region
  database_version    = "MYSQL_8_0"
  deletion_protection = false
  settings {
    tier              = "db-f1-micro"
    disk_type         = "PD_SSD"
    disk_size         = 10
    disk_autoresize   = false
    availability_type = "ZONAL"
    backup_configuration {
      enabled            = false
      binary_log_enabled = false
    }
    ip_configuration {
      ipv4_enabled    = true
      private_network = google_compute_network.sql.id
    }
    user_labels = { harness = "gcp-lab-harness", phase = "09", run = var.run_id }
  }
  depends_on = [google_service_networking_connection.private_services]
}
resource "google_sql_database" "wordpress" {
  project  = var.project_id
  name     = "wordpress"
  instance = google_sql_database_instance.wordpress.name
}

locals {
  common_startup = <<-EOT
    #!/usr/bin/env bash
    set -Eeuo pipefail
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq apache2 php libapache2-mod-php php-mysql php-curl php-gd php-mbstring php-xml php-zip default-mysql-client curl ca-certificates
    tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
    curl --proto '=https' --tlsv1.2 --fail --location --silent --show-error --max-time 300 -o "$tmp" '${var.wordpress_url}'
    printf '%s  %s\n' '${var.wordpress_sha256}' "$tmp" | sha256sum --check --status
    rm -rf /var/www/html/*; tar -xzf "$tmp" -C /var/www/html --strip-components=1
    curl --proto '=https' --tlsv1.2 --fail --location --silent --show-error --max-time 300 -o "$tmp" '${var.wp_cli_url}'
    printf '%s  %s\n' '${var.wp_cli_sha256}' "$tmp" | sha256sum --check --status
    install -m 0755 "$tmp" /usr/local/bin/wp
    chown -R www-data:www-data /var/www/html
    systemctl enable --now apache2
  EOT
  proxy_startup  = <<-EOT
    ${local.common_startup}
    tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
    curl --proto '=https' --tlsv1.2 --fail --location --silent --show-error --max-time 300 -o "$tmp" '${var.proxy_url}'
    printf '%s  %s\n' '${var.proxy_sha256}' "$tmp" | sha256sum --check --status
    install -m 0755 "$tmp" /usr/local/bin/cloud-sql-proxy
    cat >/etc/systemd/system/cloud-sql-proxy.service <<'UNIT'
    [Unit]
    After=network-online.target
    Wants=network-online.target
    [Service]
    User=nobody
    ExecStart=/usr/local/bin/cloud-sql-proxy --address=127.0.0.1 --port=3306 ${google_sql_database_instance.wordpress.connection_name}
    Restart=on-failure
    [Install]
    WantedBy=multi-user.target
    UNIT
    systemctl daemon-reload; systemctl enable --now cloud-sql-proxy
  EOT
}

resource "google_compute_instance" "proxy" {
  project      = var.project_id
  name         = "wordpress-proxy-${var.run_id}"
  zone         = var.zone
  machine_type = "e2-micro"
  tags         = ["p09-wordpress"]
  boot_disk {
    initialize_params {
      image = data.google_compute_image.debian.self_link
      size  = 10
      type  = "pd-balanced"
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.sql.id
    access_config {}
  }
  metadata = { enable-oslogin = "TRUE", startup-script = local.proxy_startup }
  service_account {
    email  = google_service_account.proxy.email
    scopes = ["https://www.googleapis.com/auth/sqlservice.admin", "https://www.googleapis.com/auth/logging.write"]
  }
}
resource "google_compute_instance" "private" {
  project      = var.project_id
  name         = "wordpress-private-${var.run_id}"
  zone         = var.zone
  machine_type = "e2-micro"
  tags         = ["p09-wordpress"]
  boot_disk {
    initialize_params {
      image = data.google_compute_image.debian.self_link
      size  = 10
      type  = "pd-balanced"
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.sql.id
    access_config {}
  }
  metadata = { enable-oslogin = "TRUE", startup-script = local.common_startup }
  service_account {
    email  = google_service_account.private.email
    scopes = ["https://www.googleapis.com/auth/logging.write"]
  }
}
output "sql_connection_name" { value = google_sql_database_instance.wordpress.connection_name }
output "sql_private_ip" {
  value     = google_sql_database_instance.wordpress.private_ip_address
  sensitive = true
}
