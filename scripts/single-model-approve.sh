#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export HARNESS_REPO_ROOT="$repo_root"
source "$repo_root/lib/harness/gate.sh"

if [[ "${1:-}" != "--run" || "$#" -ne 2 ]]; then
  printf '사용법: %s --run <id>\n' "$0" >&2
  exit 2
fi
run_id="$2"
harness_validate_run_id "$run_id"
state_file="$(harness_state_read "$run_id")"
phase="$(jq -r '.current_phase // empty' "$state_file")"
state="$(jq -r --arg phase "$phase" '.phases[] | select(.phase == $phase) | .state' "$state_file")"
[[ "$state" == "waiting_extension_review" ]] || {
  printf 'FAIL: 현재 Phase가 review 대기 상태가 아닙니다: %s\n' "$state" >&2
  exit 1
}

report_file="$(harness_run_dir "$run_id")/phase-$phase/single-model/single-model-review.json"
harness_require_file "$report_file" "단일 모델 검증 결과"
jq -e '
  type == "object" and
  .schema_version == 1 and
  (.checks | type == "array" and length > 0) and
  (.findings | type == "array") and
  (.reviewed_at | type == "string")
' "$report_file" >/dev/null || {
  printf 'FAIL: 단일 모델 검증 결과 구조가 올바르지 않습니다.\n' >&2
  exit 1
}

expected="$(jq -c --arg phase "$phase" '.phases[] | select(.phase == $phase) | [.review_bundle.plan_hash, .review_bundle.diff_hash, .review_bundle.evidence_hash]' "$state_file")"
actual="$(jq -c '[.plan_hash, .diff_hash, .evidence_hash]' "$report_file")"
[[ "$expected" == "$actual" ]] || {
  printf 'FAIL: 단일 모델 검증 결과 hash가 현재 review bundle과 다릅니다.\n' >&2
  exit 1
}
jq -e \
  --arg run_id "$run_id" \
  --arg phase "$phase" '
    .run_id == $run_id and
    .phase == $phase and
    .verdict == "pass" and
    all(.checks[]; .status == "passed") and
    all(.findings[]?; .severity != "P0" and .severity != "P1")
  ' "$report_file" >/dev/null || {
  printf 'FAIL: 모든 검증이 passed가 아니거나 P0/P1 finding이 있습니다.\n' >&2
  exit 1
}

plan_hash="$(jq -r '.plan_hash' "$report_file")"
diff_hash="$(jq -r '.diff_hash' "$report_file")"
evidence_hash="$(jq -r '.evidence_hash' "$report_file")"
"$repo_root/bin/gcp-lab-harness" gate approve "$phase" \
  --run "$run_id" \
  --plan-hash "$plan_hash" \
  --diff-hash "$diff_hash" \
  --evidence-hash "$evidence_hash" \
  --reviewer command-code-single-model-user-approved >/dev/null

printf 'PASS: 사용자 확인에 따라 단일 모델 검증을 승인 상태로 기록했습니다.\n'
printf '다음 실행: gcp-lab-harness handoff next --run %s\n' "$run_id"
