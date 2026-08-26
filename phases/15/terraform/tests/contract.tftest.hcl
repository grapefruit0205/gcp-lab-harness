mock_provider "google" {}

variables {
  project_id = "example-lab"
  run_id     = "p15-test-001"
  zone_one   = "us-central1-a"
  zone_two   = "europe-west1-b"
}

run "original_contract" {
  command = plan
  assert {
    condition     = google_compute_network.mynetwork.auto_create_subnetworks == true && module.mynet_vm_1.name == "mynet-vm-1-p15-test-001" && module.mynet_vm_2.name == "mynet-vm-2-p15-test-001"
    error_message = "auto VPC·local module 이름 계약"
  }
}
