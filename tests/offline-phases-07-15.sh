#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$repo_root/lib/harness/terraform.sh"
status_fixture="$(mktemp)"
trap 'rm -f "$status_fixture"' EXIT
for allowed_status in applied verified cleanup_required; do
  jq -n --arg status "$allowed_status" '{status:$status}' >"$status_fixture"
  harness_manifest_require_any_status "$status_fixture" applied verified cleanup_required
done
jq -n '{status:"planned"}' >"$status_fixture"
if harness_manifest_require_any_status "$status_fixture" applied verified cleanup_required 2>/dev/null; then
  printf 'FAIL: planned manifest가 destroy 허용 상태로 처리되었습니다.\n' >&2
  exit 1
fi

for phase in $(seq -w 7 15); do
  "$repo_root/phases/$phase/verify.sh" --offline >/dev/null
  [[ -f "$repo_root/phases/$phase/terraform/.terraform.lock.hcl" ]] || {
    printf 'FAIL: Phase %s provider lockfile 누락\n' "$phase" >&2
    exit 1
  }
done

sample='{"variables":{"vpn_psk":{"value":"TOPSECRET"}},"planned_values":{"root_module":{"resources":[]}},"prior_state":{"values":{}},"resource_changes":[{"address":"x","change":{"before":null,"after":{"shared_secret":"TOPSECRET","name":"safe"},"before_sensitive":false,"after_sensitive":{"shared_secret":true}}}],"output_changes":{"secret":{"before":null,"after":"TOPSECRET","before_sensitive":false,"after_sensitive":true}}}'
sanitized="$(jq -f "$repo_root/scripts/sanitize-terraform-plan.jq" <<<"$sample")"
! grep -Fq TOPSECRET <<<"$sanitized" || {
  printf 'FAIL: 정제 plan에 민감값이 남았습니다.\n' >&2
  exit 1
}
jq -e '
  (has("variables") | not) and
  .resource_changes[0].change.after.shared_secret == "<redacted>" and
  .output_changes.secret.after == "<redacted>"
' <<<"$sanitized" >/dev/null

if git -C "$repo_root" ls-files | rg -q '\.(tfstate|tfplan|pem|key)$|credentials.*\.json$|service-account.*\.json$'; then
  printf 'FAIL: Git 추적 파일에 state, plan 또는 credential 후보가 있습니다.\n' >&2
  exit 1
fi

printf 'PASS: Phase 07–15 offline 계약·lockfile·plan redaction 검증 완료\n'
