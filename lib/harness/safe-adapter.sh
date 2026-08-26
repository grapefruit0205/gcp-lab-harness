#!/usr/bin/env bash
# Phase08/09 승인 소스를 바꾸지 않는 Phase10–15 전용 보존 어댑터.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/phase-adapter.sh"

advanced() { python3 "$HARNESS_REPO_ROOT/lib/harness/advanced.py" "$@"; }

safe_identity() {
  harness_load_config "$HARNESS_REPO_ROOT/config/harness.env"
  "$HARNESS_REPO_ROOT/scripts/preflight-gcp.sh" >/dev/null
  [[ -z "${GCP_IMPERSONATE_SERVICE_ACCOUNT:-}" && -z "${CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT:-}" ]] || harness_die "Phase10–15는 현재 사용자 인증 경로만 지원합니다. 가장 설정을 해제 후 새 plan을 만드세요."
  local impersonation
  impersonation="$(gcloud config get-value auth/impersonate_service_account 2>/dev/null)"
  [[ -z "$impersonation" || "$impersonation" == '(unset)' ]] || harness_die "gcloud config의 가장 설정은 아직 지원하지 않습니다."
  export CLOUDSDK_CORE_ACCOUNT
  CLOUDSDK_CORE_ACCOUNT="$(gcloud auth list --filter=status:ACTIVE --format='value(account)')"
  [[ -n "$CLOUDSDK_CORE_ACCOUNT" && "$CLOUDSDK_CORE_ACCOUNT" != *$'\n'* ]] || harness_die "현재 실행자 한 명을 선택하세요."
  export CLOUDSDK_CORE_PROJECT="$GCP_PROJECT_ID"
  export GOOGLE_OAUTH_ACCESS_TOKEN
  GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud auth print-access-token)"
  [[ -n "$GOOGLE_OAUTH_ACCESS_TOKEN" ]] || harness_die "현재 실행자 토큰 없음"
  export GCP_PROJECT_ID GCP_MAX_RESOURCES_PER_PHASE
}

safe_failure() {
  local rc="$1" stage="$2" run_dir="$3" log_path="${4:-}"
  [[ "$rc" -ne 0 ]] || return 0
  if [[ -f "$run_dir/manifest.json" ]]; then harness_manifest_set_status "$run_dir/manifest.json" failed || true; fi
  jq -n --arg stage "$stage" --argjson code "$rc" --arg log "$log_path" '{stage:$stage,exit_code:$code,private_log:$log,resources_preserved:true,state_preserved:true,next:"diagnose -> fix -> replan -> approve new SHA -> apply -> verify"}' >"$run_dir/diagnosis.json"
  chmod 600 "$run_dir/diagnosis.json"
  printf 'FAIL: %s (rc=%s). 리소스·state·로그 보존. 같은 run으로 diagnose/replan하세요.\n' "$stage" "$rc" >&2
  return "$rc"
}

safe_bundle() {
  local run_dir="$1" operation="$2" manifest="$1/manifest.json" bundle="$1/plan-bundle.json" temporary
  advanced bind --phase "$HARNESS_PHASE" --run-dir "$run_dir"
  jq -n --arg phase "$HARNESS_PHASE" --arg run_id "$(basename "$(dirname "$run_dir")")" --arg operation "$operation" \
    --arg tf "$(harness_sha256_file "$run_dir/phase-$HARNESS_PHASE.tfplan")" \
    --arg actions "$(harness_sha256_file "$run_dir/action-plan.json")" --arg binding "$(harness_sha256_file "$run_dir/binding.json")" \
    '{schema_version:2,phase:$phase,run_id:$run_id,operation:$operation,terraform:{sha256:$tf},action_plan:{sha256:$actions},binding_sha256:$binding}' >"$bundle"
  temporary="$(mktemp "$run_dir/manifest.tmp.XXXXXX")"
  jq --slurpfile b "$bundle" --arg sha "$(harness_sha256_file "$bundle")" \
    '.status="planned" | .plan={terraform_sha256:$b[0].terraform.sha256,action_plan_sha256:$b[0].action_plan.sha256,bundle_sha256:$sha}' "$manifest" >"$temporary"
  mv "$temporary" "$manifest"; chmod 600 "$manifest" "$bundle" "$run_dir/binding.json"
  printf 'PASS: Phase %s %s 저장 계획 (실행/과금 변경 없음)\nrun_id=%s\nplan_sha256=%s\n' "$HARNESS_PHASE" "$operation" "$(basename "$(dirname "$run_dir")")" "$(harness_sha256_file "$bundle")"
}

safe_check_bundle() {
  local run_dir="$1" confirmed="$2" operation="$3" bundle="$1/plan-bundle.json"
  harness_assert_saved_plan "$bundle" "$confirmed"
  [[ "$(jq -r .operation "$bundle")" == "$operation" ]] || harness_die "apply/destroy 계획 종류 불일치"
  [[ "$(jq -r .terraform.sha256 "$bundle")" == "$(harness_sha256_file "$run_dir/phase-$HARNESS_PHASE.tfplan")" ]] || harness_die "저장 plan 변경"
  [[ "$(jq -r .action_plan.sha256 "$bundle")" == "$(harness_sha256_file "$run_dir/action-plan.json")" ]] || harness_die "action plan 변경"
  [[ "$(jq -r .binding_sha256 "$bundle")" == "$(harness_sha256_file "$run_dir/binding.json")" ]] || harness_die "binding 변경"
  advanced check --phase "$HARNESS_PHASE" --run-dir "$run_dir" --recovery
}

safe_adapter_main() {
  harness_phase_adapter_require_contract
  local action="${1:-}" run_id='' confirmed='' run_dir work_dir manifest rc=0 attempt
  [[ "$action" =~ ^(plan|replan|apply|verify|diagnose|plan-destroy|destroy)$ ]] || { printf '사용법: execute.sh {plan|replan|apply|verify|diagnose|plan-destroy|destroy} --run ID [--confirm-plan-sha SHA]\n'; return 2; }
  shift
  while [[ $# -gt 0 ]]; do case "$1" in
    --run) run_id="${2:-}"; shift 2;;
    --confirm-plan-sha) confirmed="${2:-}"; shift 2;;
    *) return 2;;
  esac; done
  harness_validate_run_id "$run_id"
  [[ "$HARNESS_PHASE" =~ ^1[0-5]$ ]] || harness_die "safe adapter 대상은 Phase10–15입니다."
  umask 077
  run_dir="$HARNESS_REPO_ROOT/artifacts/runs/$run_id/phase-$HARNESS_PHASE"; work_dir="$run_dir/work"; manifest="$run_dir/manifest.json"
  mkdir -p "$HARNESS_REPO_ROOT/artifacts/locks"
  exec {safe_lock}>"$HARNESS_REPO_ROOT/artifacts/locks/$run_id-$HARNESS_PHASE.lock"
  flock -n "$safe_lock" || harness_die "같은 run에서 다른 작업 실행 중"
  safe_identity
  export TF_DATA_DIR="$run_dir/.terraform"
  if [[ "$action" == plan ]]; then
    if [[ -d "$run_dir" && ! -f "$run_dir/binding.json" && ! -f "$work_dir/terraform.tfstate" ]]; then
      if [[ -f "$manifest" ]]; then harness_manifest_require_any_status "$manifest" planned failed; fi
      local prior_plan
      prior_plan="$(mktemp -d "$HARNESS_REPO_ROOT/artifacts/runs/$run_id/phase-$HARNESS_PHASE-plan-history.XXXXXX")"
      mv "$run_dir" "$prior_plan/preserved-attempt"
    fi
    # 기존 plan-only 코드에는 Cloud mutation/자동 destroy가 없다.
    local plan_log
    plan_log="$(mktemp "$HARNESS_REPO_ROOT/artifacts/phase-$HARNESS_PHASE-plan.XXXXXX.log")"
    set +e
    (set -Eeuo pipefail; harness_phase_adapter_main plan --run "$run_id") >"$plan_log" 2>&1
    rc=$?; set -e
    if [[ "$rc" -ne 0 ]]; then
      mkdir -p "$run_dir"
      safe_failure "$rc" plan "$run_dir" "$plan_log" || return "$rc"
    fi
    advanced guard --phase "$HARNESS_PHASE" --run-dir "$run_dir" --file "$run_dir/phase-$HARNESS_PHASE-plan.json"
    safe_bundle "$run_dir" apply
    return
  fi
  harness_require_file "$manifest" "기존 run manifest"
  [[ "$(jq -r .phase "$manifest")" == "$HARNESS_PHASE" && "$(jq -r .run_id "$manifest")" == "$run_id" ]] || harness_die "manifest 소유권 불일치"
  [[ "$(jq -r .project_id_hash "$manifest")" == "$(printf %s "$GCP_PROJECT_ID" | sha256sum | awk '{print $1}')" ]] || harness_die "기존 run project 변경 금지"
  harness_require_file "$run_dir/binding.json" "새 보존 어댑터의 기존 binding (legacy run 자동 이관 금지)"
  [[ "$(jq -r .account "$run_dir/binding.json")" == "$(printf %s "$CLOUDSDK_CORE_ACCOUNT" | sha256sum | awk '{print $1}')" ]] || harness_die "기존 run 실행 계정 변경 금지; 원래 계정으로 선택하세요."
  [[ "$(jq -r .config "$run_dir/binding.json")" == "$(harness_sha256_file "$HARNESS_REPO_ROOT/config/harness.env")" ]] || harness_die "기존 run 설정이 변경됐습니다. 원래 harness.env를 복원하세요. 다른 프로젝트/region은 새 run으로 계획합니다."
  case "$action" in
    diagnose)
      terraform -chdir="$work_dir" state list >"$run_dir/state-addresses.txt"
      printf 'state 주소 목록: %s\n실패 요약: %s\n' "$run_dir/state-addresses.txt" "$run_dir/diagnosis.json"
      ;;
    replan|plan-destroy)
      harness_manifest_require_any_status "$manifest" planned applied verified failed cleanup_required
      attempt="$(mktemp -d "$run_dir/plan-history.XXXXXX")"
      for name in plan-bundle.json binding.json action-plan.json manifest.json "phase-$HARNESS_PHASE.tfplan" "phase-$HARNESS_PHASE-plan.json"; do
        [[ ! -f "$run_dir/$name" ]] || cp -p "$run_dir/$name" "$attempt/"
      done
      set +e
      (set -Eeuo pipefail
      # tfvars(state/PSK/zone 포함)는 보존하고 저장소 Terraform 코드만 갱신한다.
      if [[ "$action" == replan ]]; then
        # .terraform provider/cache와 state는 복사하지 않는다.
        while IFS= read -r -d '' source_file; do
          relative="${source_file#"$HARNESS_REPO_ROOT/phases/$HARNESS_PHASE/terraform/"}"
          mkdir -p "$(dirname "$work_dir/$relative")"
          cp -p "$source_file" "$work_dir/$relative"
        done < <(find "$HARNESS_REPO_ROOT/phases/$HARNESS_PHASE/terraform" -path '*/.terraform' -prune -o -path '*/tests' -prune -o -type f \( -name '*.tf' -o -name '*.sh' -o -name '.terraform.lock.hcl' \) -print0)
        if declare -F phase_preflight >/dev/null; then phase_preflight "$run_id"; fi
        phase_write_action_plan "$run_dir/action-plan.json" "$run_id"
      fi
      terraform -chdir="$work_dir" init -backend=false -input=false >/dev/null
      local flags=(); [[ "$action" != plan-destroy ]] || flags+=(-destroy)
      harness_tf_timeout terraform -chdir="$work_dir" plan -input=false -lock-timeout=30s "${flags[@]}" -out="$run_dir/phase-$HARNESS_PHASE.tfplan"
      terraform -chdir="$work_dir" show -json "$run_dir/phase-$HARNESS_PHASE.tfplan" | jq -f "$HARNESS_REPO_ROOT/scripts/sanitize-terraform-plan.jq" >"$run_dir/phase-$HARNESS_PHASE-plan.json"
      flags=(); [[ "$action" != plan-destroy ]] || flags+=(--destroy)
      advanced guard --phase "$HARNESS_PHASE" --run-dir "$run_dir" --file "$run_dir/phase-$HARNESS_PHASE-plan.json" --recovery "${flags[@]}"
      if [[ "$action" == replan ]] && declare -F phase_plan_guard >/dev/null; then phase_plan_guard "$run_dir/phase-$HARNESS_PHASE-plan.json"; fi
      safe_bundle "$run_dir" "$([[ "$action" == plan-destroy ]] && printf destroy || printf apply)"
      ) >"$attempt/command.log" 2>&1
      rc=$?; set -e
      safe_failure "$rc" "$action" "$run_dir" "$attempt/command.log" || return "$rc"
      printf 'PASS: Phase %s %s 저장 계획\nrun_id=%s\nplan_sha256=%s\n로그=%s\n' "$HARNESS_PHASE" "$action" "$run_id" "$(harness_sha256_file "$run_dir/plan-bundle.json")" "$attempt/command.log"
      ;;
    apply|destroy)
      harness_manifest_require_status "$manifest" planned
      safe_check_bundle "$run_dir" "$confirmed" "$action"
      attempt="$(mktemp -d "$run_dir/$action-attempt.XXXXXX")"
      set +e
      (set -Eeuo pipefail
        harness_tf_timeout terraform -chdir="$work_dir" apply -input=false "$run_dir/phase-$HARNESS_PHASE.tfplan"
        if [[ "$action" == apply ]]; then
          if declare -F phase_after_apply >/dev/null; then phase_after_apply "$run_id"; fi
          harness_manifest_set_status "$manifest" applied
          cp "$run_dir/binding.json" "$run_dir/applied-binding.json"
        else
          advanced inventory --phase "$HARNESS_PHASE" --run-dir "$run_dir"
          harness_phase_adapter_mark_destroyed "$manifest" "$run_dir"
          if declare -F phase_after_destroy >/dev/null; then phase_after_destroy "$run_id"; fi
        fi
      ) >"$attempt/command.log" 2>&1
      rc=$?; set -e
      safe_failure "$rc" "$action" "$run_dir" "$attempt/command.log" || return "$rc"
      printf 'PASS: Phase %s %s; 로그=%s\n' "$HARNESS_PHASE" "$action" "$attempt/command.log"
      ;;
    verify)
      harness_manifest_require_any_status "$manifest" applied verified failed
      harness_require_file "$run_dir/applied-binding.json" "apply receipt"
      cmp -s "$run_dir/applied-binding.json" "$run_dir/binding.json" || harness_die "replan 후 apply가 필요합니다."
      advanced check --phase "$HARNESS_PHASE" --run-dir "$run_dir"
      attempt="$(mktemp -d "$run_dir/verify-attempt.XXXXXX")"
      [[ ! -d "$run_dir/evidence" ]] || cp -R "$run_dir/evidence" "$attempt/previous-evidence"
      harness_manifest_set_status "$manifest" applied
      set +e
      (set -Eeuo pipefail
        export HARNESS_SAFE_VERIFY_RUN="$run_id"
        "$HARNESS_REPO_ROOT/phases/$HARNESS_PHASE/verify.sh" --run "$run_id"
        advanced finish --phase "$HARNESS_PHASE" --run-dir "$run_dir"
        "$HARNESS_REPO_ROOT/scripts/validate-json.py" "$HARNESS_REPO_ROOT/schemas/phase-manifest.schema.json" "$manifest"
        "$HARNESS_REPO_ROOT/scripts/validate-json.py" "$HARNESS_REPO_ROOT/schemas/command-code-phase-result.schema.json" "$run_dir/command-code-result.json"
      ) >"$attempt/command.log" 2>&1
      rc=$?; set -e
      safe_failure "$rc" verify "$run_dir" "$attempt/command.log" || return "$rc"
      python3 "$HARNESS_REPO_ROOT/scripts/console-checks.py" --phase "$HARNESS_PHASE"
      ;;
  esac
}
