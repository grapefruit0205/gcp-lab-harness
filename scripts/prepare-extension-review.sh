#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "$#" -lt 1 ]]; then
  printf '사용법: %s docs/phases/phase-NN-name.md [--run <id> --plan-hash <sha256> --diff-hash <sha256> --evidence-hash <sha256>]\n' "$0" >&2
  exit 2
fi

repo_root="$(git rev-parse --show-toplevel)"
phase_path="$(realpath -e "$1")"
shift
case "$phase_path" in
  "$repo_root"/docs/phases/phase-[0-9][0-9]-*.md) ;;
  *) printf 'Phase 문서는 docs/phases/phase-NN-*.md 형식이어야 합니다.\n' >&2; exit 2 ;;
esac

run_id=""
plan_hash=""
diff_hash=""
evidence_hash=""
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --run) run_id="${2:-}"; shift 2 ;;
    --plan-hash) plan_hash="${2:-}"; shift 2 ;;
    --diff-hash) diff_hash="${2:-}"; shift 2 ;;
    --evidence-hash) evidence_hash="${2:-}"; shift 2 ;;
    *) printf '검증 handoff 인수가 올바르지 않습니다.\n' >&2; exit 2 ;;
  esac
done

phase_number="$(basename "$phase_path" | sed -E 's/^phase-([0-9]{2})-.*/\1/')"
if [[ -n "$run_id" ]]; then
  [[ "$plan_hash" =~ ^[a-f0-9]{64}$ && "$diff_hash" =~ ^[a-f0-9]{64}$ && "$evidence_hash" =~ ^[a-f0-9]{64}$ ]] || {
    printf 'run 기반 handoff에는 세 SHA256이 모두 필요합니다.\n' >&2
    exit 2
  }
  output_dir="$repo_root/artifacts/runs/$run_id/phase-$phase_number/extension"
else
  run_id="$(date -u '+%Y%m%dT%H%M%SZ')-$(basename "$phase_path" .md)"
  output_dir="$repo_root/artifacts/reviews/$run_id"
fi
output_file="$output_dir/EXTENSION_REVIEW_PROMPT.md"
mkdir -p "$output_dir"

{
  sed -n '1,240p' "$repo_root/prompts/phase-review.md"
  printf '\n# 검증 대상 Phase\n\n'
  sed -n '1,1000p' "$phase_path"
  if [[ -n "$plan_hash" ]]; then
    printf '\n# 승인 대상\n\n'
    printf -- '- run ID: `%s`\n' "$run_id"
    printf -- '- Phase: `%s`\n' "$phase_number"
    printf -- '- plan SHA256: `%s`\n' "$plan_hash"
    printf -- '- diff SHA256: `%s`\n' "$diff_hash"
    printf -- '- evidence SHA256: `%s`\n\n' "$evidence_hash"
    printf '사용자가 검증 완료를 명시적으로 승인한 경우에만 다음 명령을 실행합니다.\n\n```bash\n'
    printf 'gcp-lab-harness gate approve %s --run %s --plan-hash %s --diff-hash %s --evidence-hash %s --reviewer vscode-codex\n' \
      "$phase_number" "$run_id" "$plan_hash" "$diff_hash" "$evidence_hash"
    printf '```\n\n승인 기록 후 Bash 또는 PowerShell에서 `gcp-lab-harness handoff next --run %s`를 실행하면 같은 Command Code 세션이 이어집니다.\n' "$run_id"
  fi
  printf '\n# 현재 Git 상태\n\n```text\n'
  git status --short --branch
  printf '```\n'
} >"$output_file"

printf 'VS Code Codex Extension 검증 prompt: %s\n' "$output_file"
if command -v code >/dev/null 2>&1; then
  code --reuse-window "$repo_root" "$output_file"
  printf 'code CLI로 VS Code workspace와 검증 prompt를 열었습니다.\n'
else
  printf 'code CLI가 없어 자동 handoff하지 못했습니다. VS Code에서 파일을 직접 여세요.\n' >&2
  exit 1
fi
