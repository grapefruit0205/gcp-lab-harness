#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
settings_dir="$repo_root/.commandcode"
settings_file="$settings_dir/settings.json"
temporary=""
trap '[[ -z "$temporary" ]] || rm -f -- "$temporary"' EXIT

mkdir -p "$settings_dir"
if [[ ! -f "$settings_file" ]]; then
  printf '{"permissions":{"allow":[],"deny":[],"defaultMode":"default"}}\n' >"$settings_file"
fi
jq empty "$settings_file"

permissions='[
  "Shell(./bin/gcp-lab-harness:*)",
  "Shell(./scripts/preflight-gcp.sh:*)",
  "Shell(./scripts/validate-design.sh:*)",
  "Shell(./scripts/phase-gate.sh:*)",
  "Shell(./scripts/prepare-single-model-review.sh:*)"
]'
for number in $(seq -w 1 15); do
  permissions="$(jq -c \
    --arg run "Shell(./phases/$number/execute.sh:*)" \
    --arg run_bash "Shell(bash ./phases/$number/execute.sh:*)" \
    --arg verify "Shell(./phases/$number/verify.sh:*)" \
    --arg verify_bash "Shell(bash ./phases/$number/verify.sh:*)" \
    '. + [$run, $run_bash, $verify, $verify_bash]' <<<"$permissions")"
done

temporary="$(mktemp "$settings_dir/.settings.tmp.XXXXXX")"
jq --argjson permissions "$permissions" '
  .permissions = (.permissions // {}) |
  .permissions.allow = (((.permissions.allow // []) + $permissions) | unique) |
  .permissions.deny = (.permissions.deny // []) |
  .permissions.defaultMode = (.permissions.defaultMode // "default")
' "$settings_file" >"$temporary"
chmod 600 "$temporary"
mv -f "$temporary" "$settings_file"
temporary=""

if [[ -d "$repo_root/phases" ]]; then
  find "$repo_root/phases" -mindepth 2 -maxdepth 2 -type f \
    \( -name 'execute.sh' -o -name 'verify.sh' \) -exec chmod u+x {} +
fi

printf 'PASS: Phase 01~15 저장소 .sh 실행 허용 목록을 Command Code 설정에 병합했습니다.\n'
