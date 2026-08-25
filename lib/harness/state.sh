#!/usr/bin/env bash

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

harness_state_allowed_transition() {
  local from="$1"
  local to="$2"
  case "$from:$to" in
    pending:synced|synced:preflight|preflight:planned|planned:applied|applied:machine_verified|machine_verified:waiting_extension_review|waiting_extension_review:human_approved|waiting_extension_review:rejected|rejected:applied|human_approved:destroyed|destroyed:committed|committed:pushed)
      return 0
      ;;
    pending:failed|synced:failed|preflight:failed|planned:failed|applied:failed|machine_verified:failed|waiting_extension_review:failed|rejected:failed|human_approved:cleanup_required|destroyed:failed|committed:failed)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

harness_state_init() {
  local run_id="$1"
  local mode="${2:-cloud}"
  local run_dir
  local state_file
  local now
  local json

  harness_validate_run_id "$run_id" || return
  if [[ "$mode" != "cloud" && "$mode" != "offline" ]]; then
    harness_die "실행 모드는 cloud 또는 offline이어야 합니다." 2
    return
  fi
  run_dir="$(harness_run_dir "$run_id")"
  state_file="$run_dir/pipeline.json"
  if [[ -e "$run_dir" ]]; then
    harness_die "이미 존재하는 run ID입니다: $run_id"
    return
  fi

  now="$(harness_now)"
  json="$(jq -n \
    --arg run_id "$run_id" \
    --arg mode "$mode" \
    --arg now "$now" '
      {
        schema_version: 1,
        run_id: $run_id,
        mode: $mode,
        status: "active",
        current_phase: "01",
        created_at: $now,
        updated_at: $now,
        phases: [
          range(1; 16) as $number |
          {
            phase: (if $number < 10 then "0" + ($number | tostring) else ($number | tostring) end),
            state: "pending",
            attempt: 0,
            updated_at: $now,
            review_bundle: null,
            approval_file: null
          }
        ],
        history: []
      }
    ')"
  harness_atomic_json_write "$state_file" "$json"
  printf '%s\n' "$state_file"
}

harness_state_read() {
  local run_id="$1"
  local state_file
  state_file="$(harness_state_file "$run_id")"
  harness_require_file "$state_file" "run 상태" || return
  if ! jq empty "$state_file"; then
    harness_die "run 상태 JSON이 손상되었습니다: $state_file"
    return
  fi
  printf '%s\n' "$state_file"
}

harness_state_transition() {
  local run_id="$1"
  local phase="$2"
  local next_state="$3"
  local state_file
  local run_dir
  local current_phase
  local current_state
  local now
  local temporary
  local next_phase
  local lock_fd

  harness_validate_phase "$phase" || return
  state_file="$(harness_state_read "$run_id")" || return
  run_dir="$(dirname "$state_file")"
  exec {lock_fd}>"$run_dir/.pipeline.lock"
  flock -x "$lock_fd"

  current_phase="$(jq -r '.current_phase // empty' "$state_file")"
  current_state="$(jq -r --arg phase "$phase" '.phases[] | select(.phase == $phase) | .state' "$state_file")"
  if [[ "$current_phase" != "$phase" ]]; then
    flock -u "$lock_fd"
    exec {lock_fd}>&-
    harness_die "현재 실행 Phase는 ${current_phase:-없음}이며 Phase $phase를 전이할 수 없습니다."
    return
  fi
  if [[ -z "$current_state" ]]; then
    flock -u "$lock_fd"
    exec {lock_fd}>&-
    harness_die "Phase $phase 상태가 없습니다."
    return
  fi
  if ! harness_state_allowed_transition "$current_state" "$next_state"; then
    flock -u "$lock_fd"
    exec {lock_fd}>&-
    harness_die "허용되지 않은 상태 전이입니다: $current_state -> $next_state"
    return
  fi

  now="$(harness_now)"
  next_phase="$(printf '%02d' "$((10#$phase + 1))")"
  temporary="$(mktemp "$run_dir/.pipeline.tmp.XXXXXX")"
  if ! jq \
    --arg phase "$phase" \
    --arg from "$current_state" \
    --arg to "$next_state" \
    --arg now "$now" \
    --arg next_phase "$next_phase" '
      .updated_at = $now |
      .phases |= map(
        if .phase == $phase then
          .state = $to |
          .updated_at = $now |
          .attempt += (if $to == "applied" then 1 else 0 end) |
          if $from == "rejected" and $to == "applied" then
            .review_bundle = null | .approval_file = null
          else . end
        else . end
      ) |
      .history += [{phase: $phase, from: $from, to: $to, at: $now}] |
      if $to == "pushed" then
        if $phase == "15" then
          .status = "complete" | .current_phase = null
        else
          .current_phase = $next_phase
        end
      elif $to == "failed" or $to == "cleanup_required" then
        .status = "blocked"
      else . end
    ' "$state_file" >"$temporary"; then
    rm -f "$temporary"
    flock -u "$lock_fd"
    exec {lock_fd}>&-
    harness_die "상태 전이 JSON 생성에 실패했습니다."
    return
  fi
  chmod 600 "$temporary"
  mv -f "$temporary" "$state_file"
  flock -u "$lock_fd"
  exec {lock_fd}>&-
}

harness_state_prepare_review() {
  local run_id="$1"
  local phase="$2"
  local plan_hash="$3"
  local diff_hash="$4"
  local evidence_hash="$5"
  local state_file
  local run_dir
  local current_phase
  local current_state
  local now
  local temporary
  local lock_fd

  harness_validate_phase "$phase" || return
  harness_validate_hash "plan hash" "$plan_hash" || return
  harness_validate_hash "diff hash" "$diff_hash" || return
  harness_validate_hash "evidence hash" "$evidence_hash" || return
  state_file="$(harness_state_read "$run_id")" || return
  run_dir="$(dirname "$state_file")"
  exec {lock_fd}>"$run_dir/.pipeline.lock"
  flock -x "$lock_fd"
  current_phase="$(jq -r '.current_phase // empty' "$state_file")"
  current_state="$(jq -r --arg phase "$phase" '.phases[] | select(.phase == $phase) | .state' "$state_file")"
  if [[ "$current_phase" != "$phase" || "$current_state" != "machine_verified" ]]; then
    flock -u "$lock_fd"
    exec {lock_fd}>&-
    harness_die "Extension 검증 준비는 현재 Phase의 machine_verified 상태에서만 가능합니다."
    return
  fi

  now="$(harness_now)"
  temporary="$(mktemp "$run_dir/.pipeline.tmp.XXXXXX")"
  if ! jq \
    --arg phase "$phase" \
    --arg now "$now" \
    --arg plan_hash "$plan_hash" \
    --arg diff_hash "$diff_hash" \
    --arg evidence_hash "$evidence_hash" '
      .updated_at = $now |
      .phases |= map(
        if .phase == $phase then
          .state = "waiting_extension_review" |
          .updated_at = $now |
          .review_bundle = {
            plan_hash: $plan_hash,
            diff_hash: $diff_hash,
            evidence_hash: $evidence_hash,
            prepared_at: $now
          } |
          .approval_file = null
        else . end
      ) |
      .history += [{phase: $phase, from: "machine_verified", to: "waiting_extension_review", at: $now}]
    ' "$state_file" >"$temporary"; then
    rm -f "$temporary"
    flock -u "$lock_fd"
    exec {lock_fd}>&-
    harness_die "Extension 검증 준비 상태 생성에 실패했습니다."
    return
  fi
  chmod 600 "$temporary"
  mv -f "$temporary" "$state_file"
  flock -u "$lock_fd"
  exec {lock_fd}>&-
}

harness_state_attach_approval() {
  local run_id="$1"
  local phase="$2"
  local approval_file="$3"
  local decision="$4"
  local next_state
  local state_file
  local run_dir
  local current_phase
  local current_state
  local expected
  local actual
  local now
  local temporary
  local lock_fd

  harness_validate_phase "$phase" || return
  [[ "$decision" == "approved" || "$decision" == "rejected" ]] ||
    harness_die "승인 결정은 approved 또는 rejected여야 합니다." 2
  state_file="$(harness_state_read "$run_id")" || return
  harness_require_file "$approval_file" "승인" || return
  if ! jq empty "$approval_file"; then
    harness_die "승인 JSON이 손상되었습니다: $approval_file"
    return
  fi
  run_dir="$(dirname "$state_file")"
  exec {lock_fd}>"$run_dir/.pipeline.lock"
  flock -x "$lock_fd"

  current_phase="$(jq -r '.current_phase // empty' "$state_file")"
  current_state="$(jq -r --arg phase "$phase" '.phases[] | select(.phase == $phase) | .state' "$state_file")"
  expected="$(jq -c --arg phase "$phase" '.phases[] | select(.phase == $phase) | .review_bundle | [.plan_hash, .diff_hash, .evidence_hash]' "$state_file")"
  actual="$(jq -c '[.plan_hash, .diff_hash, .evidence_hash]' "$approval_file")"
  if [[ "$current_phase" != "$phase" || "$current_state" != "waiting_extension_review" ]]; then
    flock -u "$lock_fd"
    exec {lock_fd}>&-
    harness_die "승인 반영은 현재 Phase의 waiting_extension_review 상태에서만 가능합니다."
    return
  fi
  if [[ "$expected" != "$actual" ]]; then
    flock -u "$lock_fd"
    exec {lock_fd}>&-
    harness_die "승인 해시가 현재 plan/diff/evidence와 일치하지 않습니다. stale approval을 거부했습니다."
    return
  fi
  if ! jq -e \
    --arg run_id "$run_id" \
    --arg phase "$phase" \
    --arg decision "$decision" '
      .run_id == $run_id and .phase == $phase and .decision == $decision
    ' "$approval_file" >/dev/null; then
    flock -u "$lock_fd"
    exec {lock_fd}>&-
    harness_die "승인 파일의 run ID, Phase 또는 결정이 요청과 일치하지 않습니다."
    return
  fi

  if [[ "$decision" == "approved" ]]; then
    next_state="human_approved"
  else
    next_state="rejected"
  fi
  now="$(harness_now)"
  temporary="$(mktemp "$run_dir/.pipeline.tmp.XXXXXX")"
  if ! jq \
    --arg phase "$phase" \
    --arg now "$now" \
    --arg next_state "$next_state" \
    --arg approval_file "$approval_file" '
      .updated_at = $now |
      .phases |= map(
        if .phase == $phase then
          .state = $next_state |
          .updated_at = $now |
          .approval_file = $approval_file
        else . end
      ) |
      .history += [{phase: $phase, from: "waiting_extension_review", to: $next_state, at: $now}]
    ' "$state_file" >"$temporary"; then
    rm -f "$temporary"
    flock -u "$lock_fd"
    exec {lock_fd}>&-
    harness_die "승인 반영 상태 생성에 실패했습니다."
    return
  fi
  chmod 600 "$temporary"
  mv -f "$temporary" "$state_file"
  flock -u "$lock_fd"
  exec {lock_fd}>&-
}

harness_state_next_action() {
  local run_id="$1"
  local state_file
  local pipeline_status
  local phase
  local state
  local action

  state_file="$(harness_state_read "$run_id")" || return
  pipeline_status="$(jq -r '.status' "$state_file")"
  phase="$(jq -r '.current_phase // empty' "$state_file")"
  if [[ "$pipeline_status" == "complete" ]]; then
    jq -n --arg run_id "$run_id" '{run_id: $run_id, status: "complete", phase: null, next_action: "none"}'
    return
  fi
  state="$(jq -r --arg phase "$phase" '.phases[] | select(.phase == $phase) | .state' "$state_file")"
  case "$state" in
    pending) action="sync" ;;
    synced) action="preflight" ;;
    preflight) action="plan" ;;
    planned) action="apply" ;;
    applied) action="machine_verify" ;;
    machine_verified) action="prepare_extension_review" ;;
    waiting_extension_review) action="extension_review" ;;
    rejected) action="resume_command_code" ;;
    human_approved) action="destroy" ;;
    destroyed) action="commit" ;;
    committed) action="push" ;;
    failed|cleanup_required) action="manual_recovery" ;;
    *) harness_die "알 수 없는 Phase 상태입니다: $state"; return ;;
  esac
  jq -n \
    --arg run_id "$run_id" \
    --arg status "$pipeline_status" \
    --arg phase "$phase" \
    --arg state "$state" \
    --arg action "$action" \
    '{run_id: $run_id, status: $status, phase: $phase, phase_state: $state, next_action: $action}'
}
