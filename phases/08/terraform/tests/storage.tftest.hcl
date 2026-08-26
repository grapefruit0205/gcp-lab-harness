mock_provider "google" {}

variables {
  project_id = "example-lab"
  run_id     = "p08-test-001"
  region     = "us-central1"
  runner     = "learner@example.com"
}

run "regional_fine_grained_bucket" {
  command = plan
  assert {
    condition     = google_storage_bucket.lab.location == "US-CENTRAL1" && google_storage_bucket.lab.uniform_bucket_level_access == false
    error_message = "원문 리전/fine-grained 설정을 유지해야 합니다."
  }
  assert {
    condition     = google_storage_bucket.lab.name == "gcp-lab-p08-p08-test-001" && google_storage_bucket.lab.public_access_prevention == "inherited"
    error_message = "run 전용 이름/PAP 상속이 필요합니다."
  }
}

run "ephemeral_versioned_objects" {
  command = plan
  assert {
    condition     = google_storage_bucket.lab.soft_delete_policy[0].retention_duration_seconds == 0 && google_storage_bucket.lab.force_destroy
    error_message = "임시 CSEK 전체 세대의 최종 정리 정책이 필요합니다."
  }
  assert {
    condition     = google_storage_bucket.lab.versioning[0].enabled && one(one(google_storage_bucket.lab.lifecycle_rule).condition).age == 31
    error_message = "versioning/31일 lifecycle이 필요합니다."
  }
}

run "different_clone_region" {
  command = plan
  variables {
    region = "asia-northeast3"
    run_id = "other-p08-run"
    runner = "other@example.com"
  }
  assert {
    condition     = google_storage_bucket.lab.location == "ASIA-NORTHEAST3" && google_storage_bucket.lab.labels.run == "other-p08-run"
    error_message = "원 사용자 설정에 고정되면 안 됩니다."
  }
}

run "invalid_run_rejected" {
  command = plan
  variables {
    run_id = "../unsafe"
  }
  expect_failures = [var.run_id]
}
