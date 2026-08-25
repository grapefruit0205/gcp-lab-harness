#!/usr/bin/env bash
set -Eeuo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export HARNESS_REPO_ROOT="$repo_root" HARNESS_PHASE=08 HARNESS_PHASE_RESOURCE_LIMIT=2
export HARNESS_PHASE_ALLOWED_TYPES_JSON='["google_storage_bucket"]'
phase_write_tfvars() { jq -n --arg project_id "$GCP_PROJECT_ID" --arg run_id "$2" '{project_id:$project_id,run_id:$run_id}' >"$1"; }
phase_write_action_plan() {
  jq -n --arg run_id "$2" '{schema_version:1,phase:"08",run_id:$run_id,actions:[
    {id:"object-acl",kind:"gcloud",target:("gcp-lab-p08-"+$run_id),mutation:"private ACL then conditional allUsers read test",rollback:"revoke allUsers immediately",timeout_seconds:300,contains_secret:false},
    {id:"csek-rotate",kind:"gcloud",target:("gcp-lab-p08-"+$run_id),mutation:"ephemeral CSEK upload and two-object rotation",rollback:"remove key store configuration and key files",timeout_seconds:600,contains_secret:true},
    {id:"version-restore",kind:"gcloud",target:("gcp-lab-p08-"+$run_id),mutation:"create generations and restore saved generation",rollback:"bucket force destroy",timeout_seconds:300,contains_secret:false},
    {id:"recursive-sync",kind:"gcloud",target:("gcp-lab-p08-"+$run_id),mutation:"recursive local tree sync",rollback:"bucket force destroy",timeout_seconds:300,contains_secret:false}
  ]}' >"$1"
}
phase_plan_guard() {
  jq -e '([.resource_changes[]|select(.type=="google_storage_bucket")]|length)==1 and ([.resource_changes[]|select(.type=="google_storage_bucket")][0].change.after.uniform_bucket_level_access==false)' "$1" >/dev/null
}
phase_after_destroy() { rm -rf "$repo_root/artifacts/runs/$1/phase-08/secrets"; }
source "$repo_root/lib/harness/phase-adapter.sh"
harness_phase_adapter_main "$@"
