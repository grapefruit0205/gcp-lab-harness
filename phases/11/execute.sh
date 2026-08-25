#!/usr/bin/env bash
set -Eeuo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.."&&pwd)";export HARNESS_REPO_ROOT="$repo_root" HARNESS_PHASE=11 HARNESS_PHASE_RESOURCE_LIMIT=15
export HARNESS_PHASE_ALLOWED_TYPES_JSON='["google_compute_network","google_compute_subnetwork","google_compute_firewall","google_service_account","google_compute_instance","google_monitoring_dashboard","google_monitoring_alert_policy","google_monitoring_group","google_monitoring_uptime_check_config"]'
phase_preflight(){ "$repo_root/scripts/setup-gcp-mcp.sh" check >/dev/null; }
phase_write_tfvars(){ jq -n --arg project_id "$GCP_PROJECT_ID" --arg run_id "$2" --arg region "$GCP_REGION" --arg zone "$GCP_ZONE" '{project_id:$project_id,run_id:$run_id,region:$region,zone:$zone}' >"$1"; }
phase_write_action_plan(){ jq -n --arg run_id "$2" '{schema_version:1,phase:"11",run_id:$run_id,actions:[
 {id:"metric-traffic",kind:"guest",target:("nginxstack-1..3-"+$run_id),mutation:"bounded CPU and HTTP traffic",rollback:"timeout terminates traffic",timeout_seconds:300,contains_secret:false},
 {id:"metric-poll",kind:"gcloud",target:"Monitoring timeSeries",mutation:"read-only bounded polling",rollback:"none",timeout_seconds:600,contains_secret:false},
 {id:"disable-alert",kind:"gcloud",target:("Phase 11 CPU "+$run_id),mutation:"enabled true to false PATCH",rollback:"policy destroyed after approval",timeout_seconds:300,contains_secret:false}
]}' >"$1"; }
phase_plan_guard(){ jq -e '([.resource_changes[]|select(.type=="google_compute_instance")]|length)==3 and ([.resource_changes[]|select(.type=="google_monitoring_alert_policy")][0].change.after.combiner=="AND")' "$1">/dev/null; }
source "$repo_root/lib/harness/phase-adapter.sh";harness_phase_adapter_main "$@"
