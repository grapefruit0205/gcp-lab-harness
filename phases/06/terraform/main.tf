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

variable "client_source_cidr" {
  type        = string
  description = "Minecraft client probe source CIDR"

  validation {
    condition     = can(cidrhost(var.client_source_cidr, 0)) && var.client_source_cidr != "0.0.0.0/0" && var.client_source_cidr != "::/0"
    error_message = "client_source_cidr는 public 전체가 아닌 유효한 제한 CIDR이어야 합니다."
  }
}

variable "minecraft_server_url" {
  type        = string
  description = "Pinned HTTPS Minecraft server artifact URL"

  validation {
    condition     = can(regex("^https://[A-Za-z0-9._~:/?#%&=+,-]+$", var.minecraft_server_url))
    error_message = "minecraft_server_url은 shell metacharacter가 없는 HTTPS URL이어야 합니다."
  }
}

variable "minecraft_server_sha256" {
  type        = string
  description = "Expected SHA-256 of the server artifact"

  validation {
    condition     = can(regex("^[a-f0-9]{64}$", var.minecraft_server_sha256))
    error_message = "minecraft_server_sha256은 소문자 SHA-256이어야 합니다."
  }
}

variable "jre_package_version" {
  type        = string
  description = "Exact Debian openjdk-17-jre-headless package version"

  validation {
    condition     = can(regex("^[A-Za-z0-9.+:~_-]+$", var.jre_package_version))
    error_message = "jre_package_version은 apt package version에 허용되는 문자만 포함해야 합니다."
  }
}

variable "minecraft_eula_accepted" {
  type        = bool
  description = "Explicit acceptance of the Minecraft EULA"

  validation {
    condition     = var.minecraft_eula_accepted
    error_message = "Minecraft EULA를 명시적으로 승인하지 않으면 apply할 수 없습니다."
  }
}

provider "google" {
  project = var.project_id
}

resource "google_compute_network" "p06_net" {
  project                 = var.project_id
  name                    = "gcp-lab-p06-net-${var.run_id}"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "p06_subnet" {
  project       = var.project_id
  name          = "gcp-lab-p06-subnet-${var.run_id}"
  ip_cidr_range = "10.20.0.0/24"
  region        = var.region
  network       = google_compute_network.p06_net.id
}

resource "google_compute_address" "mc_ip" {
  project = var.project_id
  name    = "mc-ip-${var.run_id}"
  region  = var.region
}

resource "google_compute_firewall" "iap_ssh" {
  project = var.project_id
  name    = "minecraft-iap-ssh-${var.run_id}"
  network = google_compute_network.p06_net.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["minecraft-server"]
}

resource "google_compute_firewall" "minecraft" {
  project = var.project_id
  name    = "minecraft-rule-${var.run_id}"
  network = google_compute_network.p06_net.name

  allow {
    protocol = "tcp"
    ports    = ["25565"]
  }

  source_ranges = [var.client_source_cidr]
  target_tags   = ["minecraft-server"]
}

resource "google_storage_bucket" "backup" {
  project                     = var.project_id
  name                        = "gcp-lab-p06-backup-${var.run_id}"
  location                    = "US"
  force_destroy               = true
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  labels = {
    harness = "gcp-lab-harness"
    phase   = "06"
    run     = var.run_id
  }
}

resource "google_service_account" "minecraft" {
  project      = var.project_id
  account_id   = "p06-${substr(var.run_id, 0, 19)}"
  display_name = "Phase 06 Minecraft ${var.run_id}"
}

resource "google_storage_bucket_iam_member" "backup_writer" {
  bucket = google_storage_bucket.backup.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.minecraft.email}"
}

resource "google_compute_disk" "minecraft" {
  project = var.project_id
  name    = "minecraft-disk-${var.run_id}"
  type    = "pd-ssd"
  zone    = var.zone
  size    = 50

  labels = {
    harness = "gcp-lab-harness"
    phase   = "06"
    run     = var.run_id
  }
}

locals {
  startup_script = <<-EOT
    #!/usr/bin/env bash
    set -Eeuo pipefail
    export DEBIAN_FRONTEND=noninteractive
    install -d -m 0755 /var/lib/gcp-lab-harness
    boot_count=0
    [[ ! -f /var/lib/gcp-lab-harness/boot-count ]] || boot_count="$(cat /var/lib/gcp-lab-harness/boot-count)"
    boot_count=$((boot_count + 1))
    printf '%s\n' "$boot_count" >/var/lib/gcp-lab-harness/boot-count

    device=/dev/disk/by-id/google-minecraft-disk
    for _ in $(seq 1 60); do
      [[ -b "$device" ]] && break
      sleep 2
    done
    [[ -b "$device" ]]
    if ! blkid "$device" >/dev/null 2>&1; then
      mkfs.ext4 -F -L minecraft-data "$device"
    fi
    uuid="$(blkid -s UUID -o value "$device")"
    install -d -m 0755 /srv/minecraft
    sed -i '\| /srv/minecraft |d' /etc/fstab
    printf 'UUID=%s /srv/minecraft ext4 defaults,nofail 0 2\n' "$uuid" >>/etc/fstab
    mountpoint -q /srv/minecraft || mount /srv/minecraft

    if ! id minecraft >/dev/null 2>&1; then
      useradd --system --home-dir /srv/minecraft --shell /usr/sbin/nologin minecraft
    fi
    chown minecraft:minecraft /srv/minecraft

    apt-get update -qq
    apt-get install -y -qq ca-certificates curl cron python3 "openjdk-17-jre-headless=${var.jre_package_version}"
    artifact_tmp="$(mktemp)"
    trap 'rm -f "$artifact_tmp"' EXIT
    curl --proto '=https' --tlsv1.2 --fail --location --silent --show-error --max-time 300 \
      --output "$artifact_tmp" '${var.minecraft_server_url}'
    printf '%s  %s\n' '${var.minecraft_server_sha256}' "$artifact_tmp" | sha256sum --check --status
    install -o minecraft -g minecraft -m 0644 "$artifact_tmp" /srv/minecraft/server.jar
    printf 'eula=true\n' >/srv/minecraft/eula.txt
    chown minecraft:minecraft /srv/minecraft/eula.txt

    cat >/etc/systemd/system/minecraft.service <<'UNIT'
    [Unit]
    Description=GCP lab Minecraft server
    After=network-online.target srv-minecraft.mount
    Wants=network-online.target

    [Service]
    Type=simple
    User=minecraft
    Group=minecraft
    WorkingDirectory=/srv/minecraft
    ExecStart=/usr/bin/java -Xms512M -Xmx1G -jar server.jar nogui
    ExecStop=/bin/kill -SIGINT $MAINPID
    Restart=on-failure
    RestartSec=5
    TimeoutStopSec=90

    [Install]
    WantedBy=multi-user.target
    UNIT

    cat >/usr/local/sbin/minecraft-backup <<'BACKUP'
    #!/usr/bin/env bash
    set -Eeuo pipefail
    bucket='${google_storage_bucket.backup.name}'
    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    archive="/tmp/minecraft-$stamp.tar.gz"
    digest="$archive.sha256"
    trap 'rm -f "$archive" "$digest"' EXIT
    tar -C /srv/minecraft -czf "$archive" --exclude=server.jar --exclude='*.tmp' .
    sha256sum "$archive" | awk '{print $1}' >"$digest"
    token="$(curl --fail --silent --show-error --max-time 5 -H 'Metadata-Flavor: Google' \
      'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token' | \
      python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')"
    for file in "$archive" "$digest"; do
      object="backups/$(basename "$file")"
      encoded="$(python3 -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$object")"
      curl --fail --silent --show-error --max-time 300 \
        -X POST -H "Authorization: Bearer $token" -H 'Content-Type: application/octet-stream' \
        --data-binary "@$file" \
        "https://storage.googleapis.com/upload/storage/v1/b/$bucket/o?uploadType=media&name=$encoded" >/dev/null
    done
    printf '%s\n' "backups/$(basename "$archive")"
    BACKUP
    chmod 0750 /usr/local/sbin/minecraft-backup

    cat >/etc/cron.d/minecraft-backup <<'CRON'
    15 2 * * * root /usr/local/sbin/minecraft-backup >>/var/log/minecraft-backup.log 2>&1
    CRON
    chmod 0644 /etc/cron.d/minecraft-backup

    systemctl daemon-reload
    systemctl enable --now cron minecraft.service
    for _ in $(seq 1 120); do
      [[ -f /srv/minecraft/world/level.dat ]] && break
      sleep 5
    done
    [[ -f /srv/minecraft/world/level.dat ]]
    /usr/local/sbin/minecraft-backup >/var/lib/gcp-lab-harness/last-backup-object
    curl --fail --silent --show-error --max-time 5 -X PUT -H 'Metadata-Flavor: Google' \
      --data 'ready' \
      'http://metadata.google.internal/computeMetadata/v1/instance/guest-attributes/gcp-lab-harness/readiness'
  EOT

  shutdown_script = <<-EOT
    #!/usr/bin/env bash
    set -Eeuo pipefail
    systemctl stop minecraft.service || true
    sync
    curl --fail --silent --show-error --max-time 5 -X PUT -H 'Metadata-Flavor: Google' \
      --data 'observed' \
      'http://metadata.google.internal/computeMetadata/v1/instance/guest-attributes/gcp-lab-harness/shutdown' || true
  EOT
}

resource "google_compute_instance" "mc_server" {
  project      = var.project_id
  name         = "mc-server-${var.run_id}"
  machine_type = "e2-medium"
  zone         = var.zone
  tags         = ["minecraft-server"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
      type  = "pd-balanced"
    }
  }

  attached_disk {
    source      = google_compute_disk.minecraft.id
    device_name = "minecraft-disk"
  }

  network_interface {
    subnetwork = google_compute_subnetwork.p06_subnet.id
    access_config {
      nat_ip = google_compute_address.mc_ip.address
    }
  }

  metadata = {
    enable-oslogin          = "TRUE"
    enable-guest-attributes = "TRUE"
    startup-script          = local.startup_script
    shutdown-script         = local.shutdown_script
  }

  service_account {
    email  = google_service_account.minecraft.email
    scopes = ["https://www.googleapis.com/auth/devstorage.read_write"]
  }

  depends_on = [google_storage_bucket_iam_member.backup_writer]
}

output "vm_name" {
  value = google_compute_instance.mc_server.name
}

output "vm_external_ip" {
  value     = google_compute_address.mc_ip.address
  sensitive = true
}

output "data_disk_name" {
  value = google_compute_disk.minecraft.name
}

output "backup_bucket_name" {
  value = google_storage_bucket.backup.name
}
