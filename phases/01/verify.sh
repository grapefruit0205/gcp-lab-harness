#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
phase_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export HARNESS_REPO_ROOT="$repo_root"
source "$repo_root/lib/harness/config.sh"
source "$repo_root/lib/harness/terraform.sh"

mode="offline"
run_id=""
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --offline) mode="offline"; shift ;;
    --run) mode="cloud"; run_id="${2:-}"; shift 2 ;;
    *) printf '사용법: %s [--offline | --run <run_id>]\n' "$0" >&2; exit 2 ;;
  esac
done

if [[ "$mode" == "offline" ]]; then
  bash -n "$phase_dir/execute.sh" "$phase_dir/verify.sh"
  terraform -chdir="$phase_dir/terraform" fmt -check >/dev/null
  terraform -chdir="$phase_dir/terraform" init -backend=false -input=false >/dev/null
  terraform -chdir="$phase_dir/terraform" validate >/dev/null
  for token in "Task 1. Cloud console을 사용하여 버킷 생성하기" "Task 2. Cloud Shell 액세스하기" "Task 3. Cloud Shell을 사용하여 Cloud Storage 버킷 생성하기" "Task 4. Cloud Shell의 추가 기능 살펴보기" "Task 5. Cloud Shell에서 지속 상태 만들기" "Task 6. Google Cloud 인터페이스 정리하기"; do
    grep -Fq "$token" "$repo_root/docs/phases/phase-01-console-cloud-shell.md" || harness_die "Phase 01 문서 필수 항목 누락: $token"
  done
  printf 'PASS: Phase 01 offline 계약 검증 완료\n'
  exit 0
fi

harness_validate_run_id "$run_id"
"$repo_root/scripts/preflight-gcp.sh" >/dev/null
harness_load_config "$repo_root/config/harness.env"
run_dir="$repo_root/artifacts/runs/$run_id/phase-01"
manifest_file="$run_dir/manifest.json"
evidence_dir="$run_dir/evidence"
evidence_file="$evidence_dir/phase-01-machine.json"
console_bucket="gcp-lab-p01-console-$run_id"
shell_bucket="gcp-lab-p01-shell-$run_id"
harness_manifest_require_status "$manifest_file" "applied"
mkdir -p "$evidence_dir"
chmod 700 "$evidence_dir"

gcloud info --format=json >/dev/null
active_project="$(gcloud config get-value project 2>/dev/null)"
[[ "$active_project" == "$GCP_PROJECT_ID" ]] || harness_die "gcloud 활성 project가 allowlist project와 다릅니다."
for bucket_name in "$console_bucket" "$shell_bucket"; do
  bucket_json="$(gcloud storage buckets describe "gs://$bucket_name" --project="$GCP_PROJECT_ID" --format=json)"
  jq -e '((.location == "US" or .location_type == "multi-region") and (.storageClass == "STANDARD" or .default_storage_class == "STANDARD")) and ((.public_access_prevention == "enforced") or (.iamConfiguration.publicAccessPrevention == "enforced"))' <<<"$bucket_json" >/dev/null || harness_die "Phase 01 bucket 정책이 plan과 다릅니다."
done

temp_root="$(mktemp -d)"
trap 'rm -rf -- "$temp_root"' EXIT
fixture="$temp_root/fixture.txt"
download="$temp_root/download.txt"
printf 'phase=01\nrun=%s\n' "$run_id" >"$fixture"
fixture_sha="$(sha256sum "$fixture" | awk '{print $1}')"
object_name="fixtures/$run_id.txt"
gcloud storage cp "$fixture" "gs://$shell_bucket/$object_name" >/dev/null
gcloud storage cp "gs://$shell_bucket/$object_name" "$download" >/dev/null
download_sha="$(sha256sum "$download" | awk '{print $1}')"
[[ "$fixture_sha" == "$download_sha" ]] || harness_die "Cloud Storage upload/download SHA-256이 다릅니다."

isolated_home="$temp_root/home"
mkdir -p "$isolated_home"
marker="profile-$run_id"
printf 'export HARNESS_PROFILE_MARKER=%q\n' "$marker" >"$isolated_home/.bashrc"
HOME="$isolated_home" bash --noprofile --rcfile "$isolated_home/.bashrc" -i -c 'test "$HARNESS_PROFILE_MARKER" = "'"$marker"'"' 2>/dev/null || harness_die "격리된 새 Bash에서 profile 환경 변수가 재현되지 않았습니다."

jq -n \
  --arg phase "01" \
  --arg run_id "$run_id" \
  --arg fixture_sha "$fixture_sha" \
  --arg object_hash "$(printf '%s' "$object_name" | sha256sum | awk '{print $1}')" '
  {
    phase: $phase,
    run_id: $run_id,
    checks: {
      account_project_tool_preflight: "passed",
      two_private_buckets: "passed",
      object_roundtrip_sha256: "passed",
      isolated_profile_reload: "passed",
      cloud_shell_ui: "manual-boundary"
    },
    fixture_sha256: $fixture_sha,
    object_name_sha256: $object_hash
  }' >"$evidence_file"
chmod 600 "$evidence_file"
printf 'PASS: Phase 01 bucket·객체 hash·격리 profile 검증 완료\n'
