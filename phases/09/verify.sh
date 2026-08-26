#!/usr/bin/env bash
set +x
set -Eeuo pipefail
umask 077
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
phase_dir="$repo_root/phases/09"
export HARNESS_REPO_ROOT="$repo_root"
source "$repo_root/lib/harness/phase-adapter.sh"
source "$phase_dir/support.sh"
source "$phase_dir/recovery.sh"
mode=offline; selected_run=""
usage() { printf '사용법: %s [--offline | --run <id> | --destroyed --run <id>]\n' "$0"; }
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --offline) mode=offline; shift ;;
    --destroyed) mode=destroyed; shift ;;
    --run) [[ "$mode" == destroyed ]] || mode=cloud; selected_run="${2:-}"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
if [[ "$mode" == offline ]]; then
  for script in "$phase_dir"/{execute,verify,support,recovery}.sh; do bash -n "$script"; done
  terraform -chdir="$phase_dir/terraform" fmt -check >/dev/null
  "$repo_root/scripts/phase-contract.py" --check "$repo_root/docs/phases/phase-09-cloud-sql.md" >/dev/null
  python3 "$repo_root/tests/test-phase-09.py"
  printf 'PASS: Phase09 offline 계약·회귀 검사\n'
  exit 0
fi
harness_load_config "$repo_root/config/harness.env"
p09_context "$selected_run"
p09_approved_context || { harness_die "Phase09 승인 코드/입력 불일치"; exit 1; }
p09_identity
"$repo_root/scripts/preflight-gcp.sh" >/dev/null
p09_lock
trap p09_unlock EXIT
if [[ "$mode" == destroyed ]]; then
  p09_lab destroyed
  printf 'PASS: Phase09 run 리소스 잔여0 (공통 API 유지)\n'
  exit 0
fi
harness_manifest_require_any_status "$manifest" applied verified failed
python3 "$phase_dir/recovery.py" require-apply --run-dir "$run_dir"
export TF_DATA_DIR="$run_dir/.terraform"
success=false
finish() {
  local original="$?"
  trap - EXIT
  if [[ "$success" != true || "$original" != 0 ]]; then
    p09_preserve_failure verify "$original"
    [[ "$original" != 0 ]] || original=1
  fi
  p09_unlock
  exit "$original"
}
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
timeout --foreground --signal=TERM --kill-after=90s 2100s python3 "$phase_dir/sql_lab.py" verify --run-dir "$run_dir" 2>&1 | tee -a "$run_dir/verification.log"
success=true
printf 'PASS: Phase09 실제 SQL·WordPress 두 경로 검증 완료\n'
