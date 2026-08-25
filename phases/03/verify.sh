#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
phase_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export HARNESS_REPO_ROOT="$repo_root"
source "$repo_root/lib/harness/config.sh"
source "$repo_root/lib/harness/terraform.sh"

mode="offline"
run_id=""
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --offline) mode="offline"; shift ;;
    --run) mode="cloud"; run_id="${2:-}"; shift 2 ;;
    *) printf '사용법: %s [--offline | --run <run_id>]\n' "$0" >&2; exit 2 ;;
  esac
done

if [[ "$mode" == "offline" ]]; then
  bash -n "$phase_dir/execute.sh" "$phase_dir/verify.sh"
  terraform -chdir="$phase_dir/terraform" fmt -check >/dev/null
  terraform -chdir="$phase_dir/terraform" init -backend=false -input=false >/dev/null
  terraform -chdir="$phase_dir/terraform" validate >/dev/null
  for token in "Task 1. 기본(default) 네트워크 살펴보기" "Task 2. auto mode 네트워크 생성하기" "Task 3. custom mode 네트워크 생성하기" "Task 4. 네트워크 간 연결성 살펴보기" "Task 5. Review"; do
    grep -Fq "$token" "$repo_root/docs/phases/phase-03-vpc-networking.md" || harness_die "Phase 03 문서 필수 항목 누락: $token"
  done
  ! grep -Fq 'source_ranges = ["0.0.0.0/0"]' "$phase_dir/terraform/main.tf" || harness_die "Phase 03에 public 전체 ingress가 있습니다."
  printf 'PASS: Phase 03 offline 계약 검증 완료\n'
  exit 0
fi

harness_validate_run_id "$run_id"
"$repo_root/scripts/preflight-gcp.sh" >/dev/null
harness_load_config "$repo_root/config/harness.env"
run_dir="$repo_root/artifacts/runs/$run_id/phase-03"
manifest_file="$run_dir/manifest.json"
evidence_dir="$run_dir/evidence"
evidence_file="$evidence_dir/phase-03-machine.json"
harness_manifest_require_status "$manifest_file" "applied"
mkdir -p "$evidence_dir"
chmod 700 "$evidence_dir"

default_present=false
gcloud compute networks describe default --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && default_present=true
auto_json="$(gcloud compute networks describe "mynetwork-$run_id" --project="$GCP_PROJECT_ID" --format=json)"
management_json="$(gcloud compute networks describe "managementnet-$run_id" --project="$GCP_PROJECT_ID" --format=json)"
private_json="$(gcloud compute networks describe "privatenet-$run_id" --project="$GCP_PROJECT_ID" --format=json)"
jq -e '.autoCreateSubnetworks == true and (.subnetworks | length > 0)' <<<"$auto_json" >/dev/null || harness_die "auto mode VPC 또는 자동 subnet 집합이 없습니다."
jq -e '.autoCreateSubnetworks == false' <<<"$management_json" >/dev/null || harness_die "managementnet이 custom mode가 아닙니다."
jq -e '.autoCreateSubnetworks == false' <<<"$private_json" >/dev/null || harness_die "privatenet이 custom mode가 아닙니다."

management_subnet="$(gcloud compute networks subnets describe "managementsubnet-$run_id" --region="$GCP_REGION" --project="$GCP_PROJECT_ID" --format=json)"
private_subnet="$(gcloud compute networks subnets describe "privatesubnet-$run_id" --region="$GCP_REGION" --project="$GCP_PROJECT_ID" --format=json)"
[[ "$(jq -r '.ipCidrRange' <<<"$management_subnet")" == "10.130.0.0/20" ]] || harness_die "management subnet CIDR 불일치"
[[ "$(jq -r '.ipCidrRange' <<<"$private_subnet")" == "172.16.0.0/24" ]] || harness_die "private subnet CIDR 불일치"

vm_json() { gcloud compute instances describe "$1" --zone="$2" --project="$GCP_PROJECT_ID" --format=json; }
auto_us_json="$(vm_json "mynet-us-vm-$run_id" "$GCP_ZONE")"
auto_eu_json="$(vm_json "mynet-eu-vm-$run_id" "$GCP_SECONDARY_ZONE")"
management_vm_json="$(vm_json "managementnet-vm-$run_id" "$GCP_ZONE")"
private_vm_json="$(vm_json "privatenet-vm-$run_id" "$GCP_ZONE")"
for item in "$auto_us_json" "$auto_eu_json" "$management_vm_json" "$private_vm_json"; do
  jq -e '.status == "RUNNING" and (.networkInterfaces[0].accessConfigs[0].natIP | length > 0)' <<<"$item" >/dev/null || harness_die "Phase 03 VM RUNNING/external IP 계약 불일치"
done

external_hashes='[]'
for item in "$auto_us_json" "$auto_eu_json" "$management_vm_json" "$private_vm_json"; do
  ip="$(jq -r '.networkInterfaces[0].accessConfigs[0].natIP' <<<"$item")"
  ping -c 2 -W 5 "$ip" >/dev/null || harness_die "승인 source에서 external ICMP probe가 실패했습니다."
  external_hashes="$(jq --arg hash "$(printf '%s' "$ip" | sha256sum | awk '{print $1}')" '. + [$hash]' <<<"$external_hashes")"
done

guest() {
  local vm="$1" zone="$2" command="$3"
  timeout 60 gcloud compute ssh "$vm" --zone="$zone" --project="$GCP_PROJECT_ID" --tunnel-through-iap --quiet --command="$command" >/dev/null
}
auto_eu_internal="$(jq -r '.networkInterfaces[0].networkIP' <<<"$auto_eu_json")"
private_internal="$(jq -r '.networkInterfaces[0].networkIP' <<<"$private_vm_json")"
guest "mynet-us-vm-$run_id" "$GCP_ZONE" "ping -c 2 -W 5 '$auto_eu_internal'" || harness_die "auto VPC 내부 지역 간 ICMP가 실패했습니다."
if guest "managementnet-vm-$run_id" "$GCP_ZONE" "ping -c 2 -W 5 '$private_internal'"; then
  harness_die "route/peering 없는 custom VPC 간 internal ICMP가 성공했습니다."
fi

for net in auto management private; do
  fw_json="$(gcloud compute firewall-rules list --project="$GCP_PROJECT_ID" --filter="name~'^${net}-(iap-ssh|client-icmp)-${run_id}$'" --format=json)"
  jq -e 'length == 2 and all(.sourceRanges | all(. != "0.0.0.0/0" and . != "::/0"))' <<<"$fw_json" >/dev/null || harness_die "Phase 03 firewall source 범위가 제한되지 않았습니다."
done

jq -n \
  --arg phase "03" \
  --arg run_id "$run_id" \
  --argjson default_present "$default_present" \
  --argjson external_hashes "$external_hashes" \
  --arg auto_internal_hash "$(printf '%s' "$auto_eu_internal" | sha256sum | awk '{print $1}')" \
  --arg private_internal_hash "$(printf '%s' "$private_internal" | sha256sum | awk '{print $1}')" '
  {
    phase: $phase,
    run_id: $run_id,
    checks: {
      default_vpc_describe_only: "manual-boundary",
      auto_vpc_regions_and_internal_connectivity: "passed",
      auto_to_custom_conversion: "blocked-separate-approved-plan-required",
      custom_vpc_topology: "passed",
      external_connectivity_matrix: "passed",
      cross_vpc_internal_expected_failure: "passed"
    },
    default_vpc_present: $default_present,
    external_ip_sha256: $external_hashes,
    auto_destination_internal_ip_sha256: $auto_internal_hash,
    isolated_destination_internal_ip_sha256: $private_internal_hash
  }' >"$evidence_file"
chmod 600 "$evidence_file"
printf 'PASS: Phase 03 topology와 packet path 검증 완료; destructive/second-plan 경계는 별도 표시됨\n'
