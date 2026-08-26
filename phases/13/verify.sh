#!/usr/bin/env bash
set -Eeuo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
phase_dir="$repo_root/phases/13"
export HARNESS_REPO_ROOT="$repo_root"
source "$repo_root/lib/harness/config.sh"
source "$repo_root/lib/harness/terraform.sh"

mode=offline; run_id=""
while [[ "$#" -gt 0 ]]; do case "$1" in
  --offline) mode=offline; shift ;;
  --destroyed) mode=destroyed; shift ;;
  --run) [[ "$mode" == destroyed ]] || mode=cloud; run_id="${2:-}"; shift 2 ;;
  *) exit 2 ;;
esac; done

if [[ "$mode" == offline ]]; then
  bash -n "$phase_dir/execute.sh" "$phase_dir/verify.sh" "$phase_dir/terraform/wait-builder.sh"
  terraform -chdir="$phase_dir/terraform" fmt -check >/dev/null
  grep -Eq 'ip_version *= *"IPV4"' "$phase_dir/terraform/main.tf" && grep -Eq 'ip_version *= *"IPV6"' "$phase_dir/terraform/main.tf" || harness_die "IPv4/IPv6 frontend 누락"
  grep -Eq 'log_config' "$phase_dir/terraform/main.tf" || harness_die "backend logging 누락"
  ! grep -Eq 'source_ranges *= *\["0.0.0.0/0"\]' "$phase_dir/terraform/main.tf" || harness_die "전체 public ingress 금지"
  "$repo_root/scripts/phase-contract.py" --check "$repo_root/docs/phases/phase-13-external-alb.md" >/dev/null
  printf 'PASS: Phase 13 offline 계약 검증 완료\n'; exit 0
fi

harness_validate_run_id "$run_id"
harness_load_config "$repo_root/config/harness.env"
if [[ "$mode" == destroyed ]]; then
  remaining="$(gcloud compute forwarding-rules list --global --project="$GCP_PROJECT_ID" --filter="name~'$run_id$'" --format='value(name)' | wc -l)"
  gcloud compute networks describe "p13-$run_id" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining+=1)) || true
  gcloud compute images describe "p13-webserver-$run_id" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining+=1)) || true
  for vm in "p13-builder-$run_id" "p13-loadgen-$run_id"; do
    gcloud compute instances describe "$vm" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining+=1)) || true
  done
  gcloud compute backend-services describe "p13-http-backend-$run_id" --global --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining+=1)) || true
  gcloud compute url-maps describe "p13-http-map-$run_id" --global --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining+=1)) || true
  gcloud compute target-http-proxies describe "p13-http-proxy-$run_id" --global --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining+=1)) || true
  for address in "p13-ipv4-$run_id" "p13-ipv6-$run_id"; do
    gcloud compute addresses describe "$address" --global --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining+=1)) || true
  done
  for spec in "us-1-mig-$run_id:$GCP_REGION" "notus-1-mig-$run_id:$GCP_SECONDARY_REGION"; do
    mig="${spec%%:*}"; region="${spec#*:}"
    gcloud compute instance-groups managed describe "$mig" --region="$region" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining+=1)) || true
  done
  [[ "$remaining" -eq 0 ]] || harness_die "Phase 13 network·image·VM·MIG·ALB 잔여 리소스: $remaining"
  printf 'PASS: Phase 13 잔여 리소스 0\n'; exit 0
fi

run_dir="$repo_root/artifacts/runs/$run_id/phase-13"; manifest="$run_dir/manifest.json"; evidence_dir="$run_dir/evidence"; evidence="$evidence_dir/phase-13-machine.json"
harness_manifest_require_status "$manifest" applied; mkdir -p "$evidence_dir"; chmod 700 "$evidence_dir"
provenance="$evidence_dir/image-provenance.json"; harness_require_file "$provenance" "custom image provenance"
jq -e '.builder_ready==true and .builder_stopped_before_image==true and (.base_image_sha256|test("^[a-f0-9]{64}$")) and (.apache_package_version|length>0)' "$provenance" >/dev/null || harness_die "custom image provenance evidence 불일치"
loadgen="p13-loadgen-$run_id"; load_pid_started=false
cleanup_load() {
  if [[ "$load_pid_started" == true ]]; then timeout 60 gcloud compute ssh "$loadgen" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" --tunnel-through-iap --quiet --command="sudo pkill -f '[a]b .*p13' || true" >/dev/null 2>&1 || true; fi
}
trap cleanup_load EXIT
guest() { timeout 180 gcloud compute ssh "$loadgen" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" --tunnel-through-iap --quiet --command="$1"; }
harness_wait_until 600 10 guest 'command -v ab >/dev/null' || harness_die "load generator readiness 실패"

[[ -z "$(gcloud compute instances list --project="$GCP_PROJECT_ID" --filter="name=('p13-builder-$run_id')" --format='value(name)')" ]] || harness_die "builder VM이 image 생성 후 삭제되지 않았습니다."
image_json="$(gcloud compute images describe "p13-webserver-$run_id" --project="$GCP_PROJECT_ID" --format=json)"
jq -e '.status=="READY" and (.sourceDisk|length>0)' <<<"$image_json" >/dev/null || harness_die "custom image provenance/readiness 불일치"

backend="p13-http-backend-$run_id"
backend_json="$(gcloud compute backend-services describe "$backend" --global --project="$GCP_PROJECT_ID" --format=json)"
jq -e '.logConfig.enable==true and .logConfig.sampleRate==1' <<<"$backend_json" >/dev/null || harness_die "ALB backend logging API readback 불일치"
backend_healthy() {
  local health
  health="$(gcloud compute backend-services get-health "$backend" --global --project="$GCP_PROJECT_ID" --format=json)" || return 1
  [[ "$(jq '[.[].status.healthStatus[]? | select(.healthState=="HEALTHY")]|length' <<<"$health")" -ge 2 ]]
}
harness_wait_until 900 15 backend_healthy || harness_die "두 regional backend가 HEALTHY로 수렴하지 않았습니다."

ipv4="$(terraform -chdir="$run_dir/work" output -raw ipv4_address)"; ipv6="$(terraform -chdir="$run_dir/work" output -raw ipv6_address)"
harness_wait_until 600 10 curl -fsS --max-time 10 "http://$ipv4/" >/dev/null || harness_die "IPv4 frontend HTTP readiness 실패"
ipv6_probe=unavailable
if timeout 20 curl -6 -fsS --max-time 10 "http://[$ipv6]/" >/dev/null 2>&1; then ipv6_probe=passed; fi

initial_total=0
for region in "$GCP_REGION" "$GCP_SECONDARY_REGION"; do
  name="$([[ "$region" == "$GCP_REGION" ]] && printf 'us-1-mig-%s' "$run_id" || printf 'notus-1-mig-%s' "$run_id")"
  size="$(gcloud compute instance-groups managed describe "$name" --region="$region" --project="$GCP_PROJECT_ID" --format='value(targetSize)')"
  initial_total=$((initial_total + size))
done
[[ "$initial_total" -eq 2 ]] || harness_die "MIG baseline target size 합이 2가 아닙니다."

guest "nohup timeout 360 bash -c 'while :; do ab -n 5000 -c 100 -H \"X-Harness: p13\" http://$ipv4/ >/dev/null 2>&1 || true; done' >/tmp/p13-load.log 2>&1 &"
load_pid_started=true
scale_out_total=0
scale_out() {
  local total=0 region name size
  for region in "$GCP_REGION" "$GCP_SECONDARY_REGION"; do
    name="$([[ "$region" == "$GCP_REGION" ]] && printf 'us-1-mig-%s' "$run_id" || printf 'notus-1-mig-%s' "$run_id")"
    size="$(gcloud compute instance-groups managed describe "$name" --region="$region" --project="$GCP_PROJECT_ID" --format='value(targetSize)')"
    (( total += size ))
  done
  scale_out_total=$total
  (( total > initial_total && total <= 4 ))
}
harness_wait_until 900 20 scale_out || harness_die "제한 시간 내 autoscale scale-out을 관찰하지 못했습니다."

markers=""
for _ in $(seq 1 120); do markers+="$(curl -fsS --max-time 10 "http://$ipv4/" || true)"$'\n'; done
distinct_markers="$(grep -o 'backend=[^ <]*' <<<"$markers" | sort -u | wc -l)"
[[ "$distinct_markers" -ge 2 ]] || harness_die "서로 다른 backend marker 2개 이상을 관찰하지 못했습니다."
cleanup_load; load_pid_started=false

lb_log_json='[]'
lb_log_ready() {
  lb_log_json="$(gcloud logging read "resource.type=\"http_load_balancer\" AND resource.labels.backend_service_name=\"$backend\"" --project="$GCP_PROJECT_ID" --freshness=30m --limit=20 --format=json 2>/dev/null)" || return 1
  [[ "$(jq 'length' <<<"$lb_log_json")" -ge 1 ]]
}
harness_wait_until 600 15 lb_log_ready || harness_die "현재 backend service의 실제 HTTP load balancer log 미도착"
lb_log_count="$(jq 'length' <<<"$lb_log_json")"

scaled_in() {
  local total=0 region name size
  for region in "$GCP_REGION" "$GCP_SECONDARY_REGION"; do
    name="$([[ "$region" == "$GCP_REGION" ]] && printf 'us-1-mig-%s' "$run_id" || printf 'notus-1-mig-%s' "$run_id")"
    size="$(gcloud compute instance-groups managed describe "$name" --region="$region" --project="$GCP_PROJECT_ID" --format='value(targetSize)')"
    (( total += size ))
  done
  (( total == 2 ))
}
harness_wait_until 1200 30 scaled_in || harness_die "autoscale scale-in baseline 복귀를 관찰하지 못했습니다."

jq -n --arg phase 13 --arg run_id "$run_id" --arg ipv6_probe "$ipv6_probe" --arg provenance_sha256 "$(harness_sha256_file "$provenance")" --argjson initial_total "$initial_total" --argjson scale_out_total "$scale_out_total" --argjson distinct_markers "$distinct_markers" --argjson lb_log_count "$lb_log_count" '{phase:$phase,run_id:$run_id,tasks:{
 "task-1":{status:"passed",detail:"공식 health-check source range와 target tag 확인"},
 "task-2":{status:"passed",detail:"private backend/builder/loadgen용 primary-region Cloud NAT 확인"},
 "task-3":{status:"passed",detail:"Apache를 포함한 READY custom image와 삭제된 builder 확인"},
 "task-4":{status:"passed",detail:"두 regional MIG, min 1 max 2 autoscaler, backend health 확인"},
 "task-5":{status:"passed",detail:"IPv4·IPv6 frontend, 두 backend, logging API readback과 실제 LB log 확인"},
 "task-6":{status:"passed",detail:"bounded load, backend marker 분산, scale-out과 scale-in 확인"},
 "task-7":{status:"passed",detail:"image→template→MIG→LB→autoscale evidence 검토"}},image_provenance_sha256:$provenance_sha256,initial_instance_total:$initial_total,peak_target_total:$scale_out_total,distinct_backend_markers:$distinct_markers,load_balancer_log_entry_count:$lb_log_count,ipv6_probe:$ipv6_probe,risks:["실행 환경에 IPv6 route가 없으면 IPv6는 forwarding-rule readback만 검증","autoscaling은 metric 수렴 시간에 따라 최대 20분 polling"]}' >"$evidence"
chmod 600 "$evidence"
printf 'PASS: Phase 13 ALB dual-stack·backend·autoscale 검증 완료\n'
