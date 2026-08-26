#!/usr/bin/env bash
# Phase 08: saved run/project/account/source 및 소유권 경계.
p08_source_sha() {
  (cd "$repo_root"; sha256sum phases/08/{execute.sh,verify.sh,support.sh,storage_lab.py,fixture.html} \
    phases/08/terraform/{main.tf,.terraform.lock.hcl} \
    lib/harness/{phase-adapter.sh,terraform.sh,config.sh,common.sh} | sha256sum | awk '{print $1}')
}

p08_context() {
  run_id="$1"
  harness_validate_run_id "$run_id" || return
  [[ "${HARNESS_ENVIRONMENT:-}" == lab && "$GCP_PROJECT_ID" == "${GCP_ALLOWED_PROJECTS:-}" &&
     "${GCP_CLEANUP_ON_FAILURE:-}" == true ]] || { harness_die "Phase 08 project allowlist/cleanup 설정 불일치"; return 1; }
  run_dir="$repo_root/artifacts/runs/$run_id/phase-08"
  tfvars="$run_dir/work/phase-08.auto.tfvars.json"
  manifest="$run_dir/manifest.json"
  jq -e --arg run "$run_id" --arg project "$GCP_PROJECT_ID" \
    '.run_id==$run and .project_id==$project and (.runner|type=="string")' "$tfvars" >/dev/null || return
  p08_runner="$(jq -r .runner "$tfvars")"
}

p08_approved_context() {
  local bundle="$run_dir/plan-bundle.json" actions="$run_dir/action-plan.json"
  [[ "$(harness_sha256_file "$bundle")" == "$(jq -r .plan.bundle_sha256 "$manifest")" &&
     "$(harness_sha256_file "$actions")" == "$(jq -r .action_plan.sha256 "$bundle")" ]] || return 1
  jq -e --arg run "$run_id" --arg code "$(p08_source_sha)" --arg inputs "$(harness_sha256_file "$tfvars")" '
    .phase=="08" and .run_id==$run and
    ([.actions[]|select(.id=="implementation")|.target]==[$code]) and
    ([.actions[]|select(.id=="saved-inputs")|.target]==[$inputs])' "$actions" >/dev/null || return
  # destroy가 실행할 work module도 plan 시점의 추적 소스와 같아야 한다.
  cmp "$run_dir/work/main.tf" "$repo_root/phases/08/terraform/main.tf" >/dev/null || return
  cmp "$run_dir/work/.terraform.lock.hcl" "$repo_root/phases/08/terraform/.terraform.lock.hcl" >/dev/null || return
  local candidate
  while IFS= read -r candidate; do
    case "$candidate" in main.tf|phase-08.auto.tfvars.json) ;; *) return 1 ;; esac
  done < <(find "$run_dir/work" -maxdepth 1 -type f \( -name '*.tf' -o -name '*.tf.json' -o -name '*.tfvars' -o -name '*.tfvars.json' \) -printf '%f\n')
}

p08_identity() {
  local setting value
  while IFS= read -r setting; do
    case "$setting" in TF_CLI_ARGS*|TF_VAR_*|CLOUDSDK_API_ENDPOINT_OVERRIDES_*|CLOUDSDK_STORAGE_KEY_STORE_PATH)
      [[ -z "${!setting:-}" ]] || { harness_die "Phase 08 실행 override를 해제하세요: $setting"; return 1; } ;;
    esac
  done < <(compgen -e)
  for setting in CLOUDSDK_AUTH_ACCESS_TOKEN CLOUDSDK_AUTH_ACCESS_TOKEN_FILE CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT; do
    [[ -z "${!setting:-}" ]] || { harness_die "Phase 08 인증 override를 해제하세요: $setting"; return 1; }
  done
  for setting in auth/impersonate_service_account auth/access_token_file auth/credential_file_override storage/key_store_path; do
    value="$(gcloud config get-value "$setting" 2>/dev/null)" || return
    [[ -z "$value" || "$value" == '(unset)' ]] || { harness_die "Phase 08 전용 실행을 위해 설정을 해제하세요: $setting"; return 1; }
  done
  [[ "$p08_runner" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ && "$p08_runner" != *.gserviceaccount.com ]] || return 1
  export CLOUDSDK_CORE_ACCOUNT="$p08_runner" CLOUDSDK_CORE_LOG_HTTP=false CLOUDSDK_CORE_DISABLE_FILE_LOGGING=1
  unset GOOGLE_APPLICATION_CREDENTIALS GOOGLE_CREDENTIALS GOOGLE_CLOUD_KEYFILE_JSON GCLOUD_KEYFILE_JSON GOOGLE_IMPERSONATE_SERVICE_ACCOUNT
  GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud auth print-access-token --account="$p08_runner" --quiet)" || return
  export GOOGLE_OAUTH_ACCESS_TOKEN
  python3 "$repo_root/phases/08/storage_lab.py" identity --account "$p08_runner" >/dev/null
}

p08_lab() {
  python3 "$repo_root/phases/08/storage_lab.py" "$1" --run-dir "$run_dir"
}

p08_state_guard() {
  terraform -chdir="$run_dir/work" show -json |
    jq -e --arg name "gcp-lab-p08-$run_id" --arg project "$GCP_PROJECT_ID" '
      (.values.root_module // {}) as $root |
      (($root.child_modules // []) | length==0) and
      (($root.resources // []) | length<=1 and all(
        .address=="google_storage_bucket.lab" and .type=="google_storage_bucket" and
        .values.name==$name and .values.id==$name and .values.project==$project))' >/dev/null
}

p08_lock() {
  p08_lock_owned=false
  p08_lock_dir="$repo_root/artifacts/locks/phase-08-$run_id.lock.d"
  if [[ "${P08_LOCK_HELD:-}" == "$run_id" && -f "$p08_lock_dir/pid" &&
        "${P08_LOCK_OWNER:-}" == "$(<"$p08_lock_dir/pid")" ]] && kill -0 "$P08_LOCK_OWNER" 2>/dev/null; then
    return 0
  fi
  mkdir -p "$repo_root/artifacts/locks"
  mkdir "$p08_lock_dir" 2>/dev/null || { harness_die "이미 실행 중이거나 중단된 Phase 08 lock입니다. 실행 프로세스를 확인하세요."; return 1; }
  printf '%s\n' "$$" >"$p08_lock_dir/pid"
  p08_lock_owned=true
  export P08_LOCK_HELD="$run_id" P08_LOCK_OWNER="$$"
}

p08_unlock() {
  [[ "${p08_lock_owned:-false}" == true ]] || return 0
  rm -f "$p08_lock_dir/pid"
  rmdir "$p08_lock_dir"
}
