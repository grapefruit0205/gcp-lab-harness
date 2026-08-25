#!/usr/bin/env bash

if [[ -n "${HARNESS_COMMON_LOADED:-}" ]]; then
  return 0
fi
readonly HARNESS_COMMON_LOADED=1

HARNESS_REPO_ROOT="${HARNESS_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

harness_die() {
  local message="$1"
  local exit_code="${2:-1}"
  printf 'FAIL: %s\n' "$message" >&2
  return "$exit_code"
}

harness_now() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

harness_validate_run_id() {
  local run_id="$1"
  [[ "$run_id" =~ ^[a-z0-9][a-z0-9-]{6,18}[a-z0-9]$ ]] ||
    harness_die "run ID는 8~20자의 소문자·숫자·하이픈이며 영숫자로 끝나야 합니다." 2
}

harness_validate_phase() {
  local phase="$1"
  [[ "$phase" =~ ^(0[1-9]|1[0-5])$ ]] ||
    harness_die "Phase는 01부터 15까지의 두 자리 번호여야 합니다." 2
}

harness_validate_hash() {
  local name="$1"
  local value="$2"
  [[ "$value" =~ ^[a-f0-9]{64}$ ]] ||
    harness_die "$name 값은 소문자 SHA-256이어야 합니다." 2
}

harness_state_root() {
  printf '%s\n' "${HARNESS_STATE_ROOT:-$HARNESS_REPO_ROOT/artifacts/runs}"
}

harness_run_dir() {
  local run_id="$1"
  harness_validate_run_id "$run_id" || return
  printf '%s/%s\n' "$(harness_state_root)" "$run_id"
}

harness_state_file() {
  local run_id="$1"
  local run_dir
  run_dir="$(harness_run_dir "$run_id")" || return
  printf '%s/pipeline.json\n' "$run_dir"
}

harness_phase_doc() {
  local phase="$1"
  local matches=()
  harness_validate_phase "$phase" || return
  mapfile -t matches < <(
    find "$HARNESS_REPO_ROOT/docs/phases" -maxdepth 1 -type f \
      -name "phase-$phase-*.md" -print | sort
  )
  if [[ "${#matches[@]}" -ne 1 ]]; then
    harness_die "Phase $phase 문서를 하나로 결정할 수 없습니다."
    return
  fi
  printf '%s\n' "${matches[0]}"
}

harness_require_file() {
  local path="$1"
  local description="$2"
  if [[ ! -f "$path" ]]; then
    harness_die "$description 파일이 없습니다: $path"
    return
  fi
}

harness_atomic_json_write() {
  local target="$1"
  local json="$2"
  local directory
  local temporary

  directory="$(dirname "$target")"
  mkdir -p "$directory"
  chmod 700 "$directory"
  temporary="$(mktemp "$directory/.json.tmp.XXXXXX")"
  if ! jq empty <<<"$json"; then
    rm -f "$temporary"
    harness_die "원자적으로 저장할 값이 유효한 JSON이 아닙니다."
    return
  fi
  printf '%s\n' "$json" >"$temporary"
  chmod 600 "$temporary"
  mv -f "$temporary" "$target"
}

harness_sha256_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    harness_die "해시를 계산할 파일이 없습니다: $path" 2
    return
  fi
  sha256sum -- "$path" | awk '{print $1}'
}
