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
    *) printf '사용법: %s --run <id> --plan <file> --evidence <file>\n' "$0" >&2; exit 2 ;;
  esac
done
harness_validate_run_id "$run_id"
plan_file="$(realpath -e "$plan_file")"
evidence_file="$(realpath -e "$evidence_file")"

state_file="$(harness_state_read "$run_id")"
phase="$(jq -r '.current_phase // empty' "$state_file")"
state="$(jq -r --arg phase "$phase" '.phases[] | select(.phase == $phase) | .state' "$state_file")"
[[ "$state" == "machine_verified" ]] || {
  printf 'FAIL: 현재 Phase %s 상태가 machine_verified가 아닙니다: %s\n' "$phase" "$state" >&2
  exit 1
}

bundle_dir="$(harness_run_dir "$run_id")/phase-$phase/extension"
diff_file="$bundle_dir/git-diff.patch"
evidence_index="$bundle_dir/evidence-index.json"
mkdir -p "$bundle_dir"
chmod 700 "$bundle_dir"

phase_run_dir="$(harness_run_dir "$run_id")/phase-$phase"
case "$evidence_file" in
  "$phase_run_dir"/*) ;;
  *)
    printf 'FAIL: evidence 파일은 현재 run/Phase 디렉터리 안에 있어야 합니다: %s\n' "$phase_run_dir" >&2
    exit 1
    ;;
esac

if (( 10#$phase >= 7 )); then
  expected_plan_file="$phase_run_dir/plan-bundle.json"
  [[ "$plan_file" == "$expected_plan_file" ]] || {
    printf 'FAIL: Phase %s부터 --plan은 민감값 없는 exact plan-bundle.json이어야 합니다: %s\n' "$phase" "$expected_plan_file" >&2
    exit 1
  }
  expected_bundle_hash="$(jq -r '.plan.bundle_sha256 // empty' "$phase_run_dir/manifest.json")"
  [[ "$expected_bundle_hash" == "$(harness_sha256_file "$plan_file")" ]] || {
    printf 'FAIL: manifest와 plan bundle hash가 일치하지 않습니다.\n' >&2
    exit 1
  }
fi

mapfile -t evidence_files < <(
  {
    printf '%s\n' "$evidence_file"
    [[ ! -f "$phase_run_dir/manifest.json" ]] || printf '%s\n' "$phase_run_dir/manifest.json"
    [[ ! -f "$phase_run_dir/command-code-result.json" ]] || printf '%s\n' "$phase_run_dir/command-code-result.json"
    [[ ! -f "$phase_run_dir/plan-bundle.json" ]] || printf '%s\n' "$phase_run_dir/plan-bundle.json"
    [[ ! -f "$phase_run_dir/action-plan.json" ]] || printf '%s\n' "$phase_run_dir/action-plan.json"
    [[ ! -f "$phase_run_dir/phase-$phase-plan.json" ]] || printf '%s\n' "$phase_run_dir/phase-$phase-plan.json"
    [[ ! -f "$phase_run_dir/source-contract.json" ]] || printf '%s\n' "$phase_run_dir/source-contract.json"
    find "$phase_run_dir/evidence" -maxdepth 1 -type f -name '*.json' -print 2>/dev/null || true
  } | sort -u
)
[[ "${#evidence_files[@]}" -ge 2 ]] || {
  printf 'FAIL: manifest와 machine evidence를 포함한 evidence bundle이 필요합니다.\n' >&2
  exit 1
}
machine_evidence_count="$(find "$phase_run_dir/evidence" -maxdepth 1 -type f -name '*.json' -print 2>/dev/null | wc -l)"
[[ "$machine_evidence_count" -ge 1 ]] || {
  printf 'FAIL: 현재 Phase의 machine evidence JSON이 없습니다.\n' >&2
  exit 1
}
evidence_entries='[]'
for candidate in "${evidence_files[@]}"; do
  jq empty "$candidate" || {
    printf 'FAIL: evidence JSON이 손상되었습니다: %s\n' "$candidate" >&2
    exit 1
  }
  relative_path="${candidate#"$repo_root"/}"
  candidate_hash="$(harness_sha256_file "$candidate")"
  evidence_entries="$(jq --arg path "$relative_path" --arg sha256 "$candidate_hash" '. + [{path:$path,sha256:$sha256}]' <<<"$evidence_entries")"
done
jq -n \
  --arg run_id "$run_id" \
  --arg phase "$phase" \
  --argjson files "$evidence_entries" \
  '{schema_version: 1, run_id: $run_id, phase: $phase, files: $files}' >"$evidence_index"
chmod 600 "$evidence_index"

git -C "$repo_root" diff --binary HEAD >"$diff_file"
while IFS= read -r -d '' untracked_file; do
  git -C "$repo_root" diff --binary --no-index /dev/null "$untracked_file" >>"$diff_file" || {
    [[ "$?" -eq 1 ]] || exit 1
  }
done < <(git -C "$repo_root" ls-files --others --exclude-standard -z)
chmod 600 "$diff_file"

plan_hash="$(harness_sha256_file "$plan_file")"
diff_hash="$(harness_sha256_file "$diff_file")"
evidence_hash="$(harness_sha256_file "$evidence_index")"
"$repo_root/bin/gcp-lab-harness" gate prepare "$phase" \
  --run "$run_id" \
  --plan-hash "$plan_hash" \
  --diff-hash "$diff_hash" \
  --evidence-hash "$evidence_hash" >/dev/null

phase_doc="$(find "$repo_root/docs/phases" -maxdepth 1 -type f -name "phase-$phase-*.md" -print -quit)"
"$repo_root/scripts/prepare-extension-review.sh" "$phase_doc" \
  --run "$run_id" \
  --plan-hash "$plan_hash" \
  --diff-hash "$diff_hash" \
  --evidence-hash "$evidence_hash"
