#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
phase_dir="$repo_root/phases/07"
export HARNESS_REPO_ROOT="$repo_root"
source "$repo_root/lib/harness/config.sh"
source "$repo_root/lib/harness/terraform.sh"

mode="offline"; run_id=""
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --offline) mode=offline; shift ;;
    --run) [[ "$mode" == destroyed ]] || mode=cloud; run_id="${2:-}"; shift 2 ;;
    --destroyed) mode=destroyed; shift ;;
    *) printf '사용법: %s [--offline|--run <id>|--destroyed --run <id>]\n' "$0" >&2; exit 2 ;;
  esac
done

if [[ "$mode" == offline ]]; then
  bash -n "$phase_dir/execute.sh" "$phase_dir/verify.sh"
  terraform -chdir="$phase_dir/terraform" fmt -check >/dev/null
  "$repo_root/scripts/phase-contract.py" --check "$repo_root/docs/phases/phase-07-iam.md" >/dev/null
  ! rg -q 'google_project_iam_(policy|binding)' "$phase_dir/terraform/main.tf" || harness_die "authoritative project IAM 리소스는 허용하지 않습니다."
  ! rg -q 'google_service_account_key|private_key[[:space:]]*=' "$phase_dir/terraform" "$phase_dir/execute.sh" || harness_die "서비스 계정 키 생성 경로가 있습니다."
  printf 'PASS: Phase 07 offline 계약 검증 완료\n'
  exit 0
fi

harness_validate_run_id "$run_id"
harness_load_config "$repo_root/config/harness.env"
bucket="gcp-lab-p07-$run_id"; vm="p07-probe-$run_id"
actor1="p07-a-${run_id:0:19}@$GCP_PROJECT_ID.iam.gserviceaccount.com"
actor2="p07-b-${run_id:0:19}@$GCP_PROJECT_ID.iam.gserviceaccount.com"
workload="p07-w-${run_id:0:19}@$GCP_PROJECT_ID.iam.gserviceaccount.com"
probe_target="$(jq -r '.actions[] | select(.id=="probe-vm") | .target' "$repo_root/artifacts/runs/$run_id/phase-07/action-plan.json" 2>/dev/null || true)"
debian_image="${probe_target##* image=}"

if [[ "$mode" == destroyed ]]; then
  remaining=0
  gcloud compute instances describe "$vm" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining+=1)) || true
  gcloud storage buckets describe "gs://$bucket" >/dev/null 2>&1 && ((remaining+=1)) || true
  gcloud compute networks describe "p07-net-$run_id" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining+=1)) || true
  for account in "$actor1" "$actor2" "$workload"; do
    gcloud iam service-accounts describe "$account" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining+=1)) || true
  done
  project_policy="$(gcloud projects get-iam-policy "$GCP_PROJECT_ID" --format=json)"
  jq -e --arg actor1 "$actor1" --arg actor2 "$actor2" '
    [.bindings[].members[]? | select(contains($actor1) or contains($actor2))] | length == 0
  ' <<<"$project_policy" >/dev/null || harness_die "Phase 07 project IAM binding 잔여"
  [[ "$remaining" -eq 0 ]] || harness_die "Phase 07 잔여 리소스: $remaining"
  printf 'PASS: Phase 07 잔여 리소스 0\n'; exit 0
fi

run_dir="$repo_root/artifacts/runs/$run_id/phase-07"
manifest="$run_dir/manifest.json"; evidence_dir="$run_dir/evidence"; evidence="$evidence_dir/phase-07-machine.json"
harness_manifest_require_status "$manifest" applied
mkdir -p "$evidence_dir"; chmod 700 "$evidence_dir"
baseline_hash="$(gcloud projects get-iam-policy "$GCP_PROJECT_ID" --format=json | jq -S . | sha256sum | awk '{print $1}')"
success=false
cleanup_failure() {
  [[ "$success" == true ]] && return
  gcloud compute instances delete "$vm" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" --quiet >/dev/null 2>&1 || true
  gcloud projects remove-iam-policy-binding "$GCP_PROJECT_ID" --member="serviceAccount:$actor1" --role=roles/compute.instanceAdmin.v1 --quiet >/dev/null 2>&1 || true
  gcloud iam service-accounts remove-iam-policy-binding "$workload" --member="serviceAccount:$actor1" --role=roles/iam.serviceAccountUser --project="$GCP_PROJECT_ID" --quiet >/dev/null 2>&1 || true
  gcloud projects remove-iam-policy-binding "$GCP_PROJECT_ID" --member="serviceAccount:$actor2" --role=roles/viewer --quiet >/dev/null 2>&1 || true
  for role in roles/storage.objectViewer roles/storage.objectCreator; do
    gcloud storage buckets remove-iam-policy-binding "gs://$bucket" --member="serviceAccount:$actor2" --role="$role" --quiet >/dev/null 2>&1 || true
    gcloud storage buckets remove-iam-policy-binding "gs://$bucket" --member="serviceAccount:$workload" --role="$role" --quiet >/dev/null 2>&1 || true
  done
}
trap cleanup_failure EXIT

gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" --member="serviceAccount:$actor2" --role=roles/viewer --quiet >/dev/null
gcloud projects describe "$GCP_PROJECT_ID" --impersonate-service-account="$actor2" --format='value(projectId)' >/dev/null
gcloud projects remove-iam-policy-binding "$GCP_PROJECT_ID" --member="serviceAccount:$actor2" --role=roles/viewer --quiet >/dev/null
if gcloud projects describe "$GCP_PROJECT_ID" --impersonate-service-account="$actor2" >/dev/null 2>"$run_dir/actor2-project-denial.log"; then
  harness_die "Viewer 회수 뒤 actor2 프로젝트 조회가 성공했습니다."
fi
rg -qi 'permission|denied|forbidden' "$run_dir/actor2-project-denial.log" || harness_die "actor2 expected-denial 근거가 없습니다."

gcloud storage buckets add-iam-policy-binding "gs://$bucket" --member="serviceAccount:$actor2" --role=roles/storage.objectViewer --quiet >/dev/null
gcloud storage cat "gs://$bucket/sample.txt" --impersonate-service-account="$actor2" >/dev/null
gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" --member="serviceAccount:$actor1" --role=roles/compute.instanceAdmin.v1 --quiet >/dev/null
gcloud iam service-accounts add-iam-policy-binding "$workload" --member="serviceAccount:$actor1" --role=roles/iam.serviceAccountUser --project="$GCP_PROJECT_ID" --quiet >/dev/null
gcloud compute instances create "$vm" --project="$GCP_PROJECT_ID" --zone="$GCP_ZONE" \
  --subnet="p07-subnet-$run_id" --no-address --machine-type=e2-micro --tags=p07-iam-probe \
  --service-account="$workload" --scopes=https://www.googleapis.com/auth/devstorage.read_write \
  --metadata=enable-oslogin=TRUE --image="$debian_image" \
  --impersonate-service-account="$actor1" --quiet >/dev/null

guest() {
  timeout 180 gcloud compute ssh "$vm" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" \
    --tunnel-through-iap --quiet --command="$1"
}
harness_wait_until 300 10 guest 'true' || harness_die "Phase 07 probe VM IAP SSH 준비 실패"
if guest 'gcloud compute instances list >/tmp/compute.out 2>/tmp/compute.err'; then harness_die "workload SA Compute 조회가 성공했습니다."; fi
guest "gcloud storage cat 'gs://$bucket/sample.txt' >/dev/null"
if guest "printf denied > /tmp/upload.txt; gcloud storage cp /tmp/upload.txt 'gs://$bucket/upload.txt'"; then harness_die "viewer workload SA 업로드가 성공했습니다."; fi
gcloud storage buckets remove-iam-policy-binding "gs://$bucket" --member="serviceAccount:$workload" --role=roles/storage.objectViewer --quiet >/dev/null
gcloud storage buckets add-iam-policy-binding "gs://$bucket" --member="serviceAccount:$workload" --role=roles/storage.objectCreator --quiet >/dev/null
harness_wait_until 180 10 guest "printf allowed > /tmp/upload.txt; gcloud storage cp /tmp/upload.txt 'gs://$bucket/upload.txt' >/dev/null" || harness_die "Creator 전이 후 업로드 실패"

final_policy_hash="$(gcloud projects get-iam-policy "$GCP_PROJECT_ID" --format=json | jq -S . | sha256sum | awk '{print $1}')"
jq -n --arg phase 07 --arg run_id "$run_id" --arg baseline "$baseline_hash" --arg final "$final_policy_hash" '{
  phase:$phase,run_id:$run_id,
  tasks:{
    "task-1":{status:"passed",detail:"격리 test principal 2개와 workload identity 생성"},
    "task-2":{status:"passed",detail:"IAM policy/role 구조 조회와 baseline hash 수집"},
    "task-3":{status:"passed",detail:"private bucket fixture와 Viewer baseline 성공"},
    "task-4":{status:"passed",detail:"Project Viewer exact revoke 후 permission denial 확인"},
    "task-5":{status:"passed",detail:"Storage Object Viewer 범위 내 download와 범위 밖 project denial 확인"},
    "task-6":{status:"passed",detail:"actor1의 최소 Compute+actAs로 workload SA 부착 VM 생성"},
    "task-7":{status:"passed",detail:"guest Compute deny·object read 성공·write deny 후 Creator 전이 write 성공"},
    "task-8":{status:"passed",detail:"allow/deny matrix와 exact rollback target 검토"}
  },
  policy_hashes:{before:$baseline,after_actions:$final},risks:[]
}' >"$evidence"
chmod 600 "$evidence" "$run_dir/actor2-project-denial.log"
success=true
printf 'PASS: Phase 07 IAM 권한 전이와 guest permission matrix 검증 완료\n'
