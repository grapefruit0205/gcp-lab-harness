#!/usr/bin/env bash
set -Eeuo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.."&&pwd)";phase_dir="$repo_root/phases/11";export HARNESS_REPO_ROOT="$repo_root";source "$repo_root/lib/harness/config.sh";source "$repo_root/lib/harness/terraform.sh"
mode=offline;run_id="";while [[ "$#" -gt 0 ]];do case "$1" in --offline)mode=offline;shift;;--run)[[ "$mode" == destroyed ]]||mode=cloud;run_id="${2:-}";shift 2;;--destroyed)mode=destroyed;shift;;*)exit 2;;esac;done
if [[ "$mode" == offline ]];then
  bash -n "$phase_dir/execute.sh" "$phase_dir/verify.sh" "$repo_root/scripts/setup-gcp-mcp.sh";terraform -chdir="$phase_dir/terraform" fmt -check>/dev/null
  [[ "$(grep -Ec '^[[:space:]]*conditions \{' "$phase_dir/terraform/main.tf")" -eq 2 ]]||harness_die "alert 조건 2개 필요"
  grep -Eq 'combiner[[:space:]]*=[[:space:]]*"AND"' "$phase_dir/terraform/main.tf"||harness_die "AND combiner 누락"
  "$repo_root/scripts/phase-contract.py" --check "$repo_root/docs/phases/phase-11-monitoring.md">/dev/null
  printf 'PASS: Phase 11 offline 계약 검증 완료\n';exit 0
fi
harness_validate_run_id "$run_id";harness_load_config "$repo_root/config/harness.env"
if [[ "$mode" == destroyed ]]; then
  export GCP_PROJECT_ID
  python3 "$repo_root/lib/harness/advanced.py" inventory --phase 11 --run-dir "$repo_root/artifacts/runs/$run_id/phase-11"
  exit 0
fi
[[ "${HARNESS_SAFE_VERIFY_RUN:-}" == "$run_id" ]] || harness_die "승인 source/account 검사를 위해 phases/11/execute.sh verify --run $run_id 로 실행하세요."
run_dir="$repo_root/artifacts/runs/$run_id/phase-11";manifest="$run_dir/manifest.json";evidence_dir="$run_dir/evidence";evidence="$evidence_dir/phase-11-machine.json";harness_manifest_require_status "$manifest" applied;mkdir -p "$evidence_dir";chmod 700 "$evidence_dir"
guest(){ timeout 180 gcloud compute ssh "$1" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" --tunnel-through-iap --quiet --command="$2"; }
for n in 1 2 3;do vm="nginxstack-$n-$run_id";harness_wait_until 300 10 guest "$vm" 'systemctl is-active nginx >/dev/null'||harness_die "$vm nginx readiness 실패";guest "$vm" 'timeout 90 stress-ng --cpu 1 --timeout 60s >/dev/null 2>&1 & for i in $(seq 1 30); do curl -fsS http://127.0.0.1/ >/dev/null; done';done
export GCP_PROJECT_ID
python3 "$phase_dir/monitoring.py" "$run_dir"
printf 'PASS: Phase 11 구성·VM3개 실제 uptime·alert 전이 검증 완료\n'
