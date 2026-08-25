#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
phase_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export HARNESS_REPO_ROOT="$repo_root"
source "$repo_root/lib/harness/config.sh"
source "$repo_root/lib/harness/terraform.sh"

usage() {
  printf '사용법: %s {plan|apply|verify|destroy} --run <id> [--confirm-plan-sha <sha256>]\n' "$0"
}
action="${1:-}"
[[ "$action" == "plan" || "$action" == "apply" || "$action" == "verify" || "$action" == "destroy" ]] || { usage >&2; exit 2; }
shift
run_id=""
confirmed_sha=""
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --run) run_id="${2:-}"; shift 2 ;;
    --confirm-plan-sha) confirmed_sha="${2:-}"; shift 2 ;;
    *) usage >&2; exit 2 ;;
  esac
done
harness_validate_run_id "$run_id"
"$repo_root/scripts/preflight-gcp.sh" >/dev/null
harness_load_config "$repo_root/config/harness.env"

module_dir="$phase_dir/terraform"
run_dir="$repo_root/artifacts/runs/$run_id/phase-01"
work_dir="$run_dir/work"
plan_file="$run_dir/phase-01.tfplan"
plan_json="$run_dir/phase-01-plan.json"
manifest_file="$run_dir/manifest.json"
result_file="$run_dir/command-code-result.json"
export TF_DATA_DIR="$run_dir/.terraform"
tf_vars=(-var="project_id=$GCP_PROJECT_ID" -var="run_id=$run_id")
hash_name() { printf '%s' "$1" | sha256sum | awk '{print $1}'; }

case "$action" in
  plan)
    [[ ! -e "$run_dir" ]] || harness_die "이미 존재하는 Phase 01 run입니다: $run_id"
    mkdir -p "$work_dir"
    chmod 700 "$run_dir" "$work_dir"
    cp "$module_dir/main.tf" "$work_dir/main.tf"
    cp "$module_dir/.terraform.lock.hcl" "$work_dir/.terraform.lock.hcl"
    terraform -chdir="$work_dir" init -backend=false -input=false >/dev/null
    harness_tf_timeout terraform -chdir="$work_dir" plan -input=false -lock=false "${tf_vars[@]}" -out="$plan_file"
    terraform -chdir="$work_dir" show -json "$plan_file" >"$plan_json"
    harness_tf_guard_plan "$plan_json" 2 '["google_storage_bucket"]'
    jq -e '([.resource_changes[] | select(.type == "google_storage_bucket")] | length) == 2' "$plan_json" >/dev/null || harness_die "Phase 01 bucket 2개가 plan에 없습니다."
    plan_sha="$(harness_sha256_file "$plan_file")"
    jq -n \
      --arg phase "01" \
      --arg run_id "$run_id" \
      --arg project_hash "$(hash_name "$GCP_PROJECT_ID")" \
      --arg console_hash "$(hash_name "gcp-lab-p01-console-$run_id")" \
      --arg shell_hash "$(hash_name "gcp-lab-p01-shell-$run_id")" '
      {
        phase: $phase,
        run_id: $run_id,
        project_id_hash: $project_hash,
        status: "planned",
        resources: [
          {kind: "google_storage_bucket", name_hash: $console_hash, region: "US"},
          {kind: "google_storage_bucket", name_hash: $shell_hash, region: "US"}
        ],
        checks: [
          {id: "task-1-console-bucket", status: "pending", evidence: "apply 후 bucket describe 필요"},
          {id: "task-2-cloud-shell", status: "manual-boundary", evidence: "Console/Cloud Shell UI는 자동화하지 않고 CLI 환경만 검증"},
          {id: "task-3-shell-bucket", status: "pending", evidence: "apply 후 두 번째 bucket과 목록 일치 확인 필요"},
          {id: "task-4-shell-features", status: "pending", evidence: "fixture upload/download hash 비교 필요"},
          {id: "task-5-persistent-state", status: "pending", evidence: "격리 HOME의 새 Bash profile 재현 필요"},
          {id: "task-6-cleanup", status: "pending", evidence: "사용자 승인 후 destroy와 잔여 0 확인 필요"}
        ],
        cleanup: {status: "not_started", remaining_resource_count: 0}
      }' >"$manifest_file"
    chmod 600 "$plan_file" "$plan_json" "$manifest_file"
    printf 'PASS: Phase 01 저장 plan 생성 완료\nrun_id=%s\nplan_sha256=%s\n' "$run_id" "$plan_sha"
    ;;
  apply)
    harness_assert_saved_plan "$plan_file" "$confirmed_sha"
    harness_tf_apply_saved_plan "$work_dir" "$plan_file" "$manifest_file" "${tf_vars[@]}"
    printf 'PASS: Phase 01 리소스 apply 완료\n'
    ;;
  verify)
    harness_manifest_require_status "$manifest_file" "applied"
    "$phase_dir/verify.sh" --run "$run_id"
    tmp_manifest="$(mktemp "$run_dir/manifest.tmp.XXXXXX")"
    jq '.status = "verified" | .checks |= map(if .id == "task-6-cleanup" or .id == "task-2-cloud-shell" then . else .status = "passed" | .evidence = "machine evidence에서 실제 상태 확인" end)' "$manifest_file" >"$tmp_manifest"
    mv -f "$tmp_manifest" "$manifest_file"
    chmod 600 "$manifest_file"
    jq -n \
      --arg phase "phase-01" \
      --arg session_id "gcp-harness-$run_id-phase-01" \
      --arg run_id "$run_id" '
      {
        phase: $phase,
        status: "waiting_extension_review",
        summary: "Phase 01 bucket·객체 hash·격리 profile 검증 완료",
        session_id: $session_id,
        commands_run: ["terraform apply", "phases/01/verify.sh --run " + $run_id],
        checks: [
          {name: "Task 1: Console 대응 bucket", status: "passed", detail: "비공개 bucket describe"},
          {name: "Task 2: Cloud Shell UI", status: "skipped", detail: "manual boundary; CLI 계정·프로젝트·도구만 확인"},
          {name: "Task 3: Cloud Shell 대응 bucket", status: "passed", detail: "두 번째 bucket과 목록 일치"},
          {name: "Task 4: 객체 작업", status: "passed", detail: "upload/download SHA-256 일치"},
          {name: "Task 5: 지속 상태", status: "passed", detail: "실제 HOME을 건드리지 않은 profile 재로딩"},
          {name: "Task 6: cleanup", status: "skipped", detail: "Extension 검토와 사용자 승인 후 실행"}
        ],
        risks: ["Console과 Cloud Shell UI 자체는 자동 완료로 표시하지 않음"],
        next_action: "extension_review"
      }' >"$result_file"
    chmod 600 "$result_file"
    printf 'PASS: Phase 01 machine verification 완료\n'
    ;;
  destroy)
    [[ -d "$work_dir" ]] || harness_die "Phase 01 work directory가 없습니다: $work_dir"
    harness_tf_destroy "$work_dir" "${tf_vars[@]}"
    remaining_count=0
    for bucket_name in "gcp-lab-p01-console-$run_id" "gcp-lab-p01-shell-$run_id"; do
      gcloud storage buckets describe "gs://$bucket_name" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining_count++)) || true
    done
    [[ "$remaining_count" -eq 0 ]] || {
      harness_manifest_set_status "$manifest_file" "cleanup_required" || true
      harness_die "Phase 01 정리 후 잔여 bucket이 있습니다: ${remaining_count}개"
    }
    tmp_manifest="$(mktemp "$run_dir/manifest.tmp.XXXXXX")"
    jq '.status = "destroyed" | .checks |= map(if .id == "task-6-cleanup" then .status = "passed" | .evidence = "destroy 후 소유 bucket 잔여 0" else . end) | .cleanup.status = "completed" | .cleanup.remaining_resource_count = 0' "$manifest_file" >"$tmp_manifest"
    mv -f "$tmp_manifest" "$manifest_file"
    chmod 600 "$manifest_file"
    printf 'PASS: Phase 01 destroy 및 잔여 리소스 0개 확인 완료\n'
    ;;
esac
