#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export HARNESS_REPO_ROOT="$repo_root"
source "$repo_root/lib/harness/state.sh"

run_id=""
plan_file=""
evidence_file=""
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --run) run_id="${2:-}"; shift 2 ;;
    --plan) plan_file="${2:-}"; shift 2 ;;
    --evidence) evidence_file="${2:-}"; shift 2 ;;
    *) printf '사용법: %s --run <id> [--plan <file> --evidence <file>]\n' "$0" >&2; exit 2 ;;
  esac
done
harness_validate_run_id "$run_id"

state_file="$(harness_state_read "$run_id")"
phase="$(jq -r '.current_phase // empty' "$state_file")"
state="$(jq -r --arg phase "$phase" '.phases[] | select(.phase == $phase) | .state' "$state_file")"
phase_dir="$(harness_run_dir "$run_id")/phase-$phase"
bundle_dir="$phase_dir/single-model"
prompt_file="$bundle_dir/SINGLE_MODEL_REVIEW_PROMPT.md"
report_file="$bundle_dir/single-model-review.json"
mkdir -p "$bundle_dir"
chmod 700 "$bundle_dir"

if [[ "$state" == "machine_verified" ]]; then
  [[ -n "$plan_file" && -n "$evidence_file" ]] || {
    printf 'FAIL: machine_verified 상태에서는 --plan과 --evidence가 필요합니다.\n' >&2
    exit 2
  }
  plan_file="$(realpath -e "$plan_file")"
  evidence_file="$(realpath -e "$evidence_file")"
  diff_file="$bundle_dir/git-diff.patch"
  git -C "$repo_root" diff --binary HEAD >"$diff_file"
  while IFS= read -r -d '' untracked_file; do
    git -C "$repo_root" diff --binary --no-index /dev/null "$untracked_file" >>"$diff_file" || {
      [[ "$?" -eq 1 ]] || exit 1
    }
  done < <(git -C "$repo_root" ls-files --others --exclude-standard -z)
  chmod 600 "$diff_file"
  plan_hash="$(harness_sha256_file "$plan_file")"
  diff_hash="$(harness_sha256_file "$diff_file")"
  evidence_hash="$(harness_sha256_file "$evidence_file")"
  "$repo_root/bin/gcp-lab-harness" gate prepare "$phase" \
    --run "$run_id" \
    --plan-hash "$plan_hash" \
    --diff-hash "$diff_hash" \
    --evidence-hash "$evidence_hash" >/dev/null
elif [[ "$state" == "waiting_extension_review" ]]; then
  plan_hash="$(jq -r --arg phase "$phase" '.phases[] | select(.phase == $phase) | .review_bundle.plan_hash' "$state_file")"
  diff_hash="$(jq -r --arg phase "$phase" '.phases[] | select(.phase == $phase) | .review_bundle.diff_hash' "$state_file")"
  evidence_hash="$(jq -r --arg phase "$phase" '.phases[] | select(.phase == $phase) | .review_bundle.evidence_hash' "$state_file")"
  plan_file="$phase_dir/plan.tfplan"
  evidence_file="$phase_dir/manifest.json"
  diff_file="$phase_dir/extension/git-diff.patch"
  [[ "$(harness_sha256_file "$plan_file")" == "$plan_hash" ]] || {
    printf 'FAIL: 저장 plan이 현재 review bundle hash와 다릅니다.\n' >&2
    exit 1
  }
  [[ "$(harness_sha256_file "$diff_file")" == "$diff_hash" ]] || {
    printf 'FAIL: 저장 diff가 현재 review bundle hash와 다릅니다.\n' >&2
    exit 1
  }
  [[ "$(harness_sha256_file "$evidence_file")" == "$evidence_hash" ]] || {
    printf 'FAIL: 저장 evidence가 현재 review bundle hash와 다릅니다.\n' >&2
    exit 1
  }
else
  printf 'FAIL: 단일 모델 검증 준비는 machine_verified 또는 waiting_extension_review 상태에서만 가능합니다. 현재: %s\n' "$state" >&2
  exit 1
fi

phase_doc="$(harness_phase_doc "$phase")"
{
  sed -n '1,260p' "$repo_root/prompts/single-model-phase.md"
  printf '\n# 검증 대상 Phase\n\n'
  sed -n '1,1000p' "$phase_doc"
  printf '\n# 검증 bundle\n\n'
  printf -- '- run ID: `%s`\n' "$run_id"
  printf -- '- Phase: `%s`\n' "$phase"
  printf -- '- plan SHA256: `%s`\n' "$plan_hash"
  printf -- '- diff SHA256: `%s`\n' "$diff_hash"
  printf -- '- evidence SHA256: `%s`\n' "$evidence_hash"
  printf -- '- 저장 plan: `%s`\n' "$plan_file"
  printf -- '- 저장 diff: `%s`\n' "$diff_file"
  printf -- '- evidence manifest: `%s`\n' "$evidence_file"
  printf -- '- 결과 JSON: `%s`\n' "$report_file"
  printf -- '- JSON Schema: `%s`\n' "$repo_root/schemas/single-model-review.schema.json"
} >"$prompt_file"
chmod 600 "$prompt_file"

printf 'single_model_review_prompt=%s\n' "$prompt_file"
printf 'single_model_review_result=%s\n' "$report_file"
