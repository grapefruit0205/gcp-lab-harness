mock_provider "google" {}

variables {
  project_id       = "example-lab"
  run_id           = "p12-test-001"
  region           = "us-central1"
  zone             = "us-central1-a"
  secondary_region = "europe-west1"
  secondary_zone   = "europe-west1-b"
  vpn_psk          = "mock-only-not-a-real-secret-01234567890123456789"
}

run "original_contract" {
  command = plan
  assert {
    condition     = length(google_compute_vpn_tunnel.vpc) == 2 && length(google_compute_vpn_tunnel.onprem) == 2 && google_compute_network.vpc.routing_mode == "GLOBAL"
    error_message = "양쪽 interface0/1·GLOBAL 계약"
  }
}
