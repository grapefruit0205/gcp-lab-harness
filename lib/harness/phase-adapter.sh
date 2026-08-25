#!/usr/bin/env bash

adapter_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$adapter_lib_dir/config.sh"
source "$adapter_lib_dir/terraform.sh"

harness_phase_adapter_usage() {
  printf '사용법: %s {plan|apply|verify|destroy} --run <id> [--confirm-plan-sha <sha256>]\n' "$0"
}

harness_phase_adapter_require_contract() {
  : "${HARNESS_PHASE:?HARNESS_PHASE가 필요합니다.}"
  : "${HARNESS_PHASE_RESOURCE_LIMIT:?HARNESS_PHASE_RESOURCE_LIMIT가 필요합니다.}"
  : "${HARNESS_PHASE_ALLOWED_TYPES_JSON:?HARNESS_PHASE_ALLOWED_TYPES_JSON이 필요합니다.}"
  harness_validate_phase "$HARNESS_PHASE"
  [[ "$HARNESS_PHASE_RESOURCE_LIMIT" =~ ^[0-9]+$ && "$HARNESS_PHASE_RESOURCE_LIMIT" -ge 1 ]] ||
    harness_die "HARNESS_PHASE_RESOURCE_LIMIT는 양의 정수여야 합니다."
  jq -e 'type == "array" and length > 0 and all(type == "string")' \
    <<<"$HARNESS_PHASE_ALLOWED_TYPES_JSON" >/dev/null ||
    harness_die "HARNESS_PHASE_ALLOWED_TYPES_JSON은 비어 있지 않은 문자열 배열이어야 합니다."
  declare -F phase_write_tfvars >/dev/null || harness_die "phase_write_tfvars callback이 없습니다."
  declare -F phase_write_action_plan >/dev/null || harness_die "phase_write_action_plan callback이 없습니다."
}

harness_phase_adapter_mark_destroyed() {
  local manifest_file="$1"
  local run_dir="$2"
  local temporary
  temporary="$(mktemp "$run_dir/manifest.tmp.XXXXXX")"
  jq '.status = "destroyed" | .cleanup.status = "completed" | .cleanup.remaining_resource_count = 0' \
    "$manifest_file" >"$temporary" || { rm -f "$temporary"; return 1; }
  chmod 600 "$temporary"
  mv -f "$temporary" "$manifest_file"
}

harness_phase_adapter_destroy_owned() {
  local run_id="$1"
  local work_dir="$2"
  local phase_dir="$3"
  local state_list
  if declare -F phase_before_destroy >/dev/null; then
    phase_before_destroy "$run_id" || return
  fi
  harness_tf_destroy "$work_dir" || return
  state_list="$(terraform -chdir="$work_dir" state list 2>/dev/null)" || return
  [[ -z "$state_list" ]] || return 1
  "$phase_dir/verify.sh" --destroyed --run "$run_id" || return
  if declare -F phase_after_destroy >/dev/null; then
    phase_after_destroy "$run_id" || return
  fi
}

harness_phase_adapter_main() {
  harness_phase_adapter_require_contract
  local action="${1:-}"
  [[ "$action" == "plan" || "$action" == "apply" || "$action" == "verify" || "$action" == "destroy" ]] || {
    harness_phase_adapter_usage >&2
    return 2
  }
  shift

  local run_id="" confirmed_sha=""
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --run) run_id="${2:-}"; shift 2 ;;
      --confirm-plan-sha) confirmed_sha="${2:-}"; shift 2 ;;
      *) harness_phase_adapter_usage >&2; return 2 ;;
    esac
  done
  harness_validate_run_id "$run_id"

  local repo_root="${HARNESS_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
  local phase_dir="$repo_root/phases/$HARNESS_PHASE"
  local module_dir="$phase_dir/terraform"
  local run_dir="$repo_root/artifacts/runs/$run_id/phase-$HARNESS_PHASE"
  local work_dir="$run_dir/work"
  local plan_file="$run_dir/phase-$HARNESS_PHASE.tfplan"
  local plan_json="$run_dir/phase-$HARNESS_PHASE-plan.json"
  local action_plan="$run_dir/action-plan.json"
  local plan_bundle="$run_dir/plan-bundle.json"
  local contract_file="$run_dir/source-contract.json"
  local manifest_file="$run_dir/manifest.json"
  local result_file="$run_dir/command-code-result.json"
  local tfvars_file="$work_dir/phase-$HARNESS_PHASE.auto.tfvars.json"
  local evidence_file="$run_dir/evidence/phase-$HARNESS_PHASE-machine.json"
  export TF_DATA_DIR="$run_dir/.terraform"

  "$repo_root/scripts/preflight-gcp.sh" >/dev/null
  harness_load_config "$repo_root/config/harness.env"

  case "$action" in
    plan)
      [[ ! -e "$run_dir" ]] || harness_die "이미 존재하는 Phase $HARNESS_PHASE run입니다: $run_id"
      if declare -F phase_preflight >/dev/null; then phase_preflight "$run_id"; fi
      mkdir -p "$work_dir"
      chmod 700 "$run_dir" "$work_dir"
      cp -R "$module_dir"/. "$work_dir"/
      rm -rf "$work_dir/.terraform"
      phase_write_tfvars "$tfvars_file" "$run_id"
      chmod 600 "$tfvars_file"
      terraform -chdir="$work_dir" init -backend=false -input=false >/dev/null
      harness_tf_timeout terraform -chdir="$work_dir" plan -input=false -lock=false -out="$plan_file"
      terraform -chdir="$work_dir" show -json "$plan_file" |
        jq -f "$repo_root/scripts/sanitize-terraform-plan.jq" >"$plan_json"
      harness_tf_guard_plan "$plan_json" "$HARNESS_PHASE_RESOURCE_LIMIT" "$HARNESS_PHASE_ALLOWED_TYPES_JSON"
      if declare -F phase_plan_guard >/dev/null; then phase_plan_guard "$plan_json"; fi

      local phase_doc
      phase_doc="$(harness_phase_doc "$HARNESS_PHASE")"
      "$repo_root/scripts/phase-contract.py" "$phase_doc" >"$contract_file"
      phase_write_action_plan "$action_plan" "$run_id"
      "$repo_root/scripts/validate-json.py" "$repo_root/schemas/action-plan.schema.json" "$action_plan"

      local terraform_sha action_sha bundle_sha project_hash resources_json='[]'
      terraform_sha="$(harness_sha256_file "$plan_file")"
      action_sha="$(harness_sha256_file "$action_plan")"
      jq -n \
        --arg phase "$HARNESS_PHASE" --arg run_id "$run_id" \
        --arg terraform_path "phase-$HARNESS_PHASE.tfplan" --arg terraform_sha256 "$terraform_sha" \
        --arg action_path "action-plan.json" --arg action_sha256 "$action_sha" '
        {
          schema_version: 1,
          phase: $phase,
          run_id: $run_id,
          terraform: {path: $terraform_path, sha256: $terraform_sha256},
          action_plan: {path: $action_path, sha256: $action_sha256}
        }' >"$plan_bundle"
      bundle_sha="$(harness_sha256_file "$plan_bundle")"
      project_hash="$(printf '%s' "$GCP_PROJECT_ID" | sha256sum | awk '{print $1}')"

      while IFS=$'\t' read -r kind name location; do
        [[ -n "$kind" && -n "$name" ]] || continue
        resources_json="$(jq \
          --arg kind "$kind" \
          --arg name_hash "$(printf '%s' "$name" | sha256sum | awk '{print $1}')" \
          --arg region "${location:-global}" \
          '. + [{kind:$kind,name_hash:$name_hash,region:$region}]' <<<"$resources_json")"
      done < <(jq -r '
        .resource_changes[]? |
        select(.change.actions != ["no-op"] and .change.actions != ["read"]) |
        [.type, (.change.after.name? // .address),
         (.change.after.region? // .change.after.zone? // .change.after.location? // "global")] |
        @tsv' "$plan_json")

      jq -n \
        --arg phase "$HARNESS_PHASE" --arg run_id "$run_id" --arg project_hash "$project_hash" \
        --arg terraform_sha "$terraform_sha" --arg action_sha "$action_sha" --arg bundle_sha "$bundle_sha" \
        --argjson resources "$resources_json" --slurpfile contract "$contract_file" '
        {
          phase: $phase,
          run_id: $run_id,
          project_id_hash: $project_hash,
          status: "planned",
          plan: {
            terraform_sha256: $terraform_sha,
            action_plan_sha256: $action_sha,
            bundle_sha256: $bundle_sha
          },
          source_tasks: $contract[0].source_tasks,
          resources: $resources,
          checks: ($contract[0].source_tasks | map({
            id: .id,
            status: (if .classification == "manual-boundary" then "manual-boundary" else "pending" end),
            evidence: .evidence_contract
          })),
          cleanup: {status: "not_started", remaining_resource_count: 0}
        }' >"$manifest_file"
      "$repo_root/scripts/validate-json.py" "$repo_root/schemas/phase-manifest.schema.json" "$manifest_file"
      chmod 600 "$plan_file" "$plan_json" "$action_plan" "$plan_bundle" "$contract_file" "$manifest_file"
      printf 'PASS: Phase %s 저장 plan bundle 생성 완료\nrun_id=%s\nplan_sha256=%s\n' \
        "$HARNESS_PHASE" "$run_id" "$bundle_sha"
      ;;
    apply)
      harness_validate_hash "승인 plan bundle hash" "$confirmed_sha"
      harness_require_file "$plan_bundle" "plan bundle"
      [[ "$(harness_sha256_file "$plan_bundle")" == "$confirmed_sha" ]] ||
        harness_die "승인 hash와 plan bundle hash가 일치하지 않습니다."
      [[ "$(jq -r '.terraform.sha256' "$plan_bundle")" == "$(harness_sha256_file "$plan_file")" ]] ||
        harness_die "plan bundle의 Terraform plan hash가 stale 상태입니다."
      [[ "$(jq -r '.action_plan.sha256' "$plan_bundle")" == "$(harness_sha256_file "$action_plan")" ]] ||
        harness_die "plan bundle의 action plan hash가 stale 상태입니다."
      if ! harness_tf_apply_saved_plan "$work_dir" "$plan_file" "$manifest_file"; then
        rm -f "$plan_file"
        if [[ "${GCP_CLEANUP_ON_FAILURE:-}" == "true" ]] && \
          harness_phase_adapter_destroy_owned "$run_id" "$work_dir" "$phase_dir"; then
          harness_phase_adapter_mark_destroyed "$manifest_file" "$run_dir"
          harness_die "Phase $HARNESS_PHASE apply 실패 뒤 소유 리소스 자동 cleanup과 잔여 0 검증을 완료했습니다. 새 run으로 다시 계획하세요."
          return
        fi
        harness_manifest_set_status "$manifest_file" "cleanup_required" || true
        harness_die "Phase $HARNESS_PHASE apply 실패 뒤 cleanup을 완료하지 못했습니다. manifest를 기준으로 destroy를 재실행하세요."
        return
      fi
      rm -f "$plan_file"
      if declare -F phase_after_apply >/dev/null; then
        local callback_status
        set +e
        (set -Eeuo pipefail; phase_after_apply "$run_id")
        callback_status="$?"
        set -e
        if [[ "$callback_status" -ne 0 ]]; then
          local temporary
          temporary="$(mktemp "$run_dir/manifest.tmp.XXXXXX")"
          jq '.status = "cleanup_required" | .cleanup.status = "failed"' "$manifest_file" >"$temporary"
          chmod 600 "$temporary"
          mv -f "$temporary" "$manifest_file"
          if [[ "${GCP_CLEANUP_ON_FAILURE:-}" == "true" ]] && \
            harness_phase_adapter_destroy_owned "$run_id" "$work_dir" "$phase_dir"; then
            harness_phase_adapter_mark_destroyed "$manifest_file" "$run_dir"
            harness_die "Phase $HARNESS_PHASE apply 후 작업이 실패했지만 소유 리소스 자동 cleanup과 잔여 0 검증을 완료했습니다. 새 run으로 다시 계획하세요."
            return
          fi
          harness_die "Phase $HARNESS_PHASE apply 후 작업이 실패했습니다. 소유 리소스를 destroy할 수 있도록 cleanup_required로 기록했습니다."
          return
        fi
      fi
      printf 'PASS: Phase %s 승인된 Terraform plan apply 완료\n' "$HARNESS_PHASE"
      ;;
    verify)
      harness_manifest_require_status "$manifest_file" "applied"
      "$phase_dir/verify.sh" --run "$run_id"
      harness_require_file "$evidence_file" "Phase machine evidence"
      jq -e --slurpfile contract "$contract_file" '
        .phase == $contract[0].phase and
        ([ $contract[0].source_tasks[].id ] | all(. as $id | (.tasks[$id].status // "") == "passed"))
      ' "$evidence_file" >/dev/null || harness_die "모든 source Task가 machine evidence에서 passed가 아닙니다."
      local temporary
      temporary="$(mktemp "$run_dir/manifest.tmp.XXXXXX")"
      jq --slurpfile evidence "$evidence_file" '
        .status = "verified" |
        .checks |= map(. as $check |
          .status = $evidence[0].tasks[$check.id].status |
          .evidence = $evidence[0].tasks[$check.id].detail)
      ' "$manifest_file" >"$temporary"
      chmod 600 "$temporary"
      mv -f "$temporary" "$manifest_file"
      "$repo_root/scripts/validate-json.py" "$repo_root/schemas/phase-manifest.schema.json" "$manifest_file"
      jq -n --arg phase "phase-$HARNESS_PHASE" --arg session_id "gcp-harness-$run_id-phase-$HARNESS_PHASE" \
        --slurpfile contract "$contract_file" --slurpfile evidence "$evidence_file" '
        {
          phase: $phase,
          status: "waiting_extension_review",
          summary: ("Phase " + $contract[0].phase + " source Task 전체 machine verification 완료"),
          session_id: $session_id,
          commands_run: ["terraform apply saved plan", "phases/" + $contract[0].phase + "/verify.sh --run"],
          checks: ($contract[0].source_tasks | map({
            name: (.id + ": " + .title),
            status: $evidence[0].tasks[.id].status,
            detail: $evidence[0].tasks[.id].detail
          })),
          risks: ($evidence[0].risks // []),
          next_action: "extension_review"
        }' >"$result_file"
      "$repo_root/scripts/validate-json.py" "$repo_root/schemas/command-code-phase-result.schema.json" "$result_file"
      chmod 600 "$manifest_file" "$result_file"
      printf 'PASS: Phase %s machine verification 완료\n' "$HARNESS_PHASE"
      ;;
    destroy)
      harness_manifest_require_any_status "$manifest_file" "applied" "verified" "cleanup_required"
      if ! harness_phase_adapter_destroy_owned "$run_id" "$work_dir" "$phase_dir"; then
        harness_manifest_set_status "$manifest_file" "cleanup_required" || true
        harness_die "Phase $HARNESS_PHASE destroy 또는 잔여 리소스 검증이 실패했습니다."
      fi
      harness_phase_adapter_mark_destroyed "$manifest_file" "$run_dir"
      printf 'PASS: Phase %s destroy와 잔여 리소스 0 검증 완료\n' "$HARNESS_PHASE"
      ;;
  esac
}
