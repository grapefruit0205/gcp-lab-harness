#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
config="$repo_root/config/phase-07-users.json"
export CLOUDSDK_CORE_DISABLE_FILE_LOGGING=1
case "${1:---check}" in
  --setup)
    shift
    options=(--setup)
    while [[ "$#" -gt 0 ]]; do
      case "$1" in
        --user1|--user2) [[ "$#" -ge 2 ]] || { printf 'FAIL: 이메일 값이 필요합니다.\n' >&2; exit 2; }; options+=("$1" "$2"); shift 2 ;;
        --no-login) options+=("$1"); shift ;;
        --help|-h) exec python3 "$repo_root/phases/07/auth.py" --config "$config" --help ;;
        *) printf 'FAIL: 지원하지 않는 계정 설정 옵션: %s\n' "$1" >&2; exit 2 ;;
      esac
    done
    exec python3 "$repo_root/phases/07/auth.py" --config "$config" "${options[@]}"
    ;;
  --ensure|-h|--help)
    [[ "$#" -eq 1 ]] || { printf 'FAIL: 추가 인수는 허용하지 않습니다.\n' >&2; exit 2; }
    exec python3 "$repo_root/phases/07/auth.py" --config "$config" "$1"
    ;;
  --check)
    [[ "$#" -le 1 ]] || { printf 'FAIL: --check 뒤 추가 인수는 허용하지 않습니다.\n' >&2; exit 2; }
    exec python3 "$repo_root/phases/07/auth.py" --config "$config"
    ;;
  --login-user1|--login-user2)
    [[ "$#" -eq 1 ]] || { printf 'FAIL: 로그인 옵션 뒤 추가 인수는 허용하지 않습니다.\n' >&2; exit 2; }
    key="${1#--login-}"
    exec python3 "$repo_root/phases/07/auth.py" --config "$config" --login "$key"
    ;;
  *) printf '사용법: %s [--setup [--user1 <이메일> --user2 <이메일>] [--no-login]|--check|--login-user1|--login-user2]\n' "$0" >&2; exit 2 ;;
esac
