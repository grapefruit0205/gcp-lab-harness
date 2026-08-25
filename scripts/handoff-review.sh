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
mkdir -p "$bundle_dir"
chmod 700 "$bundle_dir"
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

phase_doc="$(find "$repo_root/docs/phases" -maxdepth 1 -type f -name "phase-$phase-*.md" -print -quit)"
"$repo_root/scripts/prepare-extension-review.sh" "$phase_doc" \
  --run "$run_id" \
  --plan-hash "$plan_hash" \
  --diff-hash "$diff_hash" \
  --evidence-hash "$evidence_hash"
