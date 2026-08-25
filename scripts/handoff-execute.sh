#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "$#" -ne 1 ]]; then
  printf '사용법: %s docs/phases/phase-NN-name.md\n' "$0" >&2
  exit 2
fi

repo_root="$(git rev-parse --show-toplevel)"
phase_path="$(realpath -e "$1")"
case "$phase_path" in
  "$repo_root"/docs/phases/phase-0[1-9]-*.md|"$repo_root"/docs/phases/phase-1[0-5]-*.md) ;;
  *) printf 'Phase 문서는 docs/phases/phase-01..15-*.md 형식이어야 합니다.\n' >&2; exit 2 ;;
esac

phase_number="$(basename "$phase_path" | sed -E 's/^phase-([0-9]{2})-.*/\1/')"
adapter="$repo_root/phases/$phase_number/execute.sh"
if [[ ! -x "$adapter" || ! -f "$repo_root/config/harness.env" ]]; then
  printf 'BLOCKED: Foundation과 Phase %s adapter가 아직 준비되지 않았습니다.\n' "$phase_number" >&2
  printf 'config/harness.env와 실행 가능한 phases/%s/execute.sh가 모두 있어야 cmd handoff를 시작합니다.\n' "$phase_number" >&2
  exit 1
fi

command -v cmd >/dev/null 2>&1 || {
  printf 'Command Code CLI cmd가 설치되어 있지 않습니다.\n' >&2
  exit 1
}
cmd status >/dev/null

run_id="${HARNESS_RUN_ID:-$(date -u '+%Y%m%dT%H%M%SZ')}"
phase_name="$(basename "$phase_path" .md)"
output_dir="$repo_root/artifacts/runs/$run_id/$phase_name/command-code"
prompt_file="$output_dir/EXECUTION_PROMPT.md"
mkdir -p "$output_dir"

{
  sed -n '1,260p' "$repo_root/prompts/phase-execute.md"
  printf '\n# 실행 대상 Phase\n\n'
  sed -n '1,1200p' "$phase_path"
} >"$prompt_file"

# D-009: 모델과 reasoning 설정은 Command Code 계정의 현재 고정값을 상속한다.
cmd -p \
  --name "gcp-harness-$run_id-$phase_name" \
  --output-format json \
  --max-turns "${CMD_MAX_TURNS:-100}" \
  --permission-mode auto-accept \
  --skip-onboarding \
  "Read $prompt_file and execute it exactly. Return only the required final JSON object." \
  | tee "$output_dir/events.jsonl"

printf 'Command Code 실행 기록: %s\n' "$output_dir/events.jsonl"
