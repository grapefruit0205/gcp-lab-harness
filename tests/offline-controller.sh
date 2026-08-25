#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export HARNESS_REPO_ROOT="$repo_root"
test_root="$(mktemp -d)"
export HARNESS_STATE_ROOT="$test_root/runs"
trap 'rm -rf -- "$test_root"' EXIT

source "$repo_root/lib/harness/gate.sh"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_json() {
  local file="$1"
  local expression="$2"
  jq -e "$expression" "$file" >/dev/null || fail "JSON assertion 실패: $expression"
}

advance_to_machine_verified() {
  local run_id="$1"
  local phase="$2"
  harness_state_transition "$run_id" "$phase" synced
  harness_state_transition "$run_id" "$phase" preflight
  harness_state_transition "$run_id" "$phase" planned
  harness_state_transition "$run_id" "$phase" applied
  harness_state_transition "$run_id" "$phase" machine_verified
}

plan_hash="$(printf 'a%.0s' {1..64})"
diff_hash="$(printf 'b%.0s' {1..64})"
evidence_hash="$(printf 'c%.0s' {1..64})"
stale_hash="$(printf 'd%.0s' {1..64})"

normal_run="offline-normal-001"
state_file="$(harness_state_init "$normal_run" offline)"
assert_json "$state_file" '.status == "active" and .current_phase == "01" and (.phases | length) == 15'
[[ "$(stat -c '%a' "$(dirname "$state_file")")" == "700" ]] || fail 'run 디렉터리 권한이 0700이 아닙니다.'
[[ "$(stat -c '%a' "$state_file")" == "600" ]] || fail 'pipeline JSON 권한이 0600이 아닙니다.'
advance_to_machine_verified "$normal_run" 01

if harness_state_transition "$normal_run" 01 destroyed >/dev/null 2>&1; then
  fail '허용되지 않은 machine_verified -> destroyed 전이를 수락했습니다.'
fi

harness_state_prepare_review "$normal_run" 01 "$plan_hash" "$diff_hash" "$evidence_hash"
if harness_gate_write_decision approved "$normal_run" 01 "$stale_hash" "$diff_hash" "$evidence_hash" test-reviewer >/dev/null 2>&1; then
  fail 'stale approval을 수락했습니다.'
fi
assert_json "$state_file" '.phases[0].state == "waiting_extension_review"'

approval_file="$(harness_gate_write_decision approved "$normal_run" 01 "$plan_hash" "$diff_hash" "$evidence_hash" test-reviewer)"
assert_json "$approval_file" '.decision == "approved" and .phase == "01"'
[[ "$(stat -c '%a' "$approval_file")" == "600" ]] || fail 'approval JSON 권한이 0600이 아닙니다.'
assert_json "$state_file" '.phases[0].state == "human_approved"'
harness_state_transition "$normal_run" 01 destroyed
harness_state_transition "$normal_run" 01 committed
harness_state_transition "$normal_run" 01 pushed
assert_json "$state_file" '.current_phase == "02" and .phases[0].state == "pushed" and .phases[1].state == "pending"'
next_action="$(harness_state_next_action "$normal_run")"
jq -e '.phase == "02" and .next_action == "sync"' <<<"$next_action" >/dev/null || fail 'resume 동작 계산이 올바르지 않습니다.'
"$repo_root/bin/gcp-lab-harness" status --run "$normal_run" | jq -e '.current_phase == "02"' >/dev/null || fail 'status CLI 출력이 올바르지 않습니다.'
"$repo_root/bin/gcp-lab-harness" resume --run "$normal_run" | jq -e '.next_action == "sync"' >/dev/null || fail 'resume CLI 출력이 올바르지 않습니다.'

rejected_run="offline-reject-001"
rejected_state="$(harness_state_init "$rejected_run" offline)"
advance_to_machine_verified "$rejected_run" 01
harness_state_prepare_review "$rejected_run" 01 "$plan_hash" "$diff_hash" "$evidence_hash"
findings_file="$test_root/findings.md"
printf '# Findings\n\n- 수정 후 다시 검증\n' >"$findings_file"
harness_gate_write_decision rejected "$rejected_run" 01 "$plan_hash" "$diff_hash" "$evidence_hash" test-reviewer "$findings_file" >/dev/null
assert_json "$rejected_state" '.phases[0].state == "rejected"'
next_action="$(harness_state_next_action "$rejected_run")"
jq -e '.next_action == "resume_command_code"' <<<"$next_action" >/dev/null || fail '반려 후 resume 동작이 올바르지 않습니다.'
harness_state_transition "$rejected_run" 01 applied
assert_json "$rejected_state" '.phases[0].attempt == 2 and .phases[0].state == "applied" and .phases[0].review_bundle == null and .phases[0].approval_file == null'

printf 'PASS: 상태 초기화, 전이 제한, stale 승인 거부, 승인·반려, resume를 확인했습니다.\n'
