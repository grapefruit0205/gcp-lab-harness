#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export HARNESS_REPO_ROOT="$repo_root"
export HARNESS_PHASE=07
export HARNESS_PHASE_RESOURCE_LIMIT=12
export HARNESS_PHASE_ALLOWED_TYPES_JSON='["google_compute_network","google_compute_subnetwork","google_compute_firewall","google_service_account","google_service_account_iam_member","google_storage_bucket","google_storage_bucket_object","google_storage_bucket_iam_member"]'

phase_preflight() {
  local account
  account="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' | head -n1)"
  [[ -n "$account" ]] || { printf 'FAIL: 활성 gcloud 계정이 없습니다.\n' >&2; return 1; }
  if [[ "$account" == *.gserviceaccount.com ]]; then
    export P07_RUNNER_MEMBER="${P07_RUNNER_MEMBER:-serviceAccount:$account}"
  else
    export P07_RUNNER_MEMBER="${P07_RUNNER_MEMBER:-user:$account}"
  fi
  [[ "$P07_RUNNER_MEMBER" != serviceAccountKey:* ]] || { printf 'FAIL: 서비스 계정 키 identity는 허용하지 않습니다.\n' >&2; return 1; }
  P07_DEBIAN_IMAGE="$(gcloud compute images describe-from-family debian-12 --project=debian-cloud --format='value(selfLink)')"
  [[ "$P07_DEBIAN_IMAGE" == https://www.googleapis.com/compute/*/projects/debian-cloud/global/images/* ]] || { printf 'FAIL: immutable Debian image 조회 실패\n' >&2; return 1; }
}

phase_write_tfvars() {
  local path="$1" run_id="$2" account
  account="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' | head -n1)"
  local default_member="user:$account"
  [[ "$account" != *.gserviceaccount.com ]] || default_member="serviceAccount:$account"
  jq -n --arg project_id "$GCP_PROJECT_ID" --arg run_id "$run_id" --arg region "$GCP_REGION" \
    --arg zone "$GCP_ZONE" --arg runner_member "${P07_RUNNER_MEMBER:-$default_member}" \
    '{project_id:$project_id,run_id:$run_id,region:$region,zone:$zone,runner_member:$runner_member}' >"$path"
}

phase_write_action_plan() {
  local path="$1" run_id="$2"
  jq -n --arg run_id "$run_id" --arg image "$P07_DEBIAN_IMAGE" '{
    schema_version: 1, phase: "07", run_id: $run_id,
    actions: [
      {id:"viewer-grant-revoke",kind:"gcloud",target:("p07-b-"+$run_id),mutation:"roles/viewer grant then exact revoke",rollback:"remove exact actor2 roles/viewer tuple",timeout_seconds:300,contains_secret:false},
      {id:"storage-viewer",kind:"gcloud",target:("gcp-lab-p07-"+$run_id),mutation:"actor2 bucket objectViewer grant",rollback:"remove exact bucket member tuple",timeout_seconds:300,contains_secret:false},
      {id:"actas-compute",kind:"gcloud",target:("p07-a-"+$run_id),mutation:"instanceAdmin and workload actAs grant",rollback:"remove exact role tuples",timeout_seconds:300,contains_secret:false},
      {id:"probe-vm",kind:"gcloud",target:("p07-probe-"+$run_id+" image="+$image),mutation:"impersonated VM create with workload identity and immutable image",rollback:"delete exact VM",timeout_seconds:600,contains_secret:false},
      {id:"guest-permission-matrix",kind:"guest",target:("p07-probe-"+$run_id),mutation:"compute deny, object read success, object write deny",rollback:"no guest mutation retained",timeout_seconds:300,contains_secret:false},
      {id:"viewer-to-creator",kind:"gcloud",target:("p07-w-"+$run_id),mutation:"bucket viewer to creator transition",rollback:"restore viewer and remove creator",timeout_seconds:300,contains_secret:false}
    ]
  }' >"$path"
}

phase_plan_guard() {
  jq -e '
    ([.resource_changes[] | select(.type == "google_service_account")] | length) == 3 and
    ([.resource_changes[] | select(.type == "google_storage_bucket")] | length) == 1 and
    ([.resource_changes[] | select(.type == "google_project_iam_policy" or .type == "google_project_iam_binding")] | length) == 0
  ' "$1" >/dev/null || { printf 'FAIL: Phase 07 최소권한 topology 계약 불일치\n' >&2; return 1; }
}

phase_before_destroy() {
  local run_id="$1" actor1 actor2 workload bucket vm
  actor1="p07-a-${run_id:0:19}@$GCP_PROJECT_ID.iam.gserviceaccount.com"
  actor2="p07-b-${run_id:0:19}@$GCP_PROJECT_ID.iam.gserviceaccount.com"
  workload="p07-w-${run_id:0:19}@$GCP_PROJECT_ID.iam.gserviceaccount.com"
  bucket="gcp-lab-p07-$run_id"; vm="p07-probe-$run_id"
  gcloud compute instances delete "$vm" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" --quiet >/dev/null 2>&1 || true
  gcloud projects remove-iam-policy-binding "$GCP_PROJECT_ID" --member="serviceAccount:$actor1" --role=roles/compute.instanceAdmin.v1 --quiet >/dev/null 2>&1 || true
  gcloud iam service-accounts remove-iam-policy-binding "$workload" --member="serviceAccount:$actor1" --role=roles/iam.serviceAccountUser --project="$GCP_PROJECT_ID" --quiet >/dev/null 2>&1 || true
  gcloud projects remove-iam-policy-binding "$GCP_PROJECT_ID" --member="serviceAccount:$actor2" --role=roles/viewer --quiet >/dev/null 2>&1 || true
  for role in roles/storage.objectViewer roles/storage.objectCreator; do
    gcloud storage buckets remove-iam-policy-binding "gs://$bucket" --member="serviceAccount:$actor2" --role="$role" --quiet >/dev/null 2>&1 || true
    gcloud storage buckets remove-iam-policy-binding "gs://$bucket" --member="serviceAccount:$workload" --role="$role" --quiet >/dev/null 2>&1 || true
  done
}

source "$repo_root/lib/harness/phase-adapter.sh"
harness_phase_adapter_main "$@"
