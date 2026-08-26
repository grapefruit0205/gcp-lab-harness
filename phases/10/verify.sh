#!/usr/bin/env bash
set -Eeuo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export HARNESS_REPO_ROOT="$repo_root"
source "$repo_root/lib/harness/config.sh"
source "$repo_root/lib/harness/terraform.sh"
mode=offline; run_id=''
while [[ $# -gt 0 ]]; do case "$1" in
  --offline) mode=offline; shift;;
  --destroyed) mode=destroyed; shift;;
  --run) [[ "$mode" == destroyed ]] || mode=cloud; run_id="${2:-}"; shift 2;;
  *) exit 2;;
esac; done
if [[ "$mode" == offline ]]; then
  bash -n "$repo_root/phases/10/execute.sh" "$repo_root/phases/10/verify.sh"
  terraform -chdir="$repo_root/phases/10/terraform" fmt -check >/dev/null
  "$repo_root/scripts/phase-contract.py" --check "$repo_root/docs/phases/phase-10-bigquery-billing.md" >/dev/null
  printf 'PASS: Phase 10 offline 계약 검증 완료\n'; exit 0
fi
harness_validate_run_id "$run_id"
harness_load_config "$repo_root/config/harness.env"
export GCP_PROJECT_ID
run_dir="$repo_root/artifacts/runs/$run_id/phase-10"
if [[ "$mode" == destroyed ]]; then
  python3 "$repo_root/lib/harness/advanced.py" inventory --phase 10 --run-dir "$run_dir"; exit
fi
[[ "${HARNESS_SAFE_VERIFY_RUN:-}" == "$run_id" ]] || harness_die "phases/10/execute.sh verify --run $run_id 로 실행하세요."
harness_manifest_require_status "$run_dir/manifest.json" applied
mkdir -p "$run_dir/evidence"; chmod 700 "$run_dir/evidence"
python3 "$repo_root/phases/10/billing.py" "$run_dir"
printf 'PASS: Phase 10 load·schema·SQL 8개 검증 완료\n'
