mock_provider "google" {}

variables {
  project_id       = "example-lab"
  run_id           = "p13-test-001"
  region           = "us-central1"
  zone             = "us-central1-a"
  secondary_region = "europe-west1"
}

run "original_contract" {
  command = plan
  assert {
    condition     = length(google_compute_region_instance_group_manager.backend) == 2 && google_compute_global_address.ipv4.ip_version == "IPV4" && google_compute_global_address.ipv6.ip_version == "IPV6"
    error_message = "두 region·dualstack 계약"
  }
}
