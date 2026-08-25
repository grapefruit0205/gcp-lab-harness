#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "$#" -ne 1 ]]; then
  printf '사용법: %s <GCP_PROJECT_ID>\n' "$0" >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_id="$1"

"$repo_root/scripts/install-toolchain.sh"
if [[ -z "$(gcloud auth list --filter=status:ACTIVE --format='value(account)' | head -n 1)" ]]; then
  "$repo_root/scripts/gcp-auth-login.sh"
fi
"$repo_root/scripts/configure-gcp-project.sh" "$project_id"
"$repo_root/scripts/preflight-gcp.sh"
"$repo_root/scripts/verify-terraform-gcp.sh"

printf 'PASS: clone 이후 로컬 Foundation 구성을 완료했습니다.\n'
