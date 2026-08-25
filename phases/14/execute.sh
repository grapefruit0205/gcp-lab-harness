#!/usr/bin/env bash
set -Eeuo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export HARNESS_REPO_ROOT="$repo_root" HARNESS_PHASE=14 HARNESS_PHASE_RESOURCE_LIMIT=20
export HARNESS_PHASE_ALLOWED_TYPES_JSON='["google_compute_network","google_compute_subnetwork","google_compute_firewall","google_compute_router","google_compute_router_nat","google_compute_region_instance_template","google_compute_instance_group_manager","google_compute_instance","google_compute_region_health_check","google_compute_region_backend_service","google_compute_address","google_compute_forwarding_rule"]'

phase_preflight() {
  P14_ZONE_TWO="$(gcloud compute zones list --project="$GCP_PROJECT_ID" --filter="region:($GCP_REGION) AND status:UP" --format='value(name)' | grep -Fxv "$GCP_ZONE" | sort | head -n1)"
  [[ -n "$P14_ZONE_TWO" ]] || harness_die "$GCP_REGION 안에서 두 번째 사용 가능 zone을 찾지 못했습니다."
}
phase_write_tfvars() {
  jq -n --arg project_id "$GCP_PROJECT_ID" --arg run_id "$2" --arg region "$GCP_REGION" --arg zone_one "$GCP_ZONE" --arg zone_two "$P14_ZONE_TWO" \
    '{project_id:$project_id,run_id:$run_id,region:$region,zone_one:$zone_one,zone_two:$zone_two}' >"$1"
}
phase_write_action_plan() {
  jq -n --arg run_id "$2" '{schema_version:1,phase:"14",run_id:$run_id,actions:[
    {id:"guest-readiness",kind:"guest",target:("utility-vm and two MIG backends "+$run_id),mutation:"bounded curl readiness",rollback:"no retained mutation",timeout_seconds:900,contains_secret:false},
    {id:"direct-backend",kind:"guest",target:("utility-vm-"+$run_id),mutation:"curl each backend internal IP before VIP",rollback:"read-only",timeout_seconds:300,contains_secret:false},
    {id:"vip-distribution",kind:"guest",target:"10.10.30.5:80",mutation:"60 bounded independent HTTP connections",rollback:"read-only",timeout_seconds:300,contains_secret:false},
    {id:"external-boundary",kind:"gcloud",target:("my-ilb-"+$run_id),mutation:"assert INTERNAL scheme and no instance external IP",rollback:"read-only",timeout_seconds:300,contains_secret:false}
  ]}' >"$1"
}
phase_plan_guard() {
  jq -e '
    ([.resource_changes[]|select(.type=="google_compute_region_instance_template")]|length)==2 and
    ([.resource_changes[]|select(.type=="google_compute_instance_group_manager")]|length)==2 and
    ([.resource_changes[]|select(.type=="google_compute_firewall")]|length)==4 and
    ([.resource_changes[]|select(.type=="google_compute_forwarding_rule")]|length)==1 and
    ([.resource_changes[]|select(.type=="google_compute_forwarding_rule")][0].change.after.load_balancing_scheme=="INTERNAL")
  ' "$1" >/dev/null || harness_die "Phase 14 two-template·two-MIG·internal forwarding 계약 불일치"
}
source "$repo_root/lib/harness/phase-adapter.sh"
harness_phase_adapter_main "$@"
