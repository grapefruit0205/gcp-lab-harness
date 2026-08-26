#!/usr/bin/env bash
set +x
set -Eeuo pipefail
umask 077
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
phase_dir="$repo_root/phases/08"
export HARNESS_REPO_ROOT="$repo_root"
source "$repo_root/lib/harness/phase-adapter.sh"
source "$phase_dir/support.sh"
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
  for script in "$phase_dir"/{execute,verify,support}.sh; do bash -n "$script"; done
  terraform -chdir="$phase_dir/terraform" fmt -check >/dev/null
  "$repo_root/scripts/phase-contract.py" --check "$repo_root/docs/phases/phase-08-cloud-storage.md" >/dev/null
  python3 "$repo_root/tests/test-phase-08.py"
  printf 'PASS: Phase 08 offline 계약·회귀 검증 완료\n'
  exit 0
fi
harness_load_config "$repo_root/config/harness.env"
p08_context "$selected_run"
p08_approved_context || { harness_die "Phase 08 실행 코드/입력의 승인 hash 불일치"; exit 1; }
p08_identity
"$repo_root/scripts/preflight-gcp.sh" >/dev/null
p08_lock
trap p08_unlock EXIT
if [[ "$mode" == destroyed ]]; then
  p08_lab destroyed
  printf 'PASS: Phase 08 활성·soft-deleted bucket 잔여 0\n'
  exit 0
fi
harness_manifest_require_status "$manifest" applied
export TF_DATA_DIR="$run_dir/.terraform"
success=false
phase_before_destroy() { p08_approved_context && p08_state_guard && p08_lab owned; }
finish() {
  local original="$?"
  trap - EXIT
  if [[ "$success" != true || "$original" != 0 ]]; then
    harness_manifest_set_status "$manifest" cleanup_required || true
    printf 'FAIL: Phase 08 검증 중단; run 소유 리소스 cleanup을 수행합니다.\n' >&2
    if [[ "${GCP_CLEANUP_ON_FAILURE:-}" == true ]] &&
       harness_phase_adapter_destroy_owned "$run_id" "$run_dir/work" "$phase_dir" >"$run_dir/verification-cleanup.log" 2>&1; then
      harness_phase_adapter_mark_destroyed "$manifest" "$run_dir"
      printf 'Phase 08 실패 cleanup 및 활성/soft-deleted 잔여 0 확인 완료\n' >&2
    else
      printf 'FAIL: cleanup 미완료. manifest=cleanup_required; 같은 run destroy로 재시도하세요.\n' >&2
    fi
    [[ "$original" != 0 ]] || original=1
  fi
  p08_unlock
  exit "$original"
}
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
# cleanup을 요청할 수 있도록 verifier 전체 시간에도 상한을 둔다.
timeout --foreground --signal=TERM --kill-after=90s 1500s python3 "$phase_dir/storage_lab.py" verify --run-dir "$run_dir"
success=true
printf 'PASS: Phase 08 ACL·CSEK·lifecycle·3세대 복구·recursive sync 검증 완료\n'
