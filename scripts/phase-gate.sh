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
  *) printf 'Phase 문서 경로가 올바르지 않습니다.\n' >&2; exit 2 ;;
esac

"$repo_root/scripts/validate-design.sh"

phase_number="$(basename "$phase_path" | sed -E 's/^phase-([0-9]{2})-.*/\1/')"
phase_verify="$repo_root/phases/$phase_number/verify.sh"
if [[ -x "$phase_verify" ]]; then
  "$phase_verify" --offline
else
  printf 'INFO: phases/%s/verify.sh가 아직 없어 공통 정적 gate만 실행했습니다.\n' "$phase_number"
fi

printf 'PASS: Phase %s 공통 gate를 통과했습니다.\n' "$phase_number"
