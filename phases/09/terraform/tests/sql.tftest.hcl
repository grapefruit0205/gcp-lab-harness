mock_provider "google" {}

variables {
  project_id         = "example-lab"
  run_id             = "p09-test-001"
  region             = "us-central1"
  zone               = "us-central1-a"
  runner             = "learner@example.com"
  client_source_cidr = "8.8.8.8/32"
  wordpress_url      = "https://wordpress.org/wordpress-7.1.tar.gz"
  wordpress_sha256   = "05a5f89138f632b7329f1202f2a0553c5f7fe4daf8e4b9ca7ebae9b9466b9e86"
  proxy_url          = "https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.25.2/cloud-sql-proxy.linux.amd64"
  proxy_sha256       = "43950f9500d2a34cd3b7e0ed89508f66b8eac4a5f9303c7bd2c18fb4bff32e10"
  wp_cli_url         = "https://github.com/wp-cli/wp-cli/releases/download/v2.12.0/wp-cli-2.12.0.phar"
  wp_cli_sha256      = "ce34ddd838f7351d6759068d09793f26755463b4a4610a5a5c0a97b68220d85c"
}
run "sql_original_shape" {
  command = plan
  assert {
    condition     = google_sql_database_instance.wordpress.settings[0].tier == "db-custom-1-3840" && google_sql_database_instance.wordpress.settings[0].edition == "ENTERPRISE"
    error_message = "원문 1vCPU/3.75GB Enterprise 구성 필요"
  }
  assert {
    condition     = alltrue([for service in google_project_service.required : service.disable_on_destroy == false])
    error_message = "공통 API는 destroy 이후 유지"
  }
}
run "different_clone" {
  command = plan
  variables {
    run_id = "p09-other-002"
    region = "asia-northeast3"
    zone   = "asia-northeast3-a"
    runner = "another@example.com"
  }
  assert {
    condition     = google_service_account.private.account_id == "p09-d-p09-other-002" && google_compute_instance.private.zone == "asia-northeast3-a"
    error_message = "다른 clone 사용자 입력 반영"
  }
}
run "wide_ingress_rejected" {
  command = plan
  variables {
    client_source_cidr = "0.0.0.0/0"
  }
  expect_failures = [var.client_source_cidr]
}
