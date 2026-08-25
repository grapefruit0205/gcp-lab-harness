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
phase_execute="$repo_root/phases/$phase_number/execute.sh"
phase_verify="$repo_root/phases/$phase_number/verify.sh"
phase_terraform="$repo_root/phases/$phase_number/terraform/main.tf"
[[ -x "$phase_execute" ]] || {
  printf 'FAIL: Phase %s 실행 adapter가 없습니다: %s\n' "$phase_number" "$phase_execute" >&2
  exit 1
}
[[ -x "$phase_verify" ]] || {
  printf 'FAIL: Phase %s verifier가 없습니다: %s\n' "$phase_number" "$phase_verify" >&2
  exit 1
}
[[ -f "$phase_terraform" ]] || {
  printf 'FAIL: Phase %s Terraform 구성이 없습니다: %s\n' "$phase_number" "$phase_terraform" >&2
  exit 1
}
"$repo_root/scripts/phase-contract.py" --check "$phase_path"
"$phase_verify" --offline

printf 'PASS: Phase %s 공통 gate를 통과했습니다.\n' "$phase_number"
