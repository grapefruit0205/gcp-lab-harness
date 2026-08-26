mock_provider "google" {}

variables {
  project_id       = "example-lab"
  run_id           = "p13-test-001"
  region           = "us-central1"
  zone             = "us-central1-a"
  secondary_region = "europe-west1"
  load_region      = "us-west1"
  load_zone        = "us-west1-a"
}

run "original_contract" {
  command = plan
  assert {
    condition     = length(google_compute_region_instance_group_manager.backend) == 2 && google_compute_global_address.ipv4.ip_version == "IPV4" && google_compute_global_address.ipv6.ip_version == "IPV6"
    error_message = "두 region·dualstack 계약"
  }
  assert {
    condition     = google_compute_instance.loadgen.zone == var.load_zone && google_compute_router_nat.load.region == var.load_region && google_compute_router_nat.load.min_ports_per_vm == 8192
    error_message = "부하 발생기는 별도 세 번째 region/NAT를 사용해야 함"
  }
  assert {
    condition = (
      length([for backend in google_compute_backend_service.http.backend : backend if backend.balancing_mode == "RATE" && backend.max_rate_per_instance == 50]) == 1 &&
      length([for backend in google_compute_backend_service.http.backend : backend if backend.balancing_mode == "UTILIZATION" && backend.max_utilization == 0.8]) == 1
    )
    error_message = "원문 primary RATE50와 secondary UTILIZATION80 계약"
  }
}

run "reject_backend_region_for_load" {
  command = plan
  variables {
    load_region = "us-central1"
    load_zone   = "us-central1-b"
  }
  expect_failures = [var.load_region]
}
