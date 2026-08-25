#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "$#" -ne 1 ]]; then
  printf '사용법: %s docs/phases/phase-NN-name.md\n' "$0" >&2
  exit 2
fi

repo_root="$(git rev-parse --show-toplevel)"
phase_path="$(realpath -e "$1")"
case "$phase_path" in
  "$repo_root"/docs/phases/phase-[0-9][0-9]-*.md) ;;
  *) printf 'Phase 문서는 docs/phases/phase-NN-*.md 형식이어야 합니다.\n' >&2; exit 2 ;;
esac

run_id="$(date -u '+%Y%m%dT%H%M%SZ')-$(basename "$phase_path" .md)"
output_dir="$repo_root/artifacts/reviews/$run_id"
output_file="$output_dir/EXTENSION_REVIEW_PROMPT.md"
mkdir -p "$output_dir"

{
  sed -n '1,240p' "$repo_root/prompts/phase-review.md"
  printf '\n# 검증 대상 Phase\n\n'
  sed -n '1,1000p' "$phase_path"
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
