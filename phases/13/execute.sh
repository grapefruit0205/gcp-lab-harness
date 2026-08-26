#!/usr/bin/env bash
set -Eeuo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export HARNESS_REPO_ROOT="$repo_root" HARNESS_PHASE=13 HARNESS_PHASE_RESOURCE_LIMIT=25
export HARNESS_PHASE_ALLOWED_TYPES_JSON='["google_compute_network","google_compute_firewall","google_compute_router","google_compute_router_nat","google_compute_instance","terraform_data","google_compute_image","google_compute_instance_template","google_compute_health_check","google_compute_region_instance_group_manager","google_compute_region_autoscaler","google_compute_backend_service","google_compute_url_map","google_compute_target_http_proxy","google_compute_global_address","google_compute_global_forwarding_rule"]'

phase_preflight() {
  [[ "$GCP_REGION" != "$GCP_SECONDARY_REGION" ]] || harness_die "두 regional MIG에는 서로 다른 region이 필요합니다."
}
phase_write_tfvars() {
  local load_region load_zone zones
  load_region="${P13_LOAD_REGION:-us-west1}"
  [[ "$load_region" != "$GCP_REGION" && "$load_region" != "$GCP_SECONDARY_REGION" ]] || harness_die "P13_LOAD_REGION은 두 backend와 다른 region으로 지정하세요."
  zones="$(gcloud compute zones list --project="$GCP_PROJECT_ID" --format=json)"
  load_zone="$(jq -r --arg region "$load_region" --arg requested "${P13_LOAD_ZONE:-}" '
    [.[]|select(.status=="UP" and (.region|endswith("/"+$region)))|.name]|sort|
    if $requested=="" then .[0]//empty else map(select(.==$requested))|.[0]//empty end' <<<"$zones")"
  [[ -n "$load_zone" ]] || harness_die "부하 region의 활성 zone이 없습니다."
  jq -n --arg project_id "$GCP_PROJECT_ID" --arg run_id "$2" --arg region "$GCP_REGION" --arg zone "$GCP_ZONE" --arg secondary_region "$GCP_SECONDARY_REGION" \
    --arg load_region "$load_region" --arg load_zone "$load_zone" \
    '{project_id:$project_id,run_id:$run_id,region:$region,zone:$zone,secondary_region:$secondary_region,load_region:$load_region,load_zone:$load_zone}' >"$1"
}
phase_write_action_plan() {
  jq -n --arg run_id "$2" '{schema_version:1,phase:"13",run_id:$run_id,actions:[
    {id:"golden-image",kind:"terraform",target:("p13-builder-"+$run_id),mutation:"wait for readiness, reset, verify Apache auto-start on new boot, stop builder, create image",rollback:"preserve failed builder and logs for repair",timeout_seconds:1500,contains_secret:false},
    {id:"builder-preserve",kind:"gcloud",target:("p13-builder-"+$run_id),mutation:"read stopped builder; retain for same-state repair",rollback:"explicit saved destroy plan removes builder",timeout_seconds:300,contains_secret:false},
    {id:"backend-health",kind:"gcloud",target:("p13-http-backend-"+$run_id),mutation:"bounded health polling",rollback:"read-only",timeout_seconds:900,contains_secret:false},
    {id:"lb-log-readback",kind:"gcloud",target:("p13-http-backend-"+$run_id),mutation:"verify logConfig and bounded current-backend log polling",rollback:"read-only",timeout_seconds:600,contains_secret:false},
    {id:"bounded-load",kind:"guest",target:("p13-loadgen-"+$run_id),mutation:"maximum 360-second ApacheBench loop",rollback:"kill exact ab processes",timeout_seconds:420,contains_secret:false},
    {id:"scale-observation",kind:"gcloud",target:"two regional MIGs min=1 max=2",mutation:"observe scale-out and return to baseline",rollback:"autoscaler and MIG destroy",timeout_seconds:1200,contains_secret:false}
  ]}' >"$1"
}
phase_plan_guard() {
  jq -e '
    ([.resource_changes[]|select(.type=="google_compute_region_instance_group_manager")]|length)==2 and
    ([.resource_changes[]|select(.type=="google_compute_region_autoscaler")]|length)==2 and
    ([.resource_changes[]|select(.type=="google_compute_global_forwarding_rule")]|length)==2 and
    ([.resource_changes[]|select(.type=="google_compute_global_address")]|length)==2 and
    all(.resource_changes[]|select(.type=="google_compute_region_autoscaler"); .change.after.autoscaling_policy[0].max_replicas==2)
  ' "$1" >/dev/null || harness_die "Phase 13 dual-region·dual-stack·autoscaling plan 계약 불일치"
}
phase_after_apply() {
  local run_id="$1" run_dir serial apache_version base_image provenance builder_status boot_count
  run_dir="$repo_root/artifacts/runs/$run_id/phase-13"
  serial="$(gcloud compute instances get-serial-port-output "p13-builder-$run_id" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" --port=1 --start=0 2>/dev/null)"
  apache_version="$(grep -o 'HARNESS_APACHE_VERSION=[^[:space:]]*' <<<"$serial" | tail -n1 | cut -d= -f2-)"
  [[ -n "$apache_version" ]] || harness_die "builder Apache package version evidence 누락"
  boot_count="$(sed -n 's/.*HARNESS_IMAGE_READY boot_id=\([a-f0-9-]*\).*/\1/p' <<<"$serial" | sort -u | wc -l)"
  [[ "$boot_count" -ge 2 ]] || harness_die "reset 전후 서로 다른 boot의 Apache 자동 시작 증거 누락"
  builder_status="$(gcloud compute instances describe "p13-builder-$run_id" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" --format='value(status)')"
  [[ "$builder_status" == TERMINATED ]] || harness_die "custom image 생성 시점의 builder 상태가 TERMINATED가 아닙니다: $builder_status"
  base_image="$(terraform -chdir="$run_dir/work" output -raw base_image_self_link)"
  provenance="$run_dir/evidence/image-provenance.json"
  mkdir -p "$run_dir/evidence"; chmod 700 "$run_dir/evidence"
  jq -n --arg base_image_sha256 "$(printf %s "$base_image" | sha256sum | awk '{print $1}')" --arg apache_version "$apache_version" \
    --argjson boot_count "$boot_count" \
    '{base_image_sha256:$base_image_sha256,apache_package_version:$apache_version,builder_ready:true,builder_stopped_before_image:true,reset_autostart_verified:true,distinct_ready_boots:$boot_count}' >"$provenance"
  chmod 600 "$provenance"
  # Terraform 밖 삭제는 다음 repair의 image/builder 의존성을 깨뜨리므로 중지 상태를 보존한다.
}
source "$repo_root/lib/harness/safe-adapter.sh"
safe_adapter_main "$@"
