mock_provider "google" {
  mock_data "google_monitoring_uptime_check_ips" {
    defaults = { uptime_check_ips = [{ ip_address = "35.1.2.3", location = "mock", region = "USA" }] }
  }
}

variables {
  project_id = "example-lab"
  run_id     = "p11-test-001"
  region     = "us-central1"
  zone       = "us-central1-a"
}

run "original_contract" {
  command = plan
  assert {
    condition     = google_monitoring_uptime_check_config.nginx.resource_group[0].resource_type == "INSTANCE" && length(google_compute_instance.nginx) == 3 && google_compute_firewall.uptime_http.source_ranges == toset(["35.1.2.3/32"])
    error_message = "VM3·INSTANCE enum·uptime IP /32 계약"
  }
  assert {
    condition     = google_monitoring_group.nginx.filter == "metadata.user_labels.run = \"${var.run_id}\""
    error_message = "그룹 필터는 resource.metadata가 아닌 metadata.user_labels를 사용해야 함"
  }
}
