#!/usr/bin/env bash
set -Eeuo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export HARNESS_REPO_ROOT="$repo_root" HARNESS_PHASE=12 HARNESS_PHASE_RESOURCE_LIMIT=28
export HARNESS_PHASE_ALLOWED_TYPES_JSON='["google_compute_network","google_compute_subnetwork","google_compute_firewall","google_compute_instance","google_compute_ha_vpn_gateway","google_compute_router","google_compute_vpn_tunnel","google_compute_router_interface","google_compute_router_peer"]'

phase_preflight() {
  [[ "$GCP_REGION" != "$GCP_SECONDARY_REGION" ]] || harness_die "HA VPN global routing 검증에는 서로 다른 두 region이 필요합니다."
  [[ "$GCP_ZONE" == "$GCP_REGION"-* && "$GCP_SECONDARY_ZONE" == "$GCP_SECONDARY_REGION"-* ]] || harness_die "zone과 region 조합이 일치하지 않습니다."
}

phase_write_tfvars() {
  local vpn_psk
  vpn_psk="$(openssl rand -base64 48 | tr -d '\n')"
  printf %s "$vpn_psk" | jq -Rs --arg project_id "$GCP_PROJECT_ID" --arg run_id "$2" --arg region "$GCP_REGION" --arg zone "$GCP_ZONE" \
    --arg secondary_region "$GCP_SECONDARY_REGION" --arg secondary_zone "$GCP_SECONDARY_ZONE" \
    '{project_id:$project_id,run_id:$run_id,region:$region,zone:$zone,secondary_region:$secondary_region,secondary_zone:$secondary_zone,vpn_psk:.}' >"$1"
}

phase_write_action_plan() {
  jq -n --arg run_id "$2" '{schema_version:1,phase:"12",run_id:$run_id,actions:[
    {id:"psk-runtime",kind:"terraform",target:"0600 tfvars and ignored run state",mutation:"generate runtime-only 48-byte PSK and redact plan JSON",rollback:"tfvars removed after destroy",timeout_seconds:300,contains_secret:true},
    {id:"routing-convergence",kind:"gcloud",target:("two routers and four tunnels "+$run_id),mutation:"bounded status polling",rollback:"read-only",timeout_seconds:900,contains_secret:false},
    {id:"connectivity-matrix",kind:"guest",target:"on-prem and two vpc-demo VMs",mutation:"bidirectional and cross-region private ICMP probes",rollback:"no retained mutation",timeout_seconds:300,contains_secret:false},
    {id:"routing-transition",kind:"gcloud",target:("vpc-demo-"+$run_id),mutation:"GLOBAL baseline to REGIONAL negative cross-region probe then GLOBAL success",rollback:"same state replan restores GLOBAL on failure",timeout_seconds:1200,contains_secret:false},
    {id:"single-path-failure",kind:"gcloud",target:("vpc-demo-tunnel0-"+$run_id),mutation:"delete exact Terraform-owned tunnel after baseline evidence",rollback:"remaining topology destroyed after review",timeout_seconds:300,contains_secret:false},
    {id:"failover-probe",kind:"guest",target:("on-prem-instance1-"+$run_id),mutation:"bounded ping through surviving tunnel",rollback:"no retained mutation",timeout_seconds:300,contains_secret:false}
  ]}' >"$1"
}

phase_plan_guard() {
  jq -e '
    ([.resource_changes[] | select(.type=="google_compute_ha_vpn_gateway")]|length)==2 and
    ([.resource_changes[] | select(.type=="google_compute_router")]|length)==2 and
    ([.resource_changes[] | select(.type=="google_compute_vpn_tunnel")]|length)==4 and
    ([.resource_changes[] | select(.type=="google_compute_router_interface")]|length)==4 and
    ([.resource_changes[] | select(.type=="google_compute_router_peer")]|length)==4 and
    ([.resource_changes[] | select(.type=="google_compute_instance")]|length)==3 and
    all(.resource_changes[] | select(.type=="google_compute_vpn_tunnel"); .change.after_sensitive.shared_secret==true)
  ' "$1" >/dev/null || harness_die "Phase 12 topology 또는 PSK sensitive 계약 불일치"
  ! jq -e '.. | strings | select(length >= 40 and test("^[A-Za-z0-9]+$"))' "$1" >/dev/null || harness_die "plan JSON에 PSK로 의심되는 문자열이 있습니다."
}

phase_after_destroy() {
  rm -f "$repo_root/artifacts/runs/$1/phase-12/work/phase-12.auto.tfvars.json"
}

source "$repo_root/lib/harness/safe-adapter.sh"
safe_adapter_main "$@"
