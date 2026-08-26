#!/usr/bin/env bash
# Phase09는 shared adapter의 실패 자동 destroy 경로를 호출하지 않는다.
p09_recovery() { python3 "$repo_root/phases/09/recovery.py" "$1" --run-dir "$run_dir"; }
p09_preserve_failure() {
  harness_manifest_set_status "$manifest" failed || true
  python3 "$repo_root/phases/09/recovery.py" failure --run-dir "$run_dir" --stage "$1" --code "$2" || true
  printf 'FAIL: Phase09 리소스/state/로그 보존. diagnose → 수정 → replan → 새 SHA 승인 → apply/verify. 과금은 계속될 수 있습니다.\n' >&2
}
p09_recovery_main() {
  local action="$1" confirmed_sha=""
  p09_stage="$1"; p09_success=false
  shift
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --run) shift 2 ;;
      --confirm-plan-sha) confirmed_sha="${2:-}"; shift 2 ;;
      *) return 2 ;;
    esac
  done
  export TF_DATA_DIR="$run_dir/.terraform"
  "$repo_root/scripts/preflight-gcp.sh" >/dev/null
  # 진단은 읽기 전용이다. 수정/생성 경로는 아래 apply 한 곳뿐이다.
  if [[ "$action" == diagnose ]]; then p09_state_guard; p09_recovery diagnose; return; fi
  if [[ "$action" == destroy ]]; then
    # 명시적으로 요청한 run 종료에만 사용. 실패 trap에서는 이 함수를 호출하지 않는다.
    harness_manifest_require_any_status "$manifest" applied verified failed cleanup_required
    if harness_phase_adapter_destroy_owned "$run_id" "$run_dir/work" "$repo_root/phases/09"; then
      harness_phase_adapter_mark_destroyed "$manifest" "$run_dir"
    else
      harness_manifest_set_status "$manifest" cleanup_required
      harness_die "명시적 destroy 미완료; state/로그 보존. 자동 재시도 없음"; return 1
    fi
    return
  fi
  if [[ "$action" == replan ]]; then
    p09_state_guard
    p09_lab owned
    p09_recovery archive
    harness_manifest_set_status "$manifest" failed
    cp "$repo_root/phases/09/terraform/main.tf" "$run_dir/work/main.tf"
    cp "$repo_root/phases/09/terraform/.terraform.lock.hcl" "$run_dir/work/.terraform.lock.hcl"
    terraform -chdir="$run_dir/work" init -backend=false -input=false >/dev/null
    harness_tf_timeout terraform -chdir="$run_dir/work" plan -input=false -lock-timeout=60s -out="$run_dir/phase-09.tfplan" 2>&1 | tee "$run_dir/replan.log"
    terraform -chdir="$run_dir/work" show -json "$run_dir/phase-09.tfplan" |
      jq -f "$repo_root/scripts/sanitize-terraform-plan.jq" >"$run_dir/phase-09-plan.json"
    phase_plan_guard "$run_dir/phase-09-plan.json"
    phase_write_action_plan "$run_dir/action-plan.json" "$run_id"
    p09_recovery bundle
    "$repo_root/scripts/validate-json.py" "$repo_root/schemas/action-plan.schema.json" "$run_dir/action-plan.json"
    "$repo_root/scripts/validate-json.py" "$repo_root/schemas/phase-manifest.schema.json" "$manifest"
    printf 'PASS: Phase09 동일 state 복구 계획 준비 (apply 미실행)\nrun_id=%s\nplan_sha256=%s\n' "$run_id" "$(harness_sha256_file "$run_dir/plan-bundle.json")"
    return
  fi
  if [[ "$action" == apply ]]; then
    harness_manifest_require_status "$manifest" planned
    harness_validate_hash "승인 plan bundle hash" "$confirmed_sha"
    [[ "$(harness_sha256_file "$run_dir/plan-bundle.json")" == "$confirmed_sha" ]] || {
      harness_die "승인 SHA 불일치"; return 1;
    }
    p09_recovery before-apply
  else
    p09_recovery require-apply
  fi
  # ERR/timeout/INT/TERM 모두 보존만 한다. plan/state/evidence를 제거하지 않는다.
  p09_finish() {
    local original="$?"
    trap - EXIT
    if [[ "${p09_success:-false}" != true || "$original" != 0 ]]; then
      [[ "$original" != 0 ]] || original=1
      p09_preserve_failure "$p09_stage" "$original"
    fi
    p09_unlock
    exit "$original"
  }
  trap p09_finish EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  if [[ "$action" == apply ]]; then
    p09_recovery start-apply
    harness_tf_timeout terraform -chdir="$run_dir/work" apply -input=false -lock-timeout=60s "$run_dir/phase-09.tfplan" 2>&1 | tee -a "$run_dir/apply.log"
    p09_stage=initialization
    p09_lab record
    p09_recovery applied
    harness_manifest_set_status "$manifest" applied
    printf 'PASS: Phase09 승인 계획 apply·root 초기화 완료\n'
  else
    "$repo_root/phases/09/verify.sh" --run "$run_id"
    p09_recovery verified
    "$repo_root/scripts/validate-json.py" "$repo_root/schemas/phase-manifest.schema.json" "$manifest"
    "$repo_root/scripts/validate-json.py" "$repo_root/schemas/command-code-phase-result.schema.json" "$run_dir/command-code-result.json"
    printf 'PASS: Phase09 Task1–6 검증 완료 (리소스 유지)\n'
  fi
  p09_success=true
  p09_unlock
  trap - EXIT INT TERM
}
