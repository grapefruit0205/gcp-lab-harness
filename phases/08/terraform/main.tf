terraform {
  required_version = "~> 1.15.0"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 7.45.0" }
  }
}
variable "project_id" { type = string }
variable "region" { type = string }
# 로컬 saved inputs에만 기록하며 로그인 자체를 만들거나 바꾸지 않는다.
variable "runner" { type = string }
variable "run_id" {
  type = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{6,18}[a-z0-9]$", var.run_id))
    error_message = "run_id 형식이 올바르지 않습니다."
  }
}
provider "google" { project = var.project_id }
resource "google_storage_bucket" "lab" {
  project                     = var.project_id
  name                        = "gcp-lab-p08-${var.run_id}"
  location                    = upper(var.region)
  force_destroy               = true
  uniform_bucket_level_access = false
  public_access_prevention    = "inherited"
  # 일회성 CSEK fixture: 키 폐기 뒤 복호화 불가능한 soft-deleted 데이터가 남지 않게 한다.
  # 기존 버킷에는 적용하지 않으며, 새 bucket의 saved plan 승인 범위에 포함한다.
  soft_delete_policy { retention_duration_seconds = 0 }
  versioning { enabled = true }
  lifecycle_rule {
    condition { age = 31 }
    action { type = "Delete" }
  }
  labels = { harness = "gcp-lab-harness", phase = "08", run = var.run_id }
}
output "bucket_name" { value = google_storage_bucket.lab.name }
