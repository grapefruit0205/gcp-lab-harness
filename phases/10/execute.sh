#!/usr/bin/env bash
set -Eeuo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)";export HARNESS_REPO_ROOT="$repo_root" HARNESS_PHASE=10 HARNESS_PHASE_RESOURCE_LIMIT=2
export HARNESS_PHASE_ALLOWED_TYPES_JSON='["google_bigquery_dataset"]'
phase_preflight(){ export P10_FIXTURE_URI="${P10_FIXTURE_URI:-gs://cloud-training/archinfra/BillingExport-2020-09-18.avro}"; [[ "$P10_FIXTURE_URI" == gs://* ]]||{ printf 'FAIL: GCS fixture URI 필요\n' >&2;return 1;}; }
phase_write_tfvars(){ jq -n --arg project_id "$GCP_PROJECT_ID" --arg run_id "$2" '{project_id:$project_id,run_id:$run_id}' >"$1"; }
phase_write_action_plan(){
  local metadata generation crc
  metadata="$(gcloud storage objects describe "$P10_FIXTURE_URI" --format=json)";generation="$(jq -r .generation<<<"$metadata")";crc="$(jq -r '.crc32c_hash // .crc32c // .metadata.crc32c // empty'<<<"$metadata")"
  [[ "$generation" =~ ^[0-9]+$ && -n "$crc" ]]||{ printf 'FAIL: fixture generation/checksum 조회 실패\n' >&2;return 1;}
  jq -n --arg run_id "$2" --arg uri "$P10_FIXTURE_URI" --arg generation "$generation" --arg crc "$crc" '{schema_version:1,phase:"10",run_id:$run_id,actions:[
    {id:"fixture-load",kind:"bq",target:($uri+"#"+$generation+" crc32c="+$crc),mutation:"AVRO useAvroLogicalTypes=true, WRITE_TRUNCATE into same run sampleinfotable (data/schema reload)",rollback:"preserve dataset/state on failure; destroy only after explicit approval",timeout_seconds:900,contains_secret:false},
    {id:"eight-queries",kind:"bq",target:"phases/10/sql/01..08",mutation:"dry-run plus maximum_bytes_billed guarded queries",rollback:"read-only queries",timeout_seconds:1800,contains_secret:false}
  ]}' >"$1"
}
phase_plan_guard(){ jq -e '([.resource_changes[]|select(.type=="google_bigquery_dataset")]|length)==1' "$1">/dev/null; }
source "$repo_root/lib/harness/safe-adapter.sh"
safe_adapter_main "$@"
