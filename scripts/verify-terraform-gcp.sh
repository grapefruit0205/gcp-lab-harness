#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$repo_root/scripts/preflight-gcp.sh"
export HARNESS_REPO_ROOT="$repo_root"
source "$repo_root/lib/harness/config.sh"
harness_load_config "$repo_root/config/harness.env"

module_dir="$repo_root/foundation/terraform/account-check"
terraform -chdir="$module_dir" init -backend=false -input=false
terraform -chdir="$module_dir" validate
terraform -chdir="$module_dir" plan \
  -input=false \
  -lock=false \
  -refresh-only \
  -var="project_id=$GCP_PROJECT_ID" \
  -out="$repo_root/artifacts/foundation-account-check.tfplan"

printf 'PASS: Terraform google provider가 ADC로 허용 프로젝트를 조회했습니다.\n'
printf 'Cloud resource apply는 수행하지 않았습니다.\n'
