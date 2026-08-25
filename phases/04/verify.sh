#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
phase_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export HARNESS_REPO_ROOT="$repo_root"
source "$repo_root/lib/harness/config.sh"
source "$repo_root/lib/harness/terraform.sh"

mode="offline"
run_id=""
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --offline) mode="offline"; shift ;;
    --run) mode="cloud"; run_id="${2:-}"; shift 2 ;;
    *) printf '사용법: %s [--offline | --run <run_id>]\n' "$0" >&2; exit 2 ;;
  esac
done

verify_offline() {
  bash -n "$phase_dir/execute.sh" "$phase_dir/verify.sh"
  terraform -chdir="$phase_dir/terraform" fmt -check >/dev/null
  terraform -chdir="$phase_dir/terraform" init -backend=false -input=false >/dev/null
  terraform -chdir="$phase_dir/terraform" validate >/dev/null
  for token in \
    "Task 1. VM 인스턴스 생성하기" \
    "Task 2. Private Google Access 활성화하기" \
    "Task 3. Cloud NAT 게이트웨이 구성하기" \
    "Task 4. Cloud NAT Logging 구성 및 로그 확인하기" \
    "Task 5. Review"; do
    grep -Fq "$token" "$repo_root/docs/phases/phase-04-private-access-nat.md" || harness_die "Phase 04 문서 필수 항목 누락: $token"
  done
  grep -Fq 'private_ip_google_access = false' "$phase_dir/terraform/main.tf" || harness_die "PGA disabled control이 없습니다."
  grep -Fq 'private_ip_google_access = true' "$phase_dir/terraform/main.tf" || harness_die "PGA enabled 경로가 없습니다."
  grep -Fq 'source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"' "$phase_dir/terraform/main.tf" || harness_die "NAT가 enabled subnet으로 제한되지 않았습니다."
  printf 'PASS: Phase 04 offline 계약 검증 완료\n'
}

verify_cloud() {
  harness_validate_run_id "$run_id"
  "$repo_root/scripts/preflight-gcp.sh" >/dev/null
  harness_load_config "$repo_root/config/harness.env"

  local run_dir="$repo_root/artifacts/runs/$run_id/phase-04"
  local manifest_file="$run_dir/manifest.json"
  local evidence_dir="$run_dir/evidence"
  local evidence_file="$evidence_dir/phase-04-machine.json"
  local log_file="$evidence_dir/nat-log.raw.json"
  local control_vm="vm-control-$run_id"
  local enabled_vm="vm-enabled-$run_id"
  local bucket_name="gcp-lab-p04-$run_id"
  local router_name="nat-router-$run_id"
  local nat_name="nat-config-$run_id"

  harness_manifest_require_status "$manifest_file" "applied"
  mkdir -p "$evidence_dir"
  chmod 700 "$evidence_dir"

  guest() {
    local vm="$1"
    local command="$2"
    timeout 60 gcloud compute ssh "$vm" \
      --zone="$GCP_ZONE" \
      --project="$GCP_PROJECT_ID" \
      --tunnel-through-iap \
      --quiet \
      --command="$command" >/dev/null
  }

  local control_json enabled_json
  control_json="$(gcloud compute instances describe "$control_vm" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" --format=json)"
  enabled_json="$(gcloud compute instances describe "$enabled_vm" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" --format=json)"
  jq -e '.status == "RUNNING" and ((.networkInterfaces[0].accessConfigs // []) | length == 0)' <<<"$control_json" >/dev/null || harness_die "control VM이 RUNNING/외부 IP 없음 상태가 아닙니다."
  jq -e '.status == "RUNNING" and ((.networkInterfaces[0].accessConfigs // []) | length == 0)' <<<"$enabled_json" >/dev/null || harness_die "enabled VM이 RUNNING/외부 IP 없음 상태가 아닙니다."

  local control_subnet enabled_subnet
  control_subnet="$(gcloud compute networks subnets describe "privatenet-control-$run_id" --region="$GCP_REGION" --project="$GCP_PROJECT_ID" --format=json)"
  enabled_subnet="$(gcloud compute networks subnets describe "privatenet-enabled-$run_id" --region="$GCP_REGION" --project="$GCP_PROJECT_ID" --format=json)"
  jq -e '.privateIpGoogleAccess == false' <<<"$control_subnet" >/dev/null || harness_die "control subnet의 PGA가 disabled가 아닙니다."
  jq -e '.privateIpGoogleAccess == true' <<<"$enabled_subnet" >/dev/null || harness_die "enabled subnet의 PGA가 enabled가 아닙니다."

  local storage_probe
  storage_probe="token=\$(curl --fail --silent --show-error --max-time 5 -H 'Metadata-Flavor: Google' 'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token' | python3 -c 'import json,sys; print(json.load(sys.stdin)[\"access_token\"])'); curl --fail --silent --show-error --max-time 15 -H \"Authorization: Bearer \$token\" 'https://storage.googleapis.com/storage/v1/b/$bucket_name/o/access.svg?alt=media' >/dev/null"

  if guest "$control_vm" "$storage_probe"; then
    harness_die "PGA disabled control에서 Storage 접근이 성공했습니다."
  fi
  guest "$enabled_vm" "$storage_probe" || harness_die "PGA enabled VM에서 Storage 객체 접근이 실패했습니다."

  local internet_probe="curl --fail --silent --show-error --max-time 15 https://example.com/ >/dev/null"
  if guest "$control_vm" "$internet_probe"; then
    harness_die "NAT 제외 control VM에서 일반 인터넷 egress가 성공했습니다."
  fi
  guest "$enabled_vm" "$internet_probe" || harness_die "NAT enabled VM의 일반 인터넷 egress가 실패했습니다."

  local nat_json
  nat_json="$(gcloud compute routers nats describe "$nat_name" --router="$router_name" --region="$GCP_REGION" --project="$GCP_PROJECT_ID" --format=json)"
  jq -e '.sourceSubnetworkIpRangesToNat == "LIST_OF_SUBNETWORKS" and .logConfig.enable == true and .logConfig.filter == "ALL"' <<<"$nat_json" >/dev/null || harness_die "NAT subnet 범위 또는 logging 계약이 맞지 않습니다."

  nat_log_ready() {
    timeout 60 gcloud logging read \
      "resource.type=\"nat_gateway\" AND resource.labels.gateway_name=\"$nat_name\"" \
      --project="$GCP_PROJECT_ID" \
      --freshness=15m \
      --limit=5 \
      --format=json >"$log_file"
    jq -e 'length > 0' "$log_file" >/dev/null
  }
  if ! harness_wait_until 600 15 nat_log_ready; then
    rm -f "$log_file"
    harness_die "제한 시간 안에 실제 Cloud NAT log를 찾지 못했습니다."
  fi

  local control_ip_hash enabled_ip_hash log_hash
  control_ip_hash="$(jq -r '.networkInterfaces[0].networkIP' <<<"$control_json" | sha256sum | awk '{print $1}')"
  enabled_ip_hash="$(jq -r '.networkInterfaces[0].networkIP' <<<"$enabled_json" | sha256sum | awk '{print $1}')"
  log_hash="$(jq -c '[.[] | {insertId, timestamp, resource}]' "$log_file" | sha256sum | awk '{print $1}')"
  rm -f "$log_file"
  jq -n \
    --arg phase "04" \
    --arg run_id "$run_id" \
    --arg control_ip_hash "$control_ip_hash" \
    --arg enabled_ip_hash "$enabled_ip_hash" \
    --arg log_hash "$log_hash" '
    {
      phase: $phase,
      run_id: $run_id,
      checks: {
        no_external_ip: "passed",
        pga_disabled_storage_expected_failure: "passed",
        pga_enabled_storage_success: "passed",
        nat_excluded_egress_expected_failure: "passed",
        nat_enabled_egress_success: "passed",
        nat_log_correlated: "passed"
      },
      control_internal_ip_sha256: $control_ip_hash,
      enabled_internal_ip_sha256: $enabled_ip_hash,
      nat_log_record_sha256: $log_hash
    }' >"$evidence_file"
  chmod 600 "$evidence_file"
  printf 'PASS: Phase 04 PGA/NAT control·enabled packet path와 NAT log 검증 완료\n'
}

if [[ "$mode" == "offline" ]]; then
  verify_offline
else
  verify_cloud
fi
