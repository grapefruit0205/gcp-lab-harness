#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export HARNESS_REPO_ROOT="$repo_root"
source "$repo_root/lib/harness/state.sh"

run_id=""
confirmed_sha=""
dry_run=false
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --run) run_id="${2:-}"; shift 2 ;;
    --confirm-plan-sha) confirmed_sha="${2:-}"; shift 2 ;;
    --dry-run) dry_run=true; shift ;;
    *) printf '사용법: %s --run <id> [--confirm-plan-sha <sha256>] [--dry-run]\n' "$0" >&2; exit 2 ;;
  esac
done
harness_validate_run_id "$run_id"
if [[ -n "$confirmed_sha" ]]; then
  harness_validate_hash "plan hash" "$confirmed_sha"
fi

state_file="$(harness_state_file "$run_id")"
if [[ ! -f "$state_file" ]]; then
  "$repo_root/bin/gcp-lab-harness" run init --run "$run_id" --mode cloud >/dev/null
fi
state_file="$(harness_state_read "$run_id")"
phase="$(jq -r '.current_phase // empty' "$state_file")"
state="$(jq -r --arg phase "$phase" '.phases[] | select(.phase == $phase) | .state' "$state_file")"
run_dir="$(harness_run_dir "$run_id")"
single_dir="$run_dir/phase-$phase/single-model"
prompt_file="$single_dir/EXECUTE_AND_REVIEW_PROMPT.md"
events_file="$single_dir/events.jsonl"
session_file="$run_dir/single-model-session"
session_name="gcp-single-$run_id-$phase"
resume_session=false
mkdir -p "$single_dir"
chmod 700 "$run_dir" "$single_dir"
if [[ -f "$session_file" ]]; then
  session_name="$(<"$session_file")"
  resume_session=true
fi

{
  sed -n '1,260p' "$repo_root/prompts/single-model-phase.md"
  printf '\n# 현재 실행\n\n'
  printf -- '- 저장소: `%s`\n' "$repo_root"
  printf -- '- run ID: `%s`\n' "$run_id"
  printf -- '- 현재 Phase: `%s`\n' "$phase"
  printf -- '- 현재 상태: `%s`\n' "$state"
  if [[ -n "$confirmed_sha" ]]; then
    printf -- '- 사용자 승인 plan SHA256: `%s`\n' "$confirmed_sha"
  else
    printf -- '- 사용자 승인 plan SHA256: 없음. apply하지 말고 plan hash 보고 후 중단한다.\n'
  fi
  printf '\n`gcp-lab-harness resume --run %s`부터 실행하고 위 계약을 따른다.\n' "$run_id"
} >"$prompt_file"
chmod 600 "$prompt_file"
printf '%s\n' "$session_name" >"$session_file"
chmod 600 "$session_file"

if [[ "$dry_run" == true ]]; then
  printf 'DRY RUN: 단일 모델 Phase 실행 준비 완료\n'
  printf 'run_id=%s\nphase=%s\nstate=%s\nshell_permission=repository-phase-scripts\nprompt=%s\n' \
    "$run_id" "$phase" "$state" "$prompt_file"
  exit 0
fi

command_code_bin="${COMMAND_CODE_BIN:-cmd}"
if [[ "$command_code_bin" == */* ]]; then [[ -x "$command_code_bin" ]]; else command -v "$command_code_bin" >/dev/null 2>&1; fi || { printf 'FAIL: Command Code CLI cmd가 없습니다.\n' >&2; exit 1; }
"$command_code_bin" status >/dev/null
[[ -f "$repo_root/config/harness.env" ]] || {
  printf 'FAIL: 먼저 gcp-lab-harness setup <GCP_PROJECT_ID>를 실행하세요.\n' >&2
  exit 1
}
"$repo_root/scripts/preflight-gcp.sh" >/dev/null
"$repo_root/scripts/configure-command-code-permissions.sh" >/dev/null

cmd_args=(
  -p
  --trust
  --add-dir "$repo_root"
  --output-format json
  --max-turns "${CMD_MAX_TURNS:-100}"
  --skip-onboarding
)
if [[ "$resume_session" == true ]]; then
  cmd_args+=(--resume "$session_name")
else
  cmd_args+=(--name "$session_name")
fi
cmd_args+=("Read $prompt_file and execute the current Phase contract. Use only the currently configured model.")

cd "$repo_root"
"$command_code_bin" "${cmd_args[@]}" | tee "$events_file"
chmod 600 "$events_file"

state_file="$(harness_state_read "$run_id")"
phase="$(jq -r '.current_phase // empty' "$state_file")"
state="$(jq -r --arg phase "$phase" '.phases[] | select(.phase == $phase) | .state' "$state_file")"
report_file="$(harness_run_dir "$run_id")/phase-$phase/single-model/single-model-review.json"
if [[ "$state" == "planned" ]]; then
  printf 'WAITING: 출력된 저장 plan SHA256을 확인한 뒤 같은 명령에 --confirm-plan-sha를 추가하세요.\n'
elif [[ "$state" == "waiting_extension_review" && -f "$report_file" ]]; then
  printf 'PASS: 단일 모델 검증 결과가 준비됐습니다: %s\n' "$report_file"
  printf '사용자 확인 후: gcp-lab-harness single-model approve --run %s\n' "$run_id"
else
  printf 'INFO: 현재 Phase %s 상태: %s\n' "$phase" "$state"
fi
