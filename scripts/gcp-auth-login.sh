#!/usr/bin/env bash
set -Eeuo pipefail

launch_mode="${1:-}"
if [[ -n "$launch_mode" && "$launch_mode" != "--no-launch-browser" ]]; then
  printf '사용법: %s [--no-launch-browser]\n' "$0" >&2
  exit 2
fi

command -v gcloud >/dev/null 2>&1 || {
  printf 'FAIL: 먼저 scripts/install-toolchain.sh를 실행하세요.\n' >&2
  exit 1
}

login_args=(auth login --update-adc)
if [[ "$launch_mode" == "--no-launch-browser" ]]; then
  login_args+=(--no-launch-browser)
fi
gcloud "${login_args[@]}"

active_account="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' | head -n 1)"
[[ -n "$active_account" ]] || {
  printf 'FAIL: 활성 Google Cloud 계정을 확인할 수 없습니다.\n' >&2
  exit 1
}
gcloud auth print-access-token >/dev/null
gcloud auth application-default print-access-token >/dev/null

printf 'PASS: gcloud 사용자 인증과 Terraform용 ADC를 확인했습니다.\n'
printf '활성 계정: %s\n' "$active_account"
printf '접근 가능한 프로젝트:\n'
gcloud projects list --filter='lifecycleState=ACTIVE' --format='table(projectId,name)'
