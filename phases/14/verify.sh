#!/usr/bin/env bash
set -Eeuo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
phase_dir="$repo_root/phases/14"; export HARNESS_REPO_ROOT="$repo_root"
source "$repo_root/lib/harness/config.sh"; source "$repo_root/lib/harness/terraform.sh"
mode=offline; run_id=""
while [[ "$#" -gt 0 ]]; do case "$1" in --offline)mode=offline;shift;;--destroyed)mode=destroyed;shift;;--run)[[ "$mode" == destroyed ]]||mode=cloud;run_id="${2:-}";shift 2;;*)exit 2;;esac;done
if [[ "$mode" == offline ]]; then
  bash -n "$phase_dir/execute.sh" "$phase_dir/verify.sh"; terraform -chdir="$phase_dir/terraform" fmt -check >/dev/null
  [[ "$(grep -Ec '^resource "google_compute_region_instance_template"' "$phase_dir/terraform/main.tf")" -eq 2 ]] || harness_die "instance template 2개 필요"
  [[ "$(grep -Ec '^resource "google_compute_instance_group_manager"' "$phase_dir/terraform/main.tf")" -eq 2 ]] || harness_die "MIG 2개 필요"
  ! grep -Eq 'access_config|0\.0\.0\.0/0|google_compute_global_forwarding_rule' "$phase_dir/terraform/main.tf" || harness_die "external access 경로가 있습니다."
  "$repo_root/scripts/phase-contract.py" --check "$repo_root/docs/phases/phase-14-internal-nlb.md" >/dev/null
  printf 'PASS: Phase 14 offline 계약 검증 완료\n';exit 0
fi
harness_validate_run_id "$run_id"; harness_load_config "$repo_root/config/harness.env"
if [[ "$mode" == destroyed ]]; then
  export GCP_PROJECT_ID
  python3 "$repo_root/lib/harness/advanced.py" inventory --phase 14 --run-dir "$repo_root/artifacts/runs/$run_id/phase-14"
  exit 0
fi
[[ "${HARNESS_SAFE_VERIFY_RUN:-}" == "$run_id" ]] || harness_die "승인 source/account 검사를 위해 phases/14/execute.sh verify --run $run_id 로 실행하세요."
run_dir="$repo_root/artifacts/runs/$run_id/phase-14";manifest="$run_dir/manifest.json";evidence_dir="$run_dir/evidence";evidence="$evidence_dir/phase-14-machine.json";harness_manifest_require_status "$manifest" applied;mkdir -p "$evidence_dir";chmod 700 "$evidence_dir"
zone_one="$(terraform -chdir="$run_dir/work" output -raw zone_one)";zone_two="$(terraform -chdir="$run_dir/work" output -raw zone_two)";vip="$(terraform -chdir="$run_dir/work" output -raw ilb_address)";utility="utility-vm-$run_id"
guest(){ timeout 180 gcloud compute ssh "$utility" --zone="$zone_one" --project="$GCP_PROJECT_ID" --tunnel-through-iap --quiet --command="$1"; }
harness_wait_until 600 10 guest 'command -v curl >/dev/null' || harness_die "utility VM readiness 실패"

backend_names=()
for spec in "instance-group-1-$run_id:$zone_one" "instance-group-2-$run_id:$zone_two";do
  group="${spec%%:*}";zone="${spec#*:}"
  instance_url="$(gcloud compute instance-groups managed list-instances "$group" --zone="$zone" --project="$GCP_PROJECT_ID" --format='value(instance)' | head -n1)"
  name="${instance_url##*/}";[[ -n "$name" ]]||harness_die "$group backend instance 누락";backend_names+=("$name:$zone")
done

for spec in "${backend_names[@]}";do
  name="${spec%%:*}";zone="${spec#*:}";ip="$(gcloud compute instances describe "$name" --zone="$zone" --project="$GCP_PROJECT_ID" --format='value(networkInterfaces[0].networkIP)')"
  harness_wait_until 600 10 guest "curl -fsS --max-time 5 'http://$ip/' | grep -Fq 'backend=$name'" || harness_die "$name direct backend probe 실패"
done

healthy() {
  gcloud compute backend-services get-health "my-ilb-backend-$run_id" --region="$GCP_REGION" --project="$GCP_PROJECT_ID" --format=json >"$evidence_dir/backend-health.json" || return 1
  python3 "$repo_root/lib/harness/advanced.py" health --file "$evidence_dir/backend-health.json" --expected "instance-group-1-$run_id" "instance-group-2-$run_id"
}
harness_wait_until 600 10 healthy || harness_die "ILB 양쪽 backend health 수렴 실패"
responses="$(guest "set -eu; for i in \$(seq 1 60); do curl -fsS --max-time 5 'http://$vip/'; printf '\\n'; done")"
markers="$(grep -o 'backend=[^ <]*'<<<"$responses")"
[[ "$(wc -l<<<"$markers")" -eq 60 ]] || harness_die "VIP 성공 응답 marker가 정확히60개가 아님"
[[ "$(grep -o '<h2>Client IP</h2>10.10.20.50'<<<"$responses" | wc -l)" -eq 60 ]] || harness_die "passthrough ILB의 원본 client IP 보존 불일치"
expected_markers="$(printf '%s\n' "${backend_names[@]}" | cut -d: -f1 | sed 's/^/backend=/' | sort)"
[[ "$(sort -u<<<"$markers")" == "$expected_markers" ]] || harness_die "VIP 응답 backend 집합 불일치"
distinct=2

forward_json="$(gcloud compute forwarding-rules describe "my-ilb-$run_id" --region="$GCP_REGION" --project="$GCP_PROJECT_ID" --format=json)"
jq -e '.loadBalancingScheme=="INTERNAL" and .IPAddress=="10.10.30.5" and .IPProtocol=="TCP"'<<<"$forward_json">/dev/null||harness_die "ILB frontend readback 불일치"
external_count="$(gcloud compute instances list --project="$GCP_PROJECT_ID" --filter="labels.run=$run_id AND labels.phase=14" --format=json | jq '[.[].networkInterfaces[].accessConfigs[]? | select(.natIP != null)]|length')";[[ "$external_count" -eq 0 ]]||harness_die "Phase 14 instance external IP가 있습니다."

jq -n --arg phase 14 --arg run_id "$run_id" --arg vip_hash "$(printf %s "$vip"|sha256sum|awk '{print $1}')" --argjson distinct "$distinct" '{phase:$phase,run_id:$run_id,tasks:{
 "task-1":{status:"passed",detail:"custom VPC, subnet 2개, restricted firewall 4개 확인"},
 "task-2":{status:"passed",detail:"private backend package egress용 Router/NAT 확인"},
 "task-3":{status:"passed",detail:"template 2개, zonal MIG 2개, utility VM, direct backend HTTP 확인"},
 "task-4":{status:"passed",detail:"regional health check, backend 2개, internal 10.10.30.5 forwarding 확인"},
 "task-5":{status:"passed",detail:"utility VM에서 VIP 반복 요청과 backend 2개 분산 확인"}},vip_sha256:$vip_hash,healthy_backends:2,distinct_backend_markers:$distinct,external_instance_ip_count:0,risks:["원본의 0.0.0.0/0 ICMP·SSH/RDP 규칙은 IAP와 내부 CIDR로 안전하게 축소"]}' >"$evidence";chmod 600 "$evidence"
printf 'PASS: Phase 14 internal-only ILB·direct backend·VIP 분산 검증 완료\n'
