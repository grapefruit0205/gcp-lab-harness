#!/usr/bin/env bash
set +x
set -Eeuo pipefail
umask 077
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export HARNESS_REPO_ROOT="$repo_root" HARNESS_PHASE=08 HARNESS_PHASE_RESOURCE_LIMIT=1
export HARNESS_PHASE_ALLOWED_TYPES_JSON='["google_storage_bucket"]'
phase_preflight() {
  python3 "$repo_root/phases/08/storage_lab.py" preflight --project "$GCP_PROJECT_ID" --run "$1" >/dev/null
}
phase_write_tfvars() {
  jq -n --arg project_id "$GCP_PROJECT_ID" --arg run_id "$2" --arg region "$GCP_REGION" --arg runner "$p08_runner" \
    '{project_id:$project_id,run_id:$run_id,region:$region,runner:$runner}' >"$1"
}
phase_write_action_plan() {
  jq -n --arg run_id "$2" --arg code "$(p08_source_sha)" \
    --arg inputs "$(harness_sha256_file "$(dirname "$1")/work/phase-08.auto.tfvars.json")" \
    '{schema_version:1,phase:"08",run_id:$run_id,actions:[
    {id:"implementation",kind:"local",target:$code,mutation:"실행 코드·fixture SHA 확인",rollback:"none",timeout_seconds:30,contains_secret:false},
    {id:"saved-inputs",kind:"local",target:$inputs,mutation:"run/project/region/실제 사용자 고정",rollback:"로그인·기존 설정 유지",timeout_seconds:30,contains_secret:false},
    {id:"object-acl",kind:"http",target:("gcp-lab-p08-"+$run_id+"/setup.html"),mutation:"private ACL; no-store fixture에만 조건부 allUsers READER; 익명 hash 확인",rollback:"generation 고정 private ACL 회수·재검증; 실패 시 run bucket destroy",timeout_seconds:300,contains_secret:false},
    {id:"csek-rotate",kind:"http",target:("gcp-lab-p08-"+$run_id+"/{setup2.html,setup3.html}"),mutation:"메모리 CSEK 2개로 upload/rewrite·구키 거부·신키 hash 검사",rollback:"키 폐기 전 두 객체의 전체 암호화 세대 삭제; soft-delete=0; 실패 시 run destroy",timeout_seconds:600,contains_secret:true},
    {id:"version-restore",kind:"http",target:("gcp-lab-p08-"+$run_id+"/setup.html"),mutation:"원본·5줄씩 줄인 2세대 생성/목록; 저장 generation을 로컬 복구하고 hash 비교",rollback:"bucket 전체 세대 force destroy",timeout_seconds:300,contains_secret:false},
    {id:"recursive-sync",kind:"gcloud",target:("gcp-lab-p08-"+$run_id+"/firstlevel/"),mutation:"recursive rsync; 정확한 객체 집합과 다운로드 hash 비교",rollback:"bucket 전체 세대 force destroy",timeout_seconds:300,contains_secret:false}
  ]}' >"$1"
}
phase_plan_guard() {
  python3 "$repo_root/phases/08/storage_lab.py" guard-plan --plan "$1" \
    --inputs "$(dirname "$1")/work/phase-08.auto.tfvars.json"
}
phase_before_apply() {
  p08_context "$1" && p08_approved_context
}
phase_after_apply() { p08_context "$1" && p08_lab record; }
phase_before_destroy() {
  p08_context "$1" && p08_approved_context && p08_state_guard && p08_lab owned
}
source "$repo_root/lib/harness/phase-adapter.sh"
source "$repo_root/phases/08/support.sh"
if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then harness_phase_adapter_usage; exit 0; fi
action="${1:-}"; selected_run=""; arguments=("$@")
[[ "$action" == plan || "$action" == apply || "$action" == verify || "$action" == destroy ]] || { harness_phase_adapter_usage >&2; exit 2; }
for ((i=1; i<${#arguments[@]}; i++)); do
  if [[ "${arguments[$i]}" == --run ]]; then selected_run="${arguments[$((i+1))]:-}"; fi
done
harness_validate_run_id "$selected_run"
harness_load_config "$repo_root/config/harness.env"
if [[ "$action" == plan ]]; then
  p08_runner="$(gcloud config get-value account 2>/dev/null)"
else
  p08_context "$selected_run"
  p08_approved_context || { harness_die "Phase 08 승인 입력/실행 코드가 변경됐습니다."; exit 1; }
fi
p08_identity
# Git Bash에서도 가능한 mkdir lock. 중첩 verify/destroy는 부모 lock을 유지한다.
run_id="$selected_run"
p08_lock
trap p08_unlock EXIT
harness_phase_adapter_main "$@"
