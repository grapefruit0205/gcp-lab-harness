#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "$#" -ne 1 ]]; then
  printf '사용법: %s <GCP_PROJECT_ID>\n' "$0" >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$repo_root/scripts/install-home-command.sh"
"$repo_root/scripts/bootstrap-from-clone.sh" "$1"

command_code_bin="${COMMAND_CODE_BIN:-cmd}"
if command -v "$command_code_bin" >/dev/null 2>&1; then
  "$command_code_bin" status >/dev/null || {
    printf 'INFO: Command Code 로그인이 필요합니다. cmd login을 실행하세요.\n' >&2
  }
else
  printf 'INFO: Command Code CLI cmd를 설치한 뒤 cmd login을 실행하세요.\n' >&2
fi

printf '\n다음 명령으로 15단계 구현 세션을 시작하세요.\n'
printf '  gcp-lab-harness start --run lab-$(date -u +%%Y%%m%%d-%%H%%M%%S)\n'
