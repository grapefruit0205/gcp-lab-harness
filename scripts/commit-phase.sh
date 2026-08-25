#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "$#" -ne 2 ]]; then
  printf '사용법: %s docs/phases/phase-NN-name.md "한국어 요약"\n' "$0" >&2
  exit 2
fi

repo_root="$(git rev-parse --show-toplevel)"
phase_path="$(realpath -e "$1")"
summary="$2"
phase_number="$(basename "$phase_path" | sed -E 's/^phase-([0-9]{2})-.*/\1/')"

if [[ ! "$phase_number" =~ ^[0-9]{2}$ ]]; then
  printf 'Phase 문서명이 올바르지 않습니다.\n' >&2
  exit 2
fi
if [[ -z "$summary" ]]; then
  printf '커밋 요약은 비어 있을 수 없습니다.\n' >&2
  exit 2
fi
if git diff --cached --quiet; then
  printf 'stage된 변경이 없습니다. 검증된 파일만 git add 하세요.\n' >&2
  exit 1
fi

"$repo_root/scripts/phase-gate.sh" "$phase_path"
git commit -m "Phase $phase_number: $summary 완료"
