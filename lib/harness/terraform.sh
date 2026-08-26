#!/usr/bin/env bash

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

harness_tf_timeout() {
  local minutes="${GCP_MAX_APPLY_MINUTES:-}"
  [[ "$minutes" =~ ^[0-9]+$ && "$minutes" -ge 1 && "$minutes" -le 60 ]] || {
    harness_die "GCP_MAX_APPLY_MINUTES는 1~60의 정수여야 합니다."
    return
  }
  timeout --foreground --signal=TERM --kill-after=30s "${minutes}m" "$@"
}

harness_tf_guard_plan() {
  local plan_json="$1"
  local phase_limit="$2"
  local allowed_types_json="$3"
  local configured_limit="${GCP_MAX_RESOURCES_PER_PHASE:-}"

  harness_require_file "$plan_json" "Terraform plan JSON" || return
  [[ "$phase_limit" =~ ^[0-9]+$ && "$phase_limit" -ge 1 ]] || {
    harness_die "Phase 리소스 상한은 양의 정수여야 합니다."
    return
  }
  [[ "$configured_limit" =~ ^[0-9]+$ && "$configured_limit" -ge 1 ]] || {
    harness_die "GCP_MAX_RESOURCES_PER_PHASE가 유효하지 않습니다."
    return
  }
  jq empty <<<"$allowed_types_json" >/dev/null || {
    harness_die "허용 Terraform type 목록이 유효한 JSON이 아닙니다."
    return
  }

  if ! jq -e \
    --arg project "${GCP_PROJECT_ID:-}" \
    --argjson phase_limit "$phase_limit" \
    --argjson configured_limit "$configured_limit" \
    --argjson allowed_types "$allowed_types_json" '
      [
        .resource_changes[]? |
        select(.change.actions != ["no-op"] and .change.actions != ["read"])
      ] as $changes |
      ($changes | length) > 0 and
      ($changes | length) <= $phase_limit and
      ($changes | length) <= $configured_limit and
      ($changes | all(.change.actions == ["create"])) and
      ($changes | all(.type as $type | ($allowed_types | index($type)) != null)) and
      ($changes | all((.change.after.project? // $project) == $project))
    ' "$plan_json" >/dev/null; then
    harness_die "plan에 create 외 action, 허용되지 않은 type/project 또는 리소스 상한 초과가 있습니다."
    return
  fi
}

harness_manifest_require_status() {
  local manifest_file="$1"
  local expected="$2"
  harness_require_file "$manifest_file" "Phase manifest" || return
  jq -e --arg expected "$expected" '.status == $expected' "$manifest_file" >/dev/null || {
    harness_die "manifest 상태가 $expected가 아닙니다."
    return
  }
}

harness_manifest_require_any_status() {
  local manifest_file="$1"
  shift
  local current_status allowed_status
  harness_require_file "$manifest_file" "Phase manifest" || return
  current_status="$(jq -r '.status // empty' "$manifest_file")"
  for allowed_status in "$@"; do
    [[ "$current_status" != "$allowed_status" ]] || return 0
  done
  harness_die "manifest 상태 $current_status에서는 이 작업을 실행할 수 없습니다. 허용 상태: $*"
}

harness_manifest_set_status() {
  local manifest_file="$1"
  local status="$2"
  local temporary
  harness_require_file "$manifest_file" "Phase manifest" || return
  temporary="$(mktemp "$(dirname "$manifest_file")/manifest.tmp.XXXXXX")"
  if ! jq --arg status "$status" '.status = $status' "$manifest_file" >"$temporary"; then
    rm -f "$temporary"
    harness_die "manifest 상태 갱신에 실패했습니다."
    return
  fi
  chmod 600 "$temporary"
  mv -f "$temporary" "$manifest_file"
}

harness_assert_saved_plan() {
  local plan_file="$1"
  local confirmed_sha="$2"
  local actual_sha
  harness_require_file "$plan_file" "저장 Terraform plan" || return
  harness_validate_hash "승인 plan hash" "$confirmed_sha" || return
  actual_sha="$(harness_sha256_file "$plan_file")" || return
  [[ "$actual_sha" == "$confirmed_sha" ]] || {
    harness_die "승인 hash와 저장 plan hash가 일치하지 않습니다."
    return
  }
}

harness_tf_apply_saved_plan() {
  local work_dir="$1"
  local plan_file="$2"
  local manifest_file="$3"
  shift 3

  harness_manifest_require_status "$manifest_file" "planned" || return
  if ! harness_tf_timeout terraform -chdir="$work_dir" apply -input=false "$plan_file"; then
    if [[ "${GCP_CLEANUP_ON_FAILURE:-}" == "true" ]]; then
      harness_tf_timeout terraform -chdir="$work_dir" destroy -auto-approve -input=false "$@" || true
    fi
    local temporary
    temporary="$(mktemp "$(dirname "$manifest_file")/manifest.tmp.XXXXXX")"
    jq '.status = "cleanup_required" | .cleanup.status = "failed"' "$manifest_file" >"$temporary" && {
      chmod 600 "$temporary"
      mv -f "$temporary" "$manifest_file"
    }
    harness_die "Terraform apply가 실패하거나 제한 시간을 초과했습니다. 자동 destroy를 시도했으며 Phase별 잔여 inventory 확인이 필요합니다."
    return
  fi
  harness_manifest_set_status "$manifest_file" "applied"
}

harness_tf_destroy() {
  local work_dir="$1"
  shift
  harness_tf_timeout terraform -chdir="$work_dir" destroy -auto-approve -input=false "$@"
}

harness_wait_until() {
  local timeout_seconds="$1"
  local interval_seconds="$2"
  shift 2
  local deadline=$((SECONDS + timeout_seconds))

  while (( SECONDS < deadline )); do
    if "$@"; then
      return 0
    fi
    sleep "$interval_seconds"
  done
  return 1
}
