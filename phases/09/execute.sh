#!/usr/bin/env bash
set -Eeuo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"; export HARNESS_REPO_ROOT="$repo_root" HARNESS_PHASE=09 HARNESS_PHASE_RESOURCE_LIMIT=16
export HARNESS_PHASE_ALLOWED_TYPES_JSON='["google_compute_network","google_compute_subnetwork","google_compute_global_address","google_service_networking_connection","google_compute_firewall","google_service_account","google_project_iam_member","google_sql_database_instance","google_sql_database","google_compute_instance"]'
phase_preflight(){
  : "${P09_CLIENT_SOURCE_CIDR:?P09_CLIENT_SOURCE_CIDR 필요}" "${P09_WORDPRESS_URL:?P09_WORDPRESS_URL 필요}" "${P09_WORDPRESS_SHA256:?P09_WORDPRESS_SHA256 필요}" "${P09_PROXY_URL:?P09_PROXY_URL 필요}" "${P09_PROXY_SHA256:?P09_PROXY_SHA256 필요}" "${P09_WP_CLI_URL:?P09_WP_CLI_URL 필요}" "${P09_WP_CLI_SHA256:?P09_WP_CLI_SHA256 필요}"
  [[ "$P09_CLIENT_SOURCE_CIDR" != 0.0.0.0/0 && "$P09_CLIENT_SOURCE_CIDR" != ::/0 ]] || { printf 'FAIL: public 전체 CIDR 금지\n' >&2; return 1; }
  for url in "$P09_WORDPRESS_URL" "$P09_PROXY_URL" "$P09_WP_CLI_URL"; do [[ "$url" == https://* ]] || { printf 'FAIL: HTTPS artifact만 허용\n' >&2; return 1; }; done
  for hash in "$P09_WORDPRESS_SHA256" "$P09_PROXY_SHA256" "$P09_WP_CLI_SHA256"; do [[ "$hash" =~ ^[a-f0-9]{64}$ ]] || { printf 'FAIL: artifact SHA256 오류\n' >&2; return 1; }; done
}
phase_write_tfvars(){ jq -n --arg project_id "$GCP_PROJECT_ID" --arg run_id "$2" --arg region "$GCP_REGION" --arg zone "$GCP_ZONE" --arg cidr "$P09_CLIENT_SOURCE_CIDR" --arg wu "$P09_WORDPRESS_URL" --arg wh "$P09_WORDPRESS_SHA256" --arg pu "$P09_PROXY_URL" --arg ph "$P09_PROXY_SHA256" --arg cu "$P09_WP_CLI_URL" --arg ch "$P09_WP_CLI_SHA256" '{project_id:$project_id,run_id:$run_id,region:$region,zone:$zone,client_source_cidr:$cidr,wordpress_url:$wu,wordpress_sha256:$wh,proxy_url:$pu,proxy_sha256:$ph,wp_cli_url:$cu,wp_cli_sha256:$ch}' >"$1"; }
phase_write_action_plan(){ jq -n --arg run_id "$2" '{schema_version:1,phase:"09",run_id:$run_id,actions:[
  {id:"root-password",kind:"sql",target:("wordpress-db-"+$run_id),mutation:"runtime password via hidden prompt",rollback:"instance destroy",timeout_seconds:600,contains_secret:true},
  {id:"guest-config",kind:"guest",target:("wordpress-proxy/private-"+$run_id),mutation:"secret file transfer, wp-config, core install",rollback:"secure local secret removal and VM destroy",timeout_seconds:900,contains_secret:true},
  {id:"proxy-public-path",kind:"sql",target:("wordpress-proxy-"+$run_id),mutation:"Auth Proxy default public path SQL transaction",rollback:"VM destroy",timeout_seconds:600,contains_secret:false},
  {id:"private-direct-path",kind:"sql",target:("wordpress-private-"+$run_id),mutation:"private IP direct SQL read",rollback:"VM destroy",timeout_seconds:600,contains_secret:false},
  {id:"frontend-http",kind:"http",target:"two restricted WordPress frontends",mutation:"HTTP readiness and shared DB state",rollback:"firewall and VM destroy",timeout_seconds:600,contains_secret:false}
]}' >"$1"; }
phase_plan_guard(){ jq -e '([.resource_changes[]|select(.type=="google_sql_database_instance")]|length)==1 and ([.resource_changes[]|select(.type=="google_compute_instance")]|length)==2 and ([.resource_changes[]|select(.type=="google_compute_firewall")|.change.after.source_ranges[]]|all(.!="0.0.0.0/0" and .!="::/0"))' "$1" >/dev/null; }
phase_after_destroy(){ rm -rf "$repo_root/artifacts/runs/$1/phase-09/secrets"; }
source "$repo_root/lib/harness/phase-adapter.sh"; harness_phase_adapter_main "$@"
