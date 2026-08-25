#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "$#" -ne 1 ]]; then
  printf '사용법: %s <GCP_PROJECT_ID>\n' "$0" >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_id="$1"

for command_name in bash git jq sha256sum timeout curl python3 gcloud bq terraform; do
  command -v "$command_name" >/dev/null 2>&1 || {
    printf 'FAIL: Windows bootstrap 필수 명령이 없습니다: %s\n' "$command_name" >&2
    exit 1
  }
done

python3 -c 'import jsonschema' >/dev/null 2>&1 ||
  python3 -m pip install --user --disable-pip-version-check 'jsonschema==4.25.1'

if [[ -z "$(gcloud auth list --filter=status:ACTIVE --format='value(account)' | head -n1)" ]]; then
  gcloud auth login --update-adc
elif ! gcloud auth application-default print-access-token >/dev/null 2>&1; then
  gcloud auth application-default login
fi

"$repo_root/scripts/configure-gcp-project.sh" "$project_id"
"$repo_root/scripts/preflight-gcp.sh"
"$repo_root/scripts/verify-terraform-gcp.sh"

printf 'PASS: WSL 없는 Windows PowerShell/Git Bash Foundation 구성을 완료했습니다.\n'
