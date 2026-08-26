#!/usr/bin/env bash
set -Eeuo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
phase_dir="$repo_root/phases/12"
export HARNESS_REPO_ROOT="$repo_root"
source "$repo_root/lib/harness/config.sh"
source "$repo_root/lib/harness/terraform.sh"

mode=offline
run_id=""
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --offline) mode=offline; shift ;;
    --destroyed) mode=destroyed; shift ;;
    --run) [[ "$mode" == destroyed ]] || mode=cloud; run_id="${2:-}"; shift 2 ;;
    *) exit 2 ;;
  esac
done

if [[ "$mode" == offline ]]; then
  bash -n "$phase_dir/execute.sh" "$phase_dir/verify.sh"
  terraform -chdir="$phase_dir/terraform" fmt -check >/dev/null
  [[ "$(grep -Ec '^resource "google_compute_vpn_tunnel"' "$phase_dir/terraform/main.tf")" -eq 2 ]] || harness_die "양쪽 tunnel resource block이 필요합니다."
  grep -Eq 'routing_mode *= *"GLOBAL"' "$phase_dir/terraform/main.tf" || harness_die "global routing 누락"
  ! grep -Eq 'shared_secret *= *"' "$phase_dir/terraform/main.tf" || harness_die "고정 PSK를 허용하지 않습니다."
  "$repo_root/scripts/phase-contract.py" --check "$repo_root/docs/phases/phase-12-ha-vpn.md" >/dev/null
  printf 'PASS: Phase 12 offline 계약 검증 완료\n'
  exit 0
fi

harness_validate_run_id "$run_id"
harness_load_config "$repo_root/config/harness.env"
prefix_vpc="vpc-demo-$run_id"
prefix_onprem="on-prem-$run_id"
if [[ "$mode" == destroyed ]]; then
  export GCP_PROJECT_ID
  python3 "$repo_root/lib/harness/advanced.py" inventory --phase 12 --run-dir "$repo_root/artifacts/runs/$run_id/phase-12"
  exit 0
fi
[[ "${HARNESS_SAFE_VERIFY_RUN:-}" == "$run_id" ]] || harness_die "승인 source/account 검사를 위해 phases/12/execute.sh verify --run $run_id 로 실행하세요."

run_dir="$repo_root/artifacts/runs/$run_id/phase-12"
manifest="$run_dir/manifest.json"
evidence_dir="$run_dir/evidence"
evidence="$evidence_dir/phase-12-machine.json"
harness_manifest_require_status "$manifest" applied
mkdir -p "$evidence_dir"
chmod 700 "$evidence_dir"

export GCP_PROJECT_ID
python3 "$phase_dir/vpn.py" "$run_dir"
printf 'PASS: Phase 12 routing·failover 검증 (Task8 destroy 대기)\n'
