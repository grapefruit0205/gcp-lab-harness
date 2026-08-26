#!/usr/bin/env bash
set +x
set -Eeuo pipefail
umask 077
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export HARNESS_REPO_ROOT="$repo_root" HARNESS_PHASE=09 HARNESS_PHASE_RESOURCE_LIMIT=16
export HARNESS_PHASE_ALLOWED_TYPES_JSON='["google_project_service","google_compute_network","google_compute_subnetwork","google_compute_global_address","google_service_networking_connection","google_compute_firewall","google_service_account","google_project_iam_member","google_sql_database_instance","google_sql_database","google_compute_instance"]'
phase_preflight() {
  p09_prepared_inputs="$(python3 "$repo_root/phases/09/sql_lab.py" prepare --run "$1" --project "$GCP_PROJECT_ID" \
    --region "$GCP_REGION" --zone "$GCP_ZONE" --account "$p09_runner" --cidr "${P09_CLIENT_SOURCE_CIDR:-}")"
  printf '%s\n' "$p09_prepared_inputs" | python3 "$repo_root/phases/09/sql_lab.py" preflight
}
phase_write_tfvars() { printf '%s\n' "$p09_prepared_inputs" >"$1"; }
phase_write_action_plan() {
  python3 "$repo_root/phases/09/recovery.py" baseline --run-dir "$(dirname "$1")"
  jq -n --arg run_id "$2" --arg code "$(p09_source_sha)" \
    --arg baseline "$(harness_sha256_file "$(dirname "$1")/plan-baseline.json")" \
    --arg inputs "$(harness_sha256_file "$(dirname "$1")/work/phase-09.auto.tfvars.json")" '
    {schema_version:1,phase:"09",run_id:$run_id,actions:[
      {id:"implementation",kind:"local",target:$code,mutation:"실행 코드·asset lock SHA 고정",rollback:"none",timeout_seconds:30,contains_secret:false},
      {id:"saved-inputs",kind:"local",target:$inputs,mutation:"본인 계정·project·region·client /32 고정",rollback:"none",timeout_seconds:30,contains_secret:false},
      {id:"plan-baseline",kind:"local",target:$baseline,mutation:"동일 state hash·기존 Cloud identity·허용 create 범위 고정",rollback:"state 보존",timeout_seconds:30,contains_secret:false},
      {id:"failure-policy",kind:"local",target:"preserve-diagnose-replan",mutation:"실패·timeout·중단 시 리소스/state/로그 보존; 코드 변경은 같은 run replan 후 새 SHA 승인",rollback:"자동 destroy/교체 없음; 보존 중 과금 지속",timeout_seconds:30,contains_secret:false},
      {id:"root-database-role",kind:"sql",target:("wordpress-db-"+$run_id+"/root@%"),mutation:"없으면 users.insert; 있으면 BUILT_IN 명시·비밀번호 없는 별도 users.update로 cloudsqlsuperuser 역할 추가·완료 확인 후 비밀번호 갱신. 기존 역할 회수 없음. 실습 전용 DB 관리자",rollback:"SQL/사용자/데이터 유지; 자동 role revoke/destroy 없음",timeout_seconds:600,contains_secret:false},
      {id:"root-password",kind:"sql",target:("wordpress-db-"+$run_id),mutation:"apply 직후 root 난수 초기화, verify 재시도마다 메모리 난수 교체·SQL API 완료 확인",rollback:"실패 시 SQL/데이터 보존; 비밀은 메모리/API/guest에만 유지",timeout_seconds:600,contains_secret:true},
      {id:"guest-config",kind:"guest",target:("wordpress-proxy/private-"+$run_id),mutation:"관리 표식/hash 일치 wp-config만 갱신; PHP lint·DB SELECT1·숫자 errno·미설치 시에만 WP 설치",rollback:"관리 밖 파일은 덮어쓰지 않음; VM/disk 보존",timeout_seconds:900,contains_secret:true},
      {id:"data-paths",kind:"sql",target:("wordpress-db-"+$run_id),mutation:"Auth Proxy public-default marker upsert/private-direct read",rollback:"SQL 데이터 보존",timeout_seconds:600,contains_secret:false},
      {id:"frontend-http",kind:"http",target:("wordpress-proxy/private-"+$run_id),mutation:"제한 /32 HTTP200 본문과 양쪽 SQL marker probe; 검증용 probe만 회수",rollback:"본인이 만든 probe만 회수; 실패 환경 보존",timeout_seconds:600,contains_secret:false}
    ]}' >"$1"
}
phase_plan_guard() {
  python3 "$repo_root/phases/09/sql_lab.py" guard-plan --plan "$1" --inputs "$(dirname "$1")/work/phase-09.auto.tfvars.json"
}
phase_before_apply() { p09_context "$1" && p09_approved_context; }
phase_after_apply() { p09_context "$1" && p09_lab record; }
phase_before_destroy() { p09_context "$1" && p09_approved_context && p09_state_guard && p09_lab owned; }
source "$repo_root/lib/harness/phase-adapter.sh"
source "$repo_root/phases/09/support.sh"
source "$repo_root/phases/09/recovery.sh"
p09_usage() { printf '사용법: %s {plan|replan|apply|verify|diagnose|destroy} --run <id> [--confirm-plan-sha <sha256>]\n' "$0"; }
if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then p09_usage; exit 0; fi
action="${1:-}"; selected_run=""; arguments=("$@")
[[ "$action" =~ ^(plan|replan|apply|verify|diagnose|destroy)$ ]] || { p09_usage >&2; exit 2; }
for ((i=1; i<${#arguments[@]}; i++)); do
  if [[ "${arguments[$i]}" == --run ]]; then selected_run="${arguments[$((i+1))]:-}"; fi
done
harness_validate_run_id "$selected_run"
harness_load_config "$repo_root/config/harness.env"
export GCP_MAX_RESOURCES_PER_PHASE
if [[ "$action" == plan ]]; then
  p09_runner="$(gcloud config get-value account 2>/dev/null)"
else
  p09_context "$selected_run"
  if [[ "$action" == replan || "$action" == diagnose ]]; then
    p09_saved_context || { harness_die "Phase09 이전 계획/입력 불일치"; exit 1; }
  else
    p09_approved_context || { harness_die "Phase09 승인 코드/입력 불일치; 먼저 replan 필요"; exit 1; }
  fi
fi
p09_identity
run_id="$selected_run"
p09_lock
trap p09_unlock EXIT
case "$action" in
  plan) harness_phase_adapter_main "$@" ;;
  *) p09_recovery_main "$@" ;;
esac
