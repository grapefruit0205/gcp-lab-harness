#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export HARNESS_REPO_ROOT="$repo_root"
source "$repo_root/lib/harness/state.sh"

if [[ "${1:-}" != "--run" || "$#" -ne 2 ]]; then
  printf '사용법: %s --run <id>\n' "$0" >&2
  exit 2
fi
run_id="$2"
harness_validate_run_id "$run_id"

command -v cmd >/dev/null 2>&1 || { printf 'FAIL: Command Code CLI cmd가 없습니다.\n' >&2; exit 1; }
cmd status >/dev/null
"$repo_root/scripts/configure-command-code-permissions.sh" >/dev/null

state_file="$(harness_state_read "$run_id")"
phase="$(jq -r '.current_phase // empty' "$state_file")"
state="$(jq -r --arg phase "$phase" '.phases[] | select(.phase == $phase) | .state' "$state_file")"
session_file="$(harness_run_dir "$run_id")/single-model-session"
single_model=false
if [[ -f "$session_file" ]]; then
  single_model=true
fi
case "$state" in
  human_approved)
    if [[ "$single_model" == true ]]; then
      instruction="사용자가 단일 모델 검증 결과를 승인했다. 현재 Phase $phase의 소유 리소스만 destroy하고 잔여 리소스 0을 확인한 뒤 한국어 commit과 push를 완료하라. 상태를 destroyed, committed, pushed 순으로 기록하고 다음 Phase를 같은 단일 모델 계약으로 구현·자기 검증한 뒤 사용자 승인 대기에서 멈춰라."
    else
      instruction="사용자가 VS Code Codex Extension 검증을 승인했다. 현재 Phase $phase의 소유 리소스만 destroy하고 잔여 리소스 0을 확인한 뒤 한국어 commit과 push를 완료하라. 상태를 destroyed, committed, pushed 순으로 기록하고 다음 Phase의 machine_verify까지 진행한 후 Extension review로 handoff하고 멈춰라."
    fi
    ;;
  rejected)
    if [[ "$single_model" == true ]]; then
      instruction="단일 모델 검증이 사용자에게 반려됐다. findings를 읽고 현재 Phase $phase만 수정·재실행한 뒤 같은 모델 자기 검증 결과를 다시 만들고 사용자 승인 대기에서 멈춰라."
    else
      instruction="VS Code Codex Extension 검증이 반려됐다. 승인 파일에 연결된 findings를 읽고 현재 Phase $phase만 수정·재실행한 뒤 machine_verify와 Extension review handoff를 다시 수행하고 멈춰라."
    fi
    ;;
  waiting_extension_review)
    printf 'FAIL: 아직 Extension 사용자 승인 또는 반려가 기록되지 않았습니다.\n' >&2
    exit 1
    ;;
  *)
    printf 'FAIL: handoff next는 human_approved 또는 rejected 상태에서만 가능합니다. 현재: %s\n' "$state" >&2
    exit 1
    ;;
esac

if [[ "$single_model" == true ]]; then
  session_name="$(<"$session_file")"
else
  session_name="gcp-harness-$run_id"
fi
cd "$repo_root"
exec cmd --resume "$session_name" --trust --add-dir "$repo_root" \
  "$instruction Run gcp-lab-harness resume --run $run_id first and preserve every state-machine guardrail."
