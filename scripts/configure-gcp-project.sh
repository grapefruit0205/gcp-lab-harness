#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "$#" -ne 1 ]]; then
  printf '사용법: %s <GCP_PROJECT_ID>\n' "$0" >&2
  exit 2
fi

project_id="$1"
[[ "$project_id" =~ ^[a-z][a-z0-9-]{4,28}[a-z0-9]$ ]] || {
  printf 'FAIL: 올바른 Google Cloud project ID 형식이 아닙니다.\n' >&2
  exit 2
}
if [[ "$project_id" =~ (^|[-])(prod|production)([-]|$) ]]; then
  printf 'FAIL: production 표식이 있는 프로젝트는 실습 allowlist에 넣지 않습니다.\n' >&2
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v gcloud >/dev/null 2>&1 || {
  printf 'FAIL: gcloud가 설치되어 있지 않습니다.\n' >&2
  exit 1
}

project_json="$(gcloud projects describe "$project_id" --format=json)"
[[ "$(jq -r '.lifecycleState' <<<"$project_json")" == "ACTIVE" ]] || {
  printf 'FAIL: 프로젝트가 ACTIVE 상태가 아닙니다.\n' >&2
  exit 1
}
billing_json="$(gcloud billing projects describe "$project_id" --format=json)"
[[ "$(jq -r '.billingEnabled' <<<"$billing_json")" == "true" ]] || {
  printf 'FAIL: 프로젝트에 결제가 연결되어 있지 않습니다.\n' >&2
  exit 1
}
billing_account="$(jq -r '.billingAccountName | sub("^billingAccounts/"; "")' <<<"$billing_json")"

if ! gcloud config configurations describe gcp-lab-harness >/dev/null 2>&1; then
  gcloud config configurations create gcp-lab-harness --no-activate
fi
gcloud config set project "$project_id" --configuration=gcp-lab-harness
gcloud auth application-default set-quota-project "$project_id"

config_file="$repo_root/config/harness.env"
temporary_file="$(mktemp "$repo_root/config/.harness.env.tmp.XXXXXX")"
trap 'rm -f -- "$temporary_file"' EXIT
sed \
  -e "s/^GCP_PROJECT_ID=.*/GCP_PROJECT_ID=$project_id/" \
  -e "s/^GCP_ALLOWED_PROJECTS=.*/GCP_ALLOWED_PROJECTS=$project_id/" \
  -e "s/^GCP_BILLING_ACCOUNT_ID=.*/GCP_BILLING_ACCOUNT_ID=$billing_account/" \
  "$repo_root/config/harness.example.env" >"$temporary_file"
chmod 600 "$temporary_file"
mv -f "$temporary_file" "$config_file"
trap - EXIT

printf 'PASS: 전용 gcloud configuration과 로컬 harness.env를 구성했습니다.\n'
printf 'project: %s\n' "$project_id"
printf 'billing: 연결됨 (%s)\n' "$billing_account"
