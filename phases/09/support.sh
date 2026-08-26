#!/usr/bin/env bash
p09_source_sha() {
  (cd "$repo_root"; sha256sum phases/09/{execute.sh,verify.sh,support.sh,recovery.sh,recovery.py,sql_lab.py,guest_install.py,assets.json} \
    phases/09/terraform/{main.tf,.terraform.lock.hcl} \
    lib/harness/{phase-adapter.sh,terraform.sh,config.sh,common.sh} | sha256sum | awk '{print $1}')
}
p09_context() {
  run_id="$1"
  harness_validate_run_id "$run_id" || return
  [[ "${HARNESS_ENVIRONMENT:-}" == lab && "$GCP_PROJECT_ID" == "${GCP_ALLOWED_PROJECTS:-}" ]] || {
    harness_die "Phase09 project 경계 불일치"; return 1;
  }
  run_dir="$repo_root/artifacts/runs/$run_id/phase-09"
  tfvars="$run_dir/work/phase-09.auto.tfvars.json"
  manifest="$run_dir/manifest.json"
  jq -e --arg run "$run_id" --arg project "$GCP_PROJECT_ID" '.run_id==$run and .project_id==$project' "$tfvars" >/dev/null || return
  p09_runner="$(jq -r .runner "$tfvars")"
}
p09_saved_context() {
  local bundle="$run_dir/plan-bundle.json" actions="$run_dir/action-plan.json" candidate
  [[ "$(harness_sha256_file "$bundle")" == "$(jq -r .plan.bundle_sha256 "$manifest")" &&
     "$(harness_sha256_file "$actions")" == "$(jq -r .action_plan.sha256 "$bundle")" ]] || return 1
  jq -e --arg run "$run_id" --arg inputs "$(harness_sha256_file "$tfvars")" '
    .phase=="09" and .run_id==$run and
    ([.actions[]|select(.id=="saved-inputs")|.target]==[$inputs])' "$actions" >/dev/null || return
  while IFS= read -r candidate; do
    case "$candidate" in main.tf|phase-09.auto.tfvars.json) ;; *) return 1 ;; esac
  done < <(find "$run_dir/work" -maxdepth 1 -type f \( -name '*.tf' -o -name '*.tf.json' -o -name '*.tfvars' -o -name '*.tfvars.json' \) -printf '%f\n')
}
p09_approved_context() {
  p09_saved_context || return
  jq -e --arg code "$(p09_source_sha)" --arg baseline "$(harness_sha256_file "$run_dir/plan-baseline.json")" '
    ([.actions[]|select(.id=="implementation")|.target]==[$code]) and
    ([.actions[]|select(.id=="plan-baseline")|.target]==[$baseline]) and
    ([.actions[]|select(.id=="failure-policy")|.target]==["preserve-diagnose-replan"])' "$run_dir/action-plan.json" >/dev/null || return
  cmp "$run_dir/work/main.tf" "$repo_root/phases/09/terraform/main.tf" >/dev/null || return
  cmp "$run_dir/work/.terraform.lock.hcl" "$repo_root/phases/09/terraform/.terraform.lock.hcl" >/dev/null || return
}
p09_identity() {
  local setting value
  while IFS= read -r setting; do
    case "$setting" in TF_CLI_ARGS*|TF_VAR_*|CLOUDSDK_API_ENDPOINT_OVERRIDES_*)
      [[ -z "${!setting:-}" ]] || { harness_die "Phase09 실행 override 해제 필요: $setting"; return 1; } ;;
    esac
  done < <(compgen -e)
  for setting in CLOUDSDK_AUTH_ACCESS_TOKEN CLOUDSDK_AUTH_ACCESS_TOKEN_FILE CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT; do
    [[ -z "${!setting:-}" ]] || { harness_die "Phase09 인증 override 해제 필요"; return 1; }
  done
  for setting in auth/impersonate_service_account auth/access_token_file auth/credential_file_override; do
    value="$(gcloud config get-value "$setting" 2>/dev/null)" || return
    [[ -z "$value" || "$value" == '(unset)' ]] || { harness_die "Phase09 인증 설정 override 해제 필요"; return 1; }
  done
  [[ "$p09_runner" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ &&
     "$p09_runner" != *.gserviceaccount.com ]] || return 1
  export CLOUDSDK_CORE_ACCOUNT="$p09_runner" CLOUDSDK_CORE_LOG_HTTP=false CLOUDSDK_CORE_DISABLE_FILE_LOGGING=1
  unset GOOGLE_APPLICATION_CREDENTIALS GOOGLE_CREDENTIALS GOOGLE_CLOUD_KEYFILE_JSON GCLOUD_KEYFILE_JSON GOOGLE_IMPERSONATE_SERVICE_ACCOUNT
  GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud auth print-access-token --account="$p09_runner" --quiet)" || return
  export GOOGLE_OAUTH_ACCESS_TOKEN
  python3 "$repo_root/phases/09/sql_lab.py" identity --account "$p09_runner"
}
p09_lab() { python3 "$repo_root/phases/09/sql_lab.py" "$1" --run-dir "$run_dir"; }
p09_state_guard() {
  terraform -chdir="$run_dir/work" show -json |
    python3 "$repo_root/phases/09/sql_lab.py" guard-state --run-dir "$run_dir"
}
p09_lock() {
  p09_lock_owned=false
  p09_lock_dir="$repo_root/artifacts/locks/phase-09-$run_id.lock.d"
  if [[ "${P09_LOCK_HELD:-}" == "$run_id" && -f "$p09_lock_dir/pid" &&
        "${P09_LOCK_OWNER:-}" == "$(<"$p09_lock_dir/pid")" ]] && kill -0 "$P09_LOCK_OWNER" 2>/dev/null; then
    return 0
  fi
  mkdir -p "$repo_root/artifacts/locks"
  mkdir "$p09_lock_dir" 2>/dev/null || { harness_die "Phase09 실행 중이거나 중단된 lock. 프로세스 확인 필요"; return 1; }
  printf '%s\n' "$$" >"$p09_lock_dir/pid"
  p09_lock_owned=true
  export P09_LOCK_HELD="$run_id" P09_LOCK_OWNER="$$"
}
p09_unlock() {
  [[ "${p09_lock_owned:-false}" == true ]] || return 0
  rm -f "$p09_lock_dir/pid"
  rmdir "$p09_lock_dir"
}
