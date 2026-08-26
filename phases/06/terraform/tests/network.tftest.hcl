mock_provider "google" {}

variables {
  project_id              = "phase06-policy-test"
  run_id                  = "testp006"
  minecraft_server_url    = "https://example.invalid/server.jar"
  minecraft_server_sha256 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  jre_package_version     = "17.0.20+8-1~deb12u1"
  minecraft_eula_accepted = true
}

run "public_minecraft_only" {
  command = plan

  variables {
    client_source_cidr = "0.0.0.0/0"
  }

  assert {
    condition = (
      google_compute_firewall.minecraft.source_ranges == toset(["0.0.0.0/0"]) &&
      length(google_compute_firewall.minecraft.allow) == 1 &&
      one(google_compute_firewall.minecraft.allow).protocol == "tcp" &&
      one(google_compute_firewall.minecraft.allow).ports == tolist(["25565"]) &&
      google_compute_firewall.minecraft.target_tags == toset(["minecraft-server"]) &&
      google_compute_firewall.minecraft.direction == "INGRESS" &&
      google_compute_firewall.minecraft.disabled == false
    )
    error_message = "공개 예외는 minecraft-server tag의 TCP 25565에만 적용해야 합니다."
  }

  assert {
    condition = (
      google_compute_firewall.iap_ssh.source_ranges == toset(["35.235.240.0/20"]) &&
      length(google_compute_firewall.iap_ssh.allow) == 1 &&
      one(google_compute_firewall.iap_ssh.allow).protocol == "tcp" &&
      one(google_compute_firewall.iap_ssh.allow).ports == tolist(["22"]) &&
      google_compute_firewall.iap_ssh.network == google_compute_firewall.minecraft.network &&
      google_compute_firewall.iap_ssh.target_tags == toset(["minecraft-server"]) &&
      google_compute_firewall.iap_ssh.direction == "INGRESS" &&
      google_compute_firewall.iap_ssh.disabled == false
    )
    error_message = "공개 서버에서도 SSH는 같은 network의 IAP source만 허용해야 합니다."
  }

  assert {
    condition = (
      google_storage_bucket.backup.public_access_prevention == "enforced" &&
      google_storage_bucket.backup.uniform_bucket_level_access
    )
    error_message = "게임 포트 공개로 backup bucket이 공개되면 안 됩니다."
  }
}

run "restricted_cidr_still_supported" {
  command = plan

  variables {
    client_source_cidr = "192.0.2.10/32"
  }

  assert {
    condition     = google_compute_firewall.minecraft.source_ranges == toset(["192.0.2.10/32"])
    error_message = "명시적으로 지정한 제한 CIDR은 유지해야 합니다."
  }
}

run "reject_ipv6_on_ipv4_vm" {
  command = plan

  variables {
    client_source_cidr = "::/0"
  }

  expect_failures = [var.client_source_cidr]
}

run "reject_invalid_cidr" {
  command = plan

  variables {
    client_source_cidr = "not-a-cidr"
  }

  expect_failures = [var.client_source_cidr]
}
