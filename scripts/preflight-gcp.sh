#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config_file="$repo_root/config/harness.env"
export HARNESS_REPO_ROOT="$repo_root"
source "$repo_root/lib/harness/config.sh"
[[ -f "$config_file" ]] || {
  printf 'FAIL: scripts/configure-gcp-project.sh로 config/harness.env를 먼저 만드세요.\n' >&2
  exit 1
}

config_mode="$(stat -c '%a' "$config_file")"
[[ "$config_mode" == "600" ]] || {
  printf 'FAIL: config/harness.env 권한은 0600이어야 합니다. 현재 %s\n' "$config_mode" >&2
  exit 1
}
harness_load_config "$config_file"

[[ "${HARNESS_ENVIRONMENT:-}" == "lab" ]] || {
  printf 'FAIL: HARNESS_ENVIRONMENT는 lab이어야 합니다.\n' >&2
  exit 1
}
[[ -n "${GCP_PROJECT_ID:-}" && "${GCP_ALLOWED_PROJECTS:-}" == "$GCP_PROJECT_ID" ]] || {
  printf 'FAIL: project ID와 단일 allowlist가 exact match여야 합니다.\n' >&2
  exit 1
}
[[ ! "$GCP_PROJECT_ID" =~ (^|[-])(prod|production)([-]|$) ]] || {
  printf 'FAIL: production 표식이 있는 프로젝트를 거부했습니다.\n' >&2
  exit 1
}
[[ "${GCP_CLEANUP_ON_FAILURE:-}" == "true" ]] || {
  printf 'FAIL: GCP_CLEANUP_ON_FAILURE=true가 필요합니다.\n' >&2
  exit 1
}
[[ "${GCP_MAX_APPLY_MINUTES:-}" =~ ^[0-9]+$ && "$GCP_MAX_APPLY_MINUTES" -ge 1 && "$GCP_MAX_APPLY_MINUTES" -le 60 ]] || {
  printf 'FAIL: 최대 apply 시간은 1~60분이어야 합니다.\n' >&2
  exit 1
}
[[ "${GCP_MAX_RESOURCES_PER_PHASE:-}" =~ ^[0-9]+$ && "$GCP_MAX_RESOURCES_PER_PHASE" -ge 1 && "$GCP_MAX_RESOURCES_PER_PHASE" -le 50 ]] || {
  printf 'FAIL: Phase당 최대 리소스 수는 1~50이어야 합니다.\n' >&2
  exit 1
}

for command_name in gcloud terraform jq timeout curl sha256sum; do
  command -v "$command_name" >/dev/null 2>&1 || {
    printf 'FAIL: 필수 명령이 없습니다: %s\n' "$command_name" >&2
    exit 1
  }
done

active_account="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' | head -n 1)"
[[ -n "$active_account" ]] || {
  printf 'FAIL: 활성 gcloud 계정이 없습니다.\n' >&2
  exit 1
}
gcloud auth print-access-token >/dev/null
gcloud auth application-default print-access-token >/dev/null

project_json="$(gcloud projects describe "$GCP_PROJECT_ID" --format=json)"
[[ "$(jq -r '.lifecycleState' <<<"$project_json")" == "ACTIVE" ]] || {
  printf 'FAIL: 허용 프로젝트가 ACTIVE 상태가 아닙니다.\n' >&2
  exit 1
}
billing_json="$(gcloud billing projects describe "$GCP_PROJECT_ID" --format=json)"
[[ "$(jq -r '.billingEnabled' <<<"$billing_json")" == "true" ]] || {
  printf 'FAIL: 허용 프로젝트에 결제가 연결되어 있지 않습니다.\n' >&2
  exit 1
}
actual_billing="$(jq -r '.billingAccountName | sub("^billingAccounts/"; "")' <<<"$billing_json")"
[[ "$actual_billing" == "${GCP_BILLING_ACCOUNT_ID:-}" ]] || {
  printf 'FAIL: 현재 billing 연결이 로컬 승인 설정과 다릅니다.\n' >&2
  exit 1
}

printf 'PASS: GCP 계정, ADC, project allowlist, billing 연결을 확인했습니다.\n'
printf 'account: %s\n' "$active_account"
printf 'project: %s\n' "$GCP_PROJECT_ID"
printf 'budget gate: 사용하지 않음 (D-012); plan 승인·timeout·cleanup gate 유지\n'
