mock_provider "google" {}

variables {
  project_id = "example-lab"
  run_id     = "p14-test-001"
  region     = "us-central1"
  zone_one   = "us-central1-a"
  zone_two   = "us-central1-b"
}

run "original_contract" {
  command = plan
  assert {
    condition     = google_compute_forwarding_rule.ilb.load_balancing_scheme == "INTERNAL" && google_compute_address.ilb.address == "10.10.30.5" && google_compute_instance_group_manager.a.zone != google_compute_instance_group_manager.b.zone
    error_message = "내부 VIP·다른 zone 계약"
  }
}

run "connection_backend_contract" {
  command = apply
  assert {
    condition     = length(google_compute_region_backend_service.ilb.backend) == 2 && alltrue([for backend in google_compute_region_backend_service.ilb.backend : backend.balancing_mode == "CONNECTION"])
    error_message = "INTERNAL passthrough backend는 CONNECTION 모드여야 함"
  }
}
