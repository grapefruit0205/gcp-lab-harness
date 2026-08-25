#!/usr/bin/env bash

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/state.sh"

harness_gate_write_decision() {
  local decision="$1"
  local run_id="$2"
  local phase="$3"
  local plan_hash="$4"
  local diff_hash="$5"
  local evidence_hash="$6"
  local reviewer="$7"
  local findings_file="${8:-}"
  local run_dir
  local approval_file
  local now
  local json

  harness_validate_run_id "$run_id" || return
  harness_validate_phase "$phase" || return
  harness_validate_hash "plan hash" "$plan_hash" || return
  harness_validate_hash "diff hash" "$diff_hash" || return
  harness_validate_hash "evidence hash" "$evidence_hash" || return
  if [[ -z "$reviewer" ]]; then
    harness_die "reviewer local ID는 비어 있을 수 없습니다." 2
    return
  fi
  if [[ "$decision" != "approved" && "$decision" != "rejected" ]]; then
    harness_die "승인 결정은 approved 또는 rejected여야 합니다." 2
    return
  fi
  if [[ "$decision" == "rejected" && -z "$findings_file" ]]; then
    harness_die "반려할 때는 findings 파일이 필요합니다." 2
    return
  fi
  if [[ -n "$findings_file" && ! -f "$findings_file" ]]; then
    harness_die "findings 파일이 없습니다: $findings_file" 2
    return
  fi

  run_dir="$(harness_run_dir "$run_id")"
  approval_file="$run_dir/phase-$phase/extension/${decision}.json"
  now="$(harness_now)"
  json="$(jq -n \
    --arg run_id "$run_id" \
    --arg phase "$phase" \
    --arg decision "$decision" \
    --arg plan_hash "$plan_hash" \
    --arg diff_hash "$diff_hash" \
    --arg evidence_hash "$evidence_hash" \
    --arg reviewed_at "$now" \
    --arg reviewer "$reviewer" \
    --arg findings_file "$findings_file" '
      {
        run_id: $run_id,
        phase: $phase,
        decision: $decision,
        plan_hash: $plan_hash,
        diff_hash: $diff_hash,
        evidence_hash: $evidence_hash,
        reviewed_at: $reviewed_at,
        reviewer_local_id: $reviewer
      }
      + if $findings_file == "" then {} else {findings_file: $findings_file} end
    ')"
  harness_atomic_json_write "$approval_file" "$json"
  if ! harness_state_attach_approval "$run_id" "$phase" "$approval_file" "$decision"; then
    rm -f "$approval_file"
    return 1
  fi
  printf '%s\n' "$approval_file"
}
