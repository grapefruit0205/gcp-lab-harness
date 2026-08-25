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
    "Task 1. 유틸리티 가상 머신 생성하기" \
    "Task 2. Windows 가상 머신 생성하기" \
    "Task 3. 커스텀 가상 머신 생성하기" \
    "Task 4. Review"; do
    grep -Fq "$token" "$repo_root/docs/phases/phase-05-creating-vms.md" || harness_die "Phase 05 문서 필수 항목 누락: $token"
  done
  ! grep -Fq '0.0.0.0/0' "$phase_dir/terraform/main.tf" || harness_die "Phase 05에 public ingress가 있습니다."
  grep -Fq 'enable-guest-attributes' "$phase_dir/terraform/main.tf" || harness_die "guest readiness evidence 채널이 없습니다."
  printf 'PASS: Phase 05 offline 계약 검증 완료\n'
}

verify_cloud() {
  harness_validate_run_id "$run_id"
  "$repo_root/scripts/preflight-gcp.sh" >/dev/null
  harness_load_config "$repo_root/config/harness.env"

  local run_dir="$repo_root/artifacts/runs/$run_id/phase-05"
  local manifest_file="$run_dir/manifest.json"
  local evidence_dir="$run_dir/evidence"
  local evidence_file="$evidence_dir/phase-05-machine.json"
  local utility_vm="utility-vm-$run_id"
  local windows_vm="windows-vm-$run_id"
  local custom_vm="custom-vm-$run_id"

  harness_manifest_require_status "$manifest_file" "applied"
  mkdir -p "$evidence_dir"
  chmod 700 "$evidence_dir"

  local utility_json windows_json custom_json
  utility_json="$(gcloud compute instances describe "$utility_vm" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" --format=json)"
  windows_json="$(gcloud compute instances describe "$windows_vm" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" --format=json)"
  custom_json="$(gcloud compute instances describe "$custom_vm" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" --format=json)"

  for vm_json in "$utility_json" "$windows_json" "$custom_json"; do
    jq -e '.status == "RUNNING" and ((.networkInterfaces[0].accessConfigs // []) | length == 0)' <<<"$vm_json" >/dev/null || harness_die "VM이 RUNNING/외부 IP 없음 계약을 만족하지 않습니다."
  done
  [[ "$(jq -r '.machineType | split("/") | last' <<<"$utility_json")" == "e2-medium" ]] || harness_die "utility VM machine type 불일치"
  [[ "$(jq -r '.machineType | split("/") | last' <<<"$windows_json")" == "e2-standard-2" ]] || harness_die "Windows VM machine type 불일치"
  [[ "$(jq -r '.machineType | split("/") | last' <<<"$custom_json")" == "e2-custom-2-4096" ]] || harness_die "custom VM machine type 불일치"
  [[ "$(jq -r '.disks[0].diskSizeGb' <<<"$windows_json")" -eq 64 ]] || harness_die "Windows boot disk가 64GB가 아닙니다."

  local utility_guest custom_guest
  utility_guest="$(timeout 60 gcloud compute ssh "$utility_vm" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" --tunnel-through-iap --quiet --command='set -eu; test -f /var/lib/gcp-lab-harness/ready; . /etc/os-release; printf "%s|%s|%s" "$ID" "$(nproc)" "$(awk "/MemTotal/{print int(\$2/1024)}" /proc/meminfo)"')"
  custom_guest="$(timeout 60 gcloud compute ssh "$custom_vm" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" --tunnel-through-iap --quiet --command='set -eu; test -f /var/lib/gcp-lab-harness/ready; . /etc/os-release; printf "%s|%s|%s" "$ID" "$(nproc)" "$(awk "/MemTotal/{print int(\$2/1024)}" /proc/meminfo)"')"
  [[ "$utility_guest" == debian\|* ]] || harness_die "utility VM guest OS/SSH 검사 실패"
  [[ "$custom_guest" == debian\|2\|* ]] || harness_die "custom VM guest vCPU/SSH 검사 실패"
  custom_memory_mb="${custom_guest##*|}"
  [[ "$custom_memory_mb" =~ ^[0-9]+$ && "$custom_memory_mb" -ge 3500 && "$custom_memory_mb" -le 4300 ]] || harness_die "custom VM guest memory가 4096MB 사양 범위를 벗어났습니다."

  guest_attribute_value() {
    local vm="$1"
    gcloud compute instances get-guest-attributes "$vm" \
      --zone="$GCP_ZONE" \
      --project="$GCP_PROJECT_ID" \
      --query-path='gcp-lab-harness/readiness' \
      --format='value(queryValue.items[0].value)' 2>/dev/null
  }
  windows_ready() { [[ "$(guest_attribute_value "$windows_vm")" == "rdp-ready" ]]; }
  if ! harness_wait_until 600 15 windows_ready; then
    harness_die "Windows guest agent가 RDP service/port readiness를 보고하지 않았습니다."
  fi

  local ssh_fw rdp_fw
  ssh_fw="$(gcloud compute firewall-rules describe "gcp-lab-p05-fw-ssh-$run_id" --project="$GCP_PROJECT_ID" --format=json)"
  rdp_fw="$(gcloud compute firewall-rules describe "gcp-lab-p05-fw-rdp-$run_id" --project="$GCP_PROJECT_ID" --format=json)"
  jq -e '.sourceRanges == ["35.235.240.0/20"]' <<<"$ssh_fw" >/dev/null || harness_die "SSH firewall가 IAP-only가 아닙니다."
  jq -e '.sourceRanges == ["35.235.240.0/20"]' <<<"$rdp_fw" >/dev/null || harness_die "RDP firewall가 IAP-only가 아닙니다."

  jq -n \
    --arg phase "05" \
    --arg run_id "$run_id" \
    --arg utility_guest "$utility_guest" \
    --arg custom_guest "$custom_guest" '
    {
      phase: $phase,
      run_id: $run_id,
      checks: {
        all_vms_running_without_external_ip: "passed",
        utility_ssh_guest: "passed",
        windows_guest_agent_rdp_ready: "passed",
        custom_ssh_cpu_memory: "passed",
        ingress_iap_only: "passed",
        windows_password_and_gui: "manual-boundary"
      },
      utility_guest_summary: $utility_guest,
      custom_guest_summary: $custom_guest
    }' >"$evidence_file"
  chmod 600 "$evidence_file"
  printf 'PASS: Phase 05 세 VM의 실제 guest readiness 검증 완료\n'
}

if [[ "$mode" == "offline" ]]; then
  verify_offline
else
  verify_cloud
fi
