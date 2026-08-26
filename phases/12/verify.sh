#!/usr/bin/env bash
set -Eeuo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
phase_dir="$repo_root/phases/12"
export HARNESS_REPO_ROOT="$repo_root"
source "$repo_root/lib/harness/config.sh"
source "$repo_root/lib/harness/terraform.sh"

mode=offline
run_id=""
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --offline) mode=offline; shift ;;
    --destroyed) mode=destroyed; shift ;;
    --run) [[ "$mode" == destroyed ]] || mode=cloud; run_id="${2:-}"; shift 2 ;;
    *) exit 2 ;;
  esac
done

if [[ "$mode" == offline ]]; then
  bash -n "$phase_dir/execute.sh" "$phase_dir/verify.sh"
  terraform -chdir="$phase_dir/terraform" fmt -check >/dev/null
  [[ "$(grep -Ec '^resource "google_compute_vpn_tunnel"' "$phase_dir/terraform/main.tf")" -eq 2 ]] || harness_die "양쪽 tunnel resource block이 필요합니다."
  grep -Eq 'routing_mode *= *"GLOBAL"' "$phase_dir/terraform/main.tf" || harness_die "global routing 누락"
  ! grep -Eq 'shared_secret *= *"' "$phase_dir/terraform/main.tf" || harness_die "고정 PSK를 허용하지 않습니다."
  "$repo_root/scripts/phase-contract.py" --check "$repo_root/docs/phases/phase-12-ha-vpn.md" >/dev/null
  printf 'PASS: Phase 12 offline 계약 검증 완료\n'
  exit 0
fi

harness_validate_run_id "$run_id"
harness_load_config "$repo_root/config/harness.env"
prefix_vpc="vpc-demo-$run_id"
prefix_onprem="on-prem-$run_id"
if [[ "$mode" == destroyed ]]; then
  remaining="$(gcloud compute vpn-tunnels list --project="$GCP_PROJECT_ID" --filter="name~'$run_id$'" --format='value(name)' | wc -l)"
  for network in "$prefix_vpc" "$prefix_onprem"; do
    gcloud compute networks describe "$network" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining+=1)) || true
  done
  for spec in "vpc-demo-instance1-$run_id:$GCP_ZONE" "vpc-demo-instance2-$run_id:$GCP_SECONDARY_ZONE" "on-prem-instance1-$run_id:$GCP_ZONE"; do
    vm="${spec%%:*}"; zone="${spec#*:}"
    gcloud compute instances describe "$vm" --zone="$zone" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining+=1)) || true
  done
  [[ "$remaining" -eq 0 ]] || harness_die "Phase 12 network·VM·VPN 잔여 리소스: $remaining"
  printf 'PASS: Phase 12 잔여 리소스 0\n'
  exit 0
fi

run_dir="$repo_root/artifacts/runs/$run_id/phase-12"
manifest="$run_dir/manifest.json"
evidence_dir="$run_dir/evidence"
evidence="$evidence_dir/phase-12-machine.json"
harness_manifest_require_status "$manifest" applied
mkdir -p "$evidence_dir"
chmod 700 "$evidence_dir"

cleanup_failure() {
  local rc=$?
  trap - ERR
  harness_manifest_set_status "$manifest" cleanup_required || true
  if [[ "${GCP_CLEANUP_ON_FAILURE:-}" == true ]]; then harness_tf_destroy "$run_dir/work" || true; fi
  exit "$rc"
}
trap cleanup_failure ERR

tunnels=("vpc-demo-tunnel0-$run_id" "vpc-demo-tunnel1-$run_id" "on-prem-tunnel0-$run_id" "on-prem-tunnel1-$run_id")
tunnel_up() {
  local name
  for name in "${tunnels[@]}"; do
    [[ "$(gcloud compute vpn-tunnels describe "$name" --region="$GCP_REGION" --project="$GCP_PROJECT_ID" --format='value(status)')" == ESTABLISHED ]] || return 1
  done
}
harness_wait_until 900 15 tunnel_up || harness_die "VPN tunnel 4개가 모두 ESTABLISHED로 수렴하지 않았습니다."

vpc_status="$(gcloud compute routers get-status "vpc-demo-router1-$run_id" --region="$GCP_REGION" --project="$GCP_PROJECT_ID" --format=json)"
onprem_status="$(gcloud compute routers get-status "on-prem-router1-$run_id" --region="$GCP_REGION" --project="$GCP_PROJECT_ID" --format=json)"
for status_json in "$vpc_status" "$onprem_status"; do
  [[ "$(jq '[.result.bgpPeerStatus[]? | select(.status=="UP")]|length' <<<"$status_json")" -eq 2 ]] || harness_die "Router BGP peer 2개가 UP이 아닙니다."
  [[ "$(jq '[.result.bgpPeerStatus[]? | (.numLearnedRoutes // 0)] | add // 0' <<<"$status_json")" -ge 1 ]] || harness_die "Router learned route가 없습니다."
done

vpc1_ip="$(terraform -chdir="$run_dir/work" output -raw vpc_primary_ip)"
vpc2_ip="$(terraform -chdir="$run_dir/work" output -raw vpc_secondary_ip)"
onprem_ip="$(terraform -chdir="$run_dir/work" output -raw onprem_ip)"
guest() { timeout 180 gcloud compute ssh "$1" --zone="$2" --project="$GCP_PROJECT_ID" --tunnel-through-iap --quiet --command="$3"; }
guest "on-prem-instance1-$run_id" "$GCP_ZONE" "ping -c 3 -W 3 '$vpc1_ip' >/dev/null"
guest "on-prem-instance1-$run_id" "$GCP_ZONE" "ping -c 3 -W 3 '$vpc2_ip' >/dev/null"
guest "vpc-demo-instance1-$run_id" "$GCP_ZONE" "ping -c 3 -W 3 '$onprem_ip' >/dev/null"
[[ "$(gcloud compute networks describe "$prefix_vpc" --project="$GCP_PROJECT_ID" --format='value(routingConfig.routingMode)')" == GLOBAL ]] || harness_die "vpc-demo routing mode가 GLOBAL이 아닙니다."

gcloud compute vpn-tunnels delete "vpc-demo-tunnel0-$run_id" --region="$GCP_REGION" --project="$GCP_PROJECT_ID" --quiet >/dev/null
survivor_up() {
  [[ "$(gcloud compute vpn-tunnels describe "vpc-demo-tunnel1-$run_id" --region="$GCP_REGION" --project="$GCP_PROJECT_ID" --format='value(status)')" == ESTABLISHED ]] &&
    [[ "$(gcloud compute vpn-tunnels describe "on-prem-tunnel1-$run_id" --region="$GCP_REGION" --project="$GCP_PROJECT_ID" --format='value(status)')" == ESTABLISHED ]]
}
harness_wait_until 300 10 survivor_up || harness_die "surviving tunnel pair가 ESTABLISHED가 아닙니다."
harness_wait_until 300 10 guest "on-prem-instance1-$run_id" "$GCP_ZONE" "ping -c 2 -W 3 '$vpc1_ip' >/dev/null" || harness_die "단일 tunnel 장애 후 private ping 실패"

jq -n --arg phase 12 --arg run_id "$run_id" --argjson initial_tunnels 4 --argjson established_peers 4 '{phase:$phase,run_id:$run_id,tasks:{
  "task-1":{status:"passed",detail:"global VPC, 두 regional subnet, VM 2개 확인"},
  "task-2":{status:"passed",detail:"simulated on-prem VPC, subnet, VM 확인"},
  "task-3":{status:"passed",detail:"HA VPN gateway 2개와 Cloud Router 2개 확인"},
  "task-4":{status:"passed",detail:"interface 0/1 양방향 VPN tunnel 4개 baseline ESTABLISHED"},
  "task-5":{status:"passed",detail:"router interface 4개와 BGP peer 4개 UP"},
  "task-6":{status:"passed",detail:"learned route, 양방향·교차 region private connectivity, GLOBAL routing 확인"},
  "task-7":{status:"passed",detail:"tunnel0 한쪽 삭제 후 surviving tunnel1으로 연결 유지"},
  "task-8":{status:"passed",detail:"Terraform 소유권 기반 필수 cleanup 경로 준비"},
  "task-9":{status:"passed",detail:"topology·redundancy·routing·connectivity evidence 검토"}},initial_tunnel_count:$initial_tunnels,established_peer_count:$established_peers,failover_probe:true,risks:["원본 failover 절차에 따라 vpc tunnel0은 검증 중 삭제되며 Extension은 baseline evidence와 현재 degraded topology를 함께 검토","PSK는 ignored Terraform state에만 존재"]}' >"$evidence"
chmod 600 "$evidence"
trap - ERR
printf 'PASS: Phase 12 HA VPN 이중화·routing·failover 검증 완료\n'
