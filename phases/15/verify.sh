#!/usr/bin/env bash
set -Eeuo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)";phase_dir="$repo_root/phases/15";export HARNESS_REPO_ROOT="$repo_root"
source "$repo_root/lib/harness/config.sh";source "$repo_root/lib/harness/terraform.sh"
mode=offline;run_id="";while [[ "$#" -gt 0 ]];do case "$1" in --offline)mode=offline;shift;;--destroyed)mode=destroyed;shift;;--run)[[ "$mode" == destroyed ]]||mode=cloud;run_id="${2:-}";shift 2;;*)exit 2;;esac;done
if [[ "$mode" == offline ]];then
  bash -n "$phase_dir/execute.sh" "$phase_dir/verify.sh";terraform -chdir="$phase_dir/terraform" fmt -check >/dev/null
  [[ -f "$phase_dir/terraform/.terraform.lock.hcl" ]]||harness_die "provider lockfile 누락"
  grep -Eq 'source *= *"\./modules/instance"' "$phase_dir/terraform/main.tf"||harness_die "local reusable module 누락"
  ! grep -Eq 'source *= *("git|"https|"registry)|access_config|0\.0\.0\.0/0' "$phase_dir/terraform/main.tf" "$phase_dir/terraform/modules/instance/main.tf"||harness_die "원격 module·external IP·전체 ingress 금지"
  "$repo_root/scripts/phase-contract.py" --check "$repo_root/docs/phases/phase-15-terraform.md">/dev/null
  printf 'PASS: Phase 15 offline 계약 검증 완료\n';exit 0
fi
harness_validate_run_id "$run_id";harness_load_config "$repo_root/config/harness.env"
if [[ "$mode" == destroyed ]];then
  remaining="$(gcloud compute networks list --project="$GCP_PROJECT_ID" --filter="name=('mynetwork-$run_id')" --format='value(name)'|wc -l)"
  for spec in "mynet-vm-1-$run_id:$GCP_ZONE" "mynet-vm-2-$run_id:$GCP_SECONDARY_ZONE";do vm="${spec%%:*}";zone="${spec#*:}";gcloud compute instances describe "$vm" --zone="$zone" --project="$GCP_PROJECT_ID" >/dev/null 2>&1&&((remaining+=1))||true;done
  gcloud compute firewall-rules describe "mynetwork-allow-http-ssh-rdp-icmp-$run_id" --project="$GCP_PROJECT_ID" >/dev/null 2>&1&&((remaining+=1))||true
  [[ "$remaining" -eq 0 ]]||harness_die "Phase 15 network·VM·firewall 잔여: $remaining";printf 'PASS: Phase 15 Cloud inventory 잔여 0\n';exit 0
fi
run_dir="$repo_root/artifacts/runs/$run_id/phase-15";work_dir="$run_dir/work";manifest="$run_dir/manifest.json";evidence_dir="$run_dir/evidence";evidence="$evidence_dir/phase-15-machine.json";harness_manifest_require_status "$manifest" applied;mkdir -p "$evidence_dir";chmod 700 "$evidence_dir"
terraform -chdir="$work_dir" fmt -check -recursive >/dev/null;terraform -chdir="$work_dir" validate >/dev/null
addresses="$(terraform -chdir="$work_dir" state list)";[[ "$(wc -l<<<"$addresses")" -eq 4 ]]||harness_die "Terraform state address가 4개가 아닙니다."
for address in google_compute_network.mynetwork google_compute_firewall.mynetwork_lab module.mynet_vm_1.google_compute_instance.vm module.mynet_vm_2.google_compute_instance.vm;do grep -Fxq "$address"<<<"$addresses"||harness_die "state address 누락: $address";done
network_json="$(gcloud compute networks describe "mynetwork-$run_id" --project="$GCP_PROJECT_ID" --format=json)";jq -e '.autoCreateSubnetworks==true'<<<"$network_json">/dev/null||harness_die "mynetwork가 auto mode가 아닙니다."
vm1="$(terraform -chdir="$work_dir" output -raw vm_one_name)";vm2="$(terraform -chdir="$work_dir" output -raw vm_two_name)";vm2_ip="$(terraform -chdir="$work_dir" output -raw vm_two_internal_ip)"
for spec in "$vm1:$GCP_ZONE" "$vm2:$GCP_SECONDARY_ZONE";do name="${spec%%:*}";zone="${spec#*:}";[[ "$(gcloud compute instances describe "$name" --zone="$zone" --project="$GCP_PROJECT_ID" --format='value(status)')" == RUNNING ]]||harness_die "$name RUNNING 아님";done
timeout 180 gcloud compute ssh "$vm1" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" --tunnel-through-iap --quiet --command="ping -c 3 -W 3 '$vm2_ip' >/dev/null"||harness_die "두 module VM private ping 실패"

idempotency_plan="$run_dir/phase-15-idempotency.tfplan";set +e;harness_tf_timeout terraform -chdir="$work_dir" plan -input=false -lock=false -detailed-exitcode -out="$idempotency_plan" >/dev/null;plan_rc=$?;set -e
[[ "$plan_rc" -eq 0 ]]||harness_die "apply 후 Terraform plan이 변경 0이 아닙니다(rc=$plan_rc)."
idempotency_hash="$(harness_sha256_file "$idempotency_plan")";rm -f "$idempotency_plan"
jq -n --arg phase 15 --arg run_id "$run_id" --arg state_hash "$(printf %s "$addresses"|sha256sum|awk '{print $1}')" --arg idempotency_hash "$idempotency_hash" '{phase:$phase,run_id:$run_id,tasks:{
 "task-1":{status:"passed",detail:"Terraform version contract, provider init lock, fmt, validate 확인"},
 "task-2":{status:"passed",detail:"auto-mode mynetwork, restricted lab firewall, reusable local module VM 2개 saved-plan apply"},
 "task-3":{status:"passed",detail:"state 4 address와 Cloud inventory 대조, cross-region private ping 성공"},
 "task-4":{status:"passed",detail:"idempotency detailed-exitcode 0과 destroy 경로 검토"}},state_address_sha256:$state_hash,state_address_count:4,idempotency_plan_sha256:$idempotency_hash,idempotency_changes:0,risks:["원본 0.0.0.0/0 firewall와 external IP는 IAP·RFC1918 경계로 축소","binary plan과 state는 artifacts ignored 경로에만 유지"]}' >"$evidence";chmod 600 "$evidence"
printf 'PASS: Phase 15 Terraform module·Cloud inventory·idempotency 검증 완료\n'
