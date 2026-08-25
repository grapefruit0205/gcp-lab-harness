#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
phase_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$repo_root/lib/harness/config.sh"
source "$repo_root/lib/harness/common.sh"
source "$repo_root/lib/harness/terraform.sh"

mode="offline"
run_id=""

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --offline)
      mode="offline"
      shift
      ;;
    --run)
      mode="cloud"
      run_id="${2:-}"
      shift 2
      ;;
    *)
      printf '사용법: %s [--offline | --run <run_id>]\n' "$0" >&2
      exit 2
      ;;
  esac
done

verify_offline() {
  printf 'INFO: Phase 02 offline 검증 시작\n'

  # 1. Bash 문법 검사
  bash -n "$phase_dir/execute.sh"
  bash -n "$phase_dir/verify.sh"

  # 2. Terraform 코드 포맷 및 유효성 검사
  terraform -chdir="$phase_dir/terraform" fmt -check >/dev/null
  terraform -chdir="$phase_dir/terraform" init -backend=false -input=false >/dev/null
  terraform -chdir="$phase_dir/terraform" validate >/dev/null

  # 3. Phase 02 설계 문서 요구사항 대조
  local doc_file="$repo_root/docs/phases/phase-02-infrastructure-preview.md"
  if [[ ! -f "$doc_file" ]]; then
    printf 'FAIL: Phase 02 설계 문서가 없습니다: %s\n' "$doc_file" >&2
    exit 1
  fi

  local required_tokens=(
    "Task 1. Marketplace를 사용하여 배포 구축하기"
    "Task 2. 배포 살펴보기"
    "Task 3. 서비스 관리하기"
    "Task 4. Review"
    "Marketplace"
    "Jenkins"
  )
  for token in "${required_tokens[@]}"; do
    if ! grep -Fq "$token" "$doc_file"; then
      printf 'FAIL: Phase 02 문서에 필수 항목이 없습니다: %s\n' "$token" >&2
      exit 1
    fi
  done

  printf 'PASS: Phase 02 offline 검증 완료 (Bash, Terraform validate, 설계 문서 매핑)\n'
}

verify_cloud() {
  [[ -n "$run_id" ]] || {
    printf 'FAIL: cloud 검증에는 --run <run_id>가 필요합니다.\n' >&2
    exit 2
  }
  harness_validate_run_id "$run_id"

  "$repo_root/scripts/preflight-gcp.sh" >/dev/null
  harness_load_config "$repo_root/config/harness.env"

  local run_dir="$repo_root/artifacts/runs/$run_id/phase-02"
  local manifest_file="$run_dir/manifest.json"
  local evidence_dir="$run_dir/evidence"
  local evidence_file="$evidence_dir/phase-02-machine.json"

  if [[ ! -f "$manifest_file" ]]; then
    printf 'FAIL: Phase 02 manifest 파일이 없습니다: %s\n' "$manifest_file" >&2
    exit 1
  fi

  jq empty "$manifest_file" || {
    printf 'FAIL: Phase 02 manifest JSON이 손상되었습니다.\n' >&2
    exit 1
  }

  local vm_name="jenkins-1-vm-$run_id"
  local zone="$GCP_ZONE"
  mkdir -p "$evidence_dir"
  chmod 700 "$evidence_dir"

  printf 'INFO: Phase 02 Cloud 상태 검증 시작 (project: %s, run: %s)\n' "$GCP_PROJECT_ID" "$run_id"

  # Task 1 & 2 검증: VM 존재 및 Marketplace provenance 확인
  local vm_json
  vm_json="$(gcloud compute instances describe "$vm_name" --zone="$zone" --project="$GCP_PROJECT_ID" --format=json)"
  local vm_status
  vm_status="$(jq -r '.status' <<<"$vm_json")"
  if [[ "$vm_status" != "RUNNING" ]]; then
    printf 'FAIL: Jenkins VM이 RUNNING 상태가 아닙니다: %s\n' "$vm_status" >&2
    exit 1
  fi
  jq -e '((.networkInterfaces[0].accessConfigs // []) | length == 0)' <<<"$vm_json" >/dev/null || {
    printf 'FAIL: Jenkins VM에 외부 IP가 있습니다.\n' >&2
    exit 1
  }
  jq -e '([.serviceAccounts[0].scopes[]? | select(endswith("/cloud-platform"))] | length) == 0' <<<"$vm_json" >/dev/null || {
    printf 'FAIL: Jenkins VM에 cloud-platform scope가 있습니다.\n' >&2
    exit 1
  }

  local boot_disk_name
  local disk_json
  local source_image
  boot_disk_name="$(jq -r '.disks[0].source | split("/") | last' <<<"$vm_json")"
  disk_json="$(gcloud compute disks describe "$boot_disk_name" --zone="$zone" --project="$GCP_PROJECT_ID" --format=json)"
  source_image="$(jq -r '.sourceImage // empty' <<<"$disk_json")"
  [[ "$source_image" == *"/projects/click-to-deploy-images/global/images/jenkins-v20250921" ]] || {
    printf 'FAIL: boot disk의 Marketplace Jenkins provenance가 일치하지 않습니다.\n' >&2
    exit 1
  }
  printf 'PASS: Marketplace Click-to-Deploy 이미지 provenance 확인 완료\n'

  # Task 3 검증: 방화벽 규칙 확인
  local fw_json
  fw_json="$(gcloud compute firewall-rules describe "gcp-lab-p02-fw-$run_id" --project="$GCP_PROJECT_ID" --format=json)"
  if [[ -z "$fw_json" ]]; then
    printf 'FAIL: Jenkins 방화벽 규칙을 찾을 수 없습니다.\n' >&2
    exit 1
  fi
  jq -e '
    .sourceRanges == ["35.235.240.0/20"] and
    ([.allowed[] | select(.IPProtocol == "tcp") | .ports[]] | sort) == (["22", "80", "8080"] | sort)
  ' <<<"$fw_json" >/dev/null || {
    printf 'FAIL: Jenkins 방화벽이 IAP 범위와 허용 포트 계약에 맞지 않습니다.\n' >&2
    exit 1
  }

  ssh_guest() {
    timeout 60 gcloud compute ssh "$vm_name" \
      --zone="$zone" \
      --project="$GCP_PROJECT_ID" \
      --tunnel-through-iap \
      --quiet \
      --command="$1" >/dev/null
  }
  jenkins_ready() {
    ssh_guest 'sudo systemctl is-active --quiet jenkins && curl --fail --silent --show-error --max-time 5 http://127.0.0.1:8080/login >/dev/null'
  }

  if ! harness_wait_until 600 15 jenkins_ready; then
    printf 'FAIL: 제한 시간 안에 Jenkins service와 HTTP endpoint가 ready가 되지 않았습니다.\n' >&2
    exit 1
  fi
  ssh_guest 'set -u; sudo systemctl stop jenkins; stopped=0; if curl --fail --silent --max-time 5 http://127.0.0.1:8080/login >/dev/null 2>&1; then stopped=1; fi; sudo systemctl start jenkins; exit "$stopped"'
  if ! harness_wait_until 300 10 jenkins_ready; then
    printf 'FAIL: Jenkins restart 뒤 endpoint가 복구되지 않았습니다.\n' >&2
    exit 1
  fi
  printf 'PASS: Task 3 service active/stop/start와 HTTP 상태 전이 검증 완료\n'

  jq -n \
    --arg phase "02" \
    --arg run_id "$run_id" \
    --arg image_hash "$(printf '%s' "$source_image" | sha256sum | awk '{print $1}')" \
    '{
      phase: $phase,
      run_id: $run_id,
      checks: {
        marketplace_provenance: "passed",
        vm_running: "passed",
        ingress_iap_only: "passed",
        jenkins_http_ready: "passed",
        jenkins_stop_start_transition: "passed"
      },
      source_image_sha256: $image_hash
    }' >"$evidence_file"
  chmod 600 "$evidence_file"

  printf 'PASS: Phase 02 모든 Cloud 검증 게이트를 통과했습니다.\n'
}

if [[ "$mode" == "offline" ]]; then
  verify_offline
else
  verify_cloud
fi
