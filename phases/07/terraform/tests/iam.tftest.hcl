mock_provider "google" {}

variables {
  project_id    = "phase07-policy-test"
  run_id        = "testp007"
  region        = "us-central1"
  zone          = "us-central1-a"
  user1         = "admin@example.com"
  user2         = "lab-user@example.com"
}

run "private_network_and_bucket" {
  command = plan

  assert {
    condition = (
      google_compute_subnetwork.iam.private_ip_google_access &&
      !google_compute_network.iam.auto_create_subnetworks &&
      google_compute_firewall.iap_ssh.source_ranges == toset(["35.235.240.0/20"]) &&
      google_compute_firewall.iap_ssh.direction == "INGRESS" &&
      google_compute_firewall.iap_ssh.disabled == false &&
      length(google_compute_firewall.iap_ssh.allow) == 1 &&
      one(google_compute_firewall.iap_ssh.allow).protocol == "tcp" &&
      one(google_compute_firewall.iap_ssh.allow).ports == tolist(["22"])
    )
    error_message = "private VM의 Google API 접근과 IAP-only SSH가 필요합니다."
  }
  assert {
    condition = (
      google_storage_bucket.iam.uniform_bucket_level_access &&
      google_storage_bucket.iam.location == "US" && google_storage_bucket.iam.storage_class == "STANDARD" &&
      google_storage_bucket.iam.public_access_prevention == "enforced" &&
      one(google_storage_bucket.iam.soft_delete_policy).retention_duration_seconds == 0 &&
      google_storage_bucket_object.sample.content == "Phase 07 IAM fixture ${var.run_id}\n"
    )
    error_message = "실습 bucket은 비공개이며 soft-delete 잔여 비용을 만들지 않아야 합니다."
  }
}

run "real_users_and_one_workload_account" {
  command = plan

  assert {
    condition = (
      google_service_account.workload.account_id == "p07-w-${var.run_id}" &&
      google_project_iam_member.workload_viewer.project == var.project_id &&
      google_project_iam_member.workload_viewer.role == "roles/storage.objectViewer" &&
      var.user1 != var.user2 && var.identity_mode == "two-users"
    )
    error_message = "실제 User1/User2와 VM workload SA 하나·project Object Viewer가 필요합니다. User2 actAs는 승인된 Task 6에서 임시 부여합니다."
  }
}

run "resource_manager_enabled_without_shared_api_teardown" {
  command = plan

  assert {
    condition = (
      google_project_service.resource_manager.service == "cloudresourcemanager.googleapis.com" &&
      google_project_service.resource_manager.disable_on_destroy == false &&
      google_project_service.resource_manager.disable_dependent_services == false
    )
    error_message = "SA consumer가 사용할 API를 활성화하고 destroy 때 다른 workload의 공용 API를 끄지 않습니다."
  }
}

run "full_run_identity_not_truncated" {
  command = plan

  variables {
    run_id = "abcdefghijklmnopqrst"
  }
  assert {
    condition     = google_service_account.workload.account_id == "p07-w-abcdefghijklmnopqrst"
    error_message = "20자 run ID도 잘리지 않아야 다른 run과 충돌하지 않습니다."
  }
}

run "reject_public_user" {
  command = plan
  variables {
    user1 = "allUsers"
  }
  expect_failures = [var.user1]
}

run "reject_service_account_as_user2" {
  command = plan
  variables {
    user2 = "actor@test.iam.gserviceaccount.com"
  }
  expect_failures = [var.user2]
}

run "reject_same_user_twice" {
  command = plan
  variables {
    user2 = "admin@example.com"
  }
  expect_failures = [var.user2]
}

run "reject_invalid_run" {
  command = plan
  variables {
    run_id = "../other-run"
  }
  expect_failures = [var.run_id]
}
