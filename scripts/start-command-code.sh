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

command_code_bin="${COMMAND_CODE_BIN:-cmd}"
if [[ "$command_code_bin" == */* ]]; then
  [[ -x "$command_code_bin" ]]
else
  command -v "$command_code_bin" >/dev/null 2>&1
fi || {
  printf 'FAIL: Command Code CLI cmd가 없습니다. 설치 후 cmd login을 실행하세요.\n' >&2
  exit 1
}
"$command_code_bin" status >/dev/null
[[ -f "$repo_root/config/harness.env" ]] || {
  printf 'FAIL: 먼저 gcp-lab-harness setup <GCP_PROJECT_ID>를 실행하세요.\n' >&2
  exit 1
}
"$repo_root/scripts/preflight-gcp.sh" >/dev/null
"$repo_root/scripts/configure-command-code-permissions.sh" >/dev/null

state_file="$(harness_state_file "$run_id")"
session_name="gcp-harness-$run_id"
run_dir="$(harness_run_dir "$run_id")"
prompt_file="$run_dir/COMMAND_CODE_START.md"
is_new=true
if [[ -f "$state_file" ]]; then
  is_new=false
else
  "$repo_root/bin/gcp-lab-harness" run init --run "$run_id" --mode cloud >/dev/null
fi

mkdir -p "$run_dir"
chmod 700 "$run_dir"
{
  printf '# Command Code 대화형 오케스트레이션\n\n'
  printf '저장소: %s\n' "$repo_root"
  printf 'run ID: %s\n\n' "$run_id"
  cat <<'PROMPT'
`AGENTS.md`, `docs/orchestration.md`, `memory/CHECKPOINT.md`를 읽고 다음을 지킨다.

1. 전달받은 run ID로 `gcp-lab-harness resume --run <RUN_ID>`를 실행해 현재 Phase와 next_action을 확인한다.
2. 사용자가 자연어로 요청한 현재 단계만 구현한다. 모델과 effort는 변경하지 않는다.
3. `synced → preflight → planned → applied → machine_verified` 상태를 순서대로 진행하고, 각 완료 시 `gcp-lab-harness transition <NN> <state> --run <RUN_ID>`로 기록한다.
4. Cloud apply 전에는 저장 plan의 영향과 SHA256을 사용자에게 보여주고 명시적 승인을 기다린다.
5. machine_verify 완료 뒤 Phase 07 이상은 `gcp-lab-harness handoff review --run <RUN_ID> --plan artifacts/runs/<RUN_ID>/phase-<NN>/plan-bundle.json --evidence artifacts/runs/<RUN_ID>/phase-<NN>/manifest.json`을 실행해 VS Code Codex Extension으로 넘긴 뒤 멈춘다. binary plan은 apply 직후 삭제되며 review 입력으로 사용하지 않는다.
6. 정상 검증 중인 리소스는 Extension 사용자 승인 전 cleanup하지 않고 commit, push, 다음 Phase도 시작하지 않는다. apply·post-apply 실패 시에는 manifest가 소유한 리소스만 `GCP_CLEANUP_ON_FAILURE` 계약으로 정리하고 잔여 0을 보고한다.
7. 이 Phase session은 저장소 소유 `execute.sh`·`verify.sh` 실행을 자동 승인한다. 저장 plan hash 승인과 외부 변경 gate는 별개이며 생략하지 않는다.

먼저 현재 상태를 짧게 설명하고 사용자의 자연어 지시를 기다린다.
PROMPT
  printf '\n실제 RUN_ID는 `%s`다. 모든 `<RUN_ID>` 자리에 이 값을 사용한다.\n' "$run_id"
} >"$prompt_file"
chmod 600 "$prompt_file"

cd "$repo_root"
if [[ "$is_new" == true ]]; then
  exec "$command_code_bin" --name "$session_name" --trust --add-dir "$repo_root" \
    "Read $prompt_file and follow it. Start by reporting the current phase and wait for my natural-language instruction."
else
  exec "$command_code_bin" --resume "$session_name" --trust --add-dir "$repo_root" \
    "Read $prompt_file again, inspect the persisted run state, and continue waiting for my natural-language instruction."
fi
