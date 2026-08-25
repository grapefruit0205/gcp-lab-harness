#!/usr/bin/env bash
set -uo pipefail

readonly CORE_COMMANDS=(bash git jq cmd code codex curl)
readonly CLOUD_COMMANDS=(gcloud terraform)
missing=0

printf 'Google Cloud 실습 하네스 환경 점검\n'
for command_name in "${CORE_COMMANDS[@]}" "${CLOUD_COMMANDS[@]}"; do
  if command -v "$command_name" >/dev/null 2>&1; then
    case "$command_name" in
      bash) version="$(bash --version | head -n 1)" ;;
      git) version="$(git --version)" ;;
      jq) version="$(jq --version)" ;;
      cmd) version="$(cmd --version | head -n 1)" ;;
      code) version="$(code --version | head -n 1)" ;;
      codex) version="$(codex --version)" ;;
      gcloud) version="$(gcloud --version | head -n 1)" ;;
      terraform) version="$(terraform version | head -n 1)" ;;
      gh) version="$(gh --version | head -n 1)" ;;
      curl) version="$(curl --version | head -n 1)" ;;
    esac
    printf 'PASS  %-10s %s\n' "$command_name" "$version"
  else
    printf 'FAIL  %-10s 설치되지 않음\n' "$command_name"
    missing=1
  fi
done

if command -v gh >/dev/null 2>&1; then
  printf 'PASS  %-10s %s\n' 'gh' "$(gh --version | head -n 1)"
else
  printf 'WARN  %-10s %s\n' 'gh' '선택 도구 — 설치되지 않음'
fi

if cmd status >/dev/null; then
  printf 'PASS  %-10s %s\n' 'cmd-auth' 'Command Code 계정 인증됨'
else
  printf '\nFAIL  cmd        Command Code 계정 인증이 필요합니다.\n' >&2
  missing=1
fi

if code --list-extensions | grep -Fqx 'openai.chatgpt'; then
  printf 'PASS  %-10s %s\n' 'extension' 'VS Code Codex Extension 설치됨'
else
  printf 'FAIL  %-10s %s\n' 'extension' 'VS Code Codex Extension 설치되지 않음' >&2
  missing=1
fi

if [[ "$missing" -ne 0 ]]; then
  printf '\nFoundation 구현을 시작하기 전에 누락된 도구·인증을 준비하세요.\n' >&2
  exit 1
fi

printf '\n'
printf '필수 CLI가 모두 확인되었습니다. Google Cloud 인증과 프로젝트 검사는 Foundation에서 별도로 수행합니다.\n'
