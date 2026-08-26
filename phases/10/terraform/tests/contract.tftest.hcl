mock_provider "google" {}

variables {
  project_id = "example-lab"
  run_id     = "p10-test-001"

}

run "original_contract" {
  command = plan
  assert {
    condition     = google_bigquery_dataset.billing.location == "US" && google_bigquery_dataset.billing.default_table_expiration_ms == 86400000
    error_message = "US·1일 만료 계약"
  }
}
