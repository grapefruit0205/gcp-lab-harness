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
    {id:"php-index-convergence",kind:"guest",target:("exact owned backend VMs of two MIGs "+$run_id),mutation:"identity-check live MIG member; persistent p14-php-index drop-in resets DirectoryIndex to index.php independently of legacy startup; configtest/reload/local hostname HTTP; no VM/template replacement",rollback:"preserve all resources/state and diagnostic log",timeout_seconds:1500,contains_secret:false},
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
    ([.resource_changes[]|select(.type=="google_compute_forwarding_rule")][0].change.after.load_balancing_scheme=="INTERNAL") and
    all(.resource_changes[]|select(.type=="google_compute_region_backend_service");
      (.change.after.backend|length)==2 and all(.change.after.backend[]; .balancing_mode=="CONNECTION"))
  ' "$1" >/dev/null || harness_die "Phase 14 two-template·two-MIG·internal forwarding 계약 불일치"
}
phase_after_apply() {
  local run_id="$1" run_dir zone_one zone_two spec group zone name expected_id actual
  run_dir="$repo_root/artifacts/runs/$run_id/phase-14"
  mkdir -p "$run_dir/evidence"; chmod 700 "$run_dir/evidence"
  zone_one="$(terraform -chdir="$run_dir/work" output -raw zone_one)"
  zone_two="$(terraform -chdir="$run_dir/work" output -raw zone_two)"
  p14_member_ready() {
    gcloud compute instance-groups managed list-instances "$group" --zone="$zone" --project="$GCP_PROJECT_ID" --format=json >"$run_dir/evidence/index-members-$zone.json" || return 1
    jq -e --arg prefix "https://www.googleapis.com/compute/v1/projects/$GCP_PROJECT_ID/zones/$zone/instances/" --arg run "$run_id" '
      length==1 and .[0].instanceStatus=="RUNNING" and (.[0].instance|startswith($prefix)) and (.[0].instance|contains($run)) and (.[0].id|test("^[0-9]+$"))' "$run_dir/evidence/index-members-$zone.json" >/dev/null
  }
  p14_apache_ready() {
    timeout 60 gcloud compute ssh "$name" --zone="$zone" --project="$GCP_PROJECT_ID" --tunnel-through-iap --quiet --command='test -f /var/www/html/index.php && test -f /etc/apache2/conf-available/p14-index.conf && systemctl is-active --quiet apache2'
  }
  for spec in "instance-group-1-$run_id:$zone_one" "instance-group-2-$run_id:$zone_two"; do
    group="${spec%%:*}"; zone="${spec#*:}"
    harness_wait_until 300 10 p14_member_ready || harness_die "PHP 설정 대상 MIG member 준비 실패"
    name="$(jq -r '.[0].instance|split("/")|last' "$run_dir/evidence/index-members-$zone.json")"
    expected_id="$(jq -r '.[0].id' "$run_dir/evidence/index-members-$zone.json")"
    actual="$(gcloud compute instances describe "$name" --zone="$zone" --project="$GCP_PROJECT_ID" --format=json)"
    jq -e --arg run "$run_id" --arg id "$expected_id" '.id==$id and .labels.run==$run and .labels.phase=="14" and .status=="RUNNING"' <<<"$actual" >/dev/null || harness_die "PHP 설정 대상 Cloud ID/소유권 불일치"
    harness_wait_until 600 10 p14_apache_ready || harness_die "PHP/Apache startup 준비 실패"
    timeout 90 gcloud compute ssh "$name" --zone="$zone" --project="$GCP_PROJECT_ID" --tunnel-through-iap --quiet --command='sudo bash -s' <"$run_dir/work/ensure-index.sh"
  done
  jq -n '{owned_backends:2,directory_index:"index.php",persistent_drop_in:"p14-php-index.conf",configuration_test:true,local_hostname_http:true,resources_replaced:0}' >"$run_dir/evidence/index-repair.json"
  chmod 600 "$run_dir/evidence/"*.json
}
source "$repo_root/lib/harness/safe-adapter.sh"
safe_adapter_main "$@"
