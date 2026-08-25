#!/usr/bin/env bash

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

harness_load_config() {
  local config_file="$1"
  local line
  local key
  local value
  local line_number=0
  local -A seen_keys=()

  harness_require_file "$config_file" "하네스 설정" || return
  while IFS= read -r line || [[ -n "$line" ]]; do
    line_number=$((line_number + 1))
    [[ -z "$line" || "$line" == \#* ]] && continue
    if [[ "$line" != *=* ]]; then
      harness_die "설정 $line_number번째 줄이 KEY=VALUE 형식이 아닙니다."
      return
    fi
    key="${line%%=*}"
    value="${line#*=}"
    case "$key" in
      HARNESS_ENVIRONMENT|GCP_PROJECT_ID|GCP_ALLOWED_PROJECTS|GCP_BILLING_ACCOUNT_ID|GCP_REGION|GCP_ZONE|GCP_SECONDARY_REGION|GCP_SECONDARY_ZONE|GCP_IMPERSONATE_SERVICE_ACCOUNT|GCP_RESOURCE_PREFIX|GCP_CLEANUP_ON_FAILURE|GCP_MAX_APPLY_MINUTES|GCP_MAX_RESOURCES_PER_PHASE|GCP_MCP_MONITORING_ENABLED|GCP_MCP_LOGGING_ENABLED|GCP_MCP_VERIFIER_SERVICE_ACCOUNT|GCP_MCP_MODE)
        ;;
      *)
        harness_die "허용되지 않은 설정 key입니다: $key"
        return
        ;;
    esac
    if [[ -n "${seen_keys[$key]:-}" ]]; then
      harness_die "중복 설정 key입니다: $key"
      return
    fi
    [[ "$value" != *'$('* && "$value" != *'`'* ]] || {
      harness_die "설정 값에 실행 가능한 shell 구문을 허용하지 않습니다: $key"
      return
    }
    seen_keys[$key]=1
    printf -v "$key" '%s' "$value"
  done <"$config_file"
}
