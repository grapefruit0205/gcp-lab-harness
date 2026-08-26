#!/usr/bin/env bash
set -Eeuo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export HARNESS_REPO_ROOT="$repo_root" HARNESS_PHASE=15 HARNESS_PHASE_RESOURCE_LIMIT=4
export HARNESS_PHASE_ALLOWED_TYPES_JSON='["google_compute_network","google_compute_firewall","google_compute_instance"]'

phase_preflight() {
  [[ "${GCP_ZONE%-*}" != "${GCP_SECONDARY_ZONE%-*}" ]] || harness_die "Phase15는 서로 다른 두 region의 zone이 필요합니다."
  [[ "$GCP_ZONE" != "$GCP_SECONDARY_ZONE" ]] || harness_die "두 VM에는 서로 다른 zone이 필요합니다."
}
phase_write_tfvars() {
  jq -n --arg project_id "$GCP_PROJECT_ID" --arg run_id "$2" --arg zone_one "$GCP_ZONE" --arg zone_two "$GCP_SECONDARY_ZONE" \
    '{project_id:$project_id,run_id:$run_id,zone_one:$zone_one,zone_two:$zone_two}' >"$1"
}
phase_write_action_plan() {
  jq -n --arg run_id "$2" '{schema_version:1,phase:"15",run_id:$run_id,actions:[
    {id:"saved-plan-apply",kind:"terraform",target:("mynetwork-"+$run_id+" and module VMs"),mutation:"apply exact approved binary plan",rollback:"Terraform destroy from same run state",timeout_seconds:1800,contains_secret:false},
    {id:"cloud-readback",kind:"gcloud",target:("resources labelled "+$run_id),mutation:"compare Terraform addresses and Cloud inventory",rollback:"read-only",timeout_seconds:300,contains_secret:false},
    {id:"private-ping",kind:"guest",target:("mynet-vm-1-"+$run_id),mutation:"three ICMP probes to VM 2 internal IP",rollback:"no retained mutation",timeout_seconds:300,contains_secret:false},
    {id:"idempotency-plan",kind:"terraform",target:"same ignored run state",mutation:"second plan requiring detailed-exitcode 0",rollback:"delete generated binary plan after hash",timeout_seconds:900,contains_secret:false}
  ]}' >"$1"
}
phase_plan_guard() {
  jq -e '
    ([.resource_changes[]|select(.type=="google_compute_network")]|length)==1 and
    ([.resource_changes[]|select(.type=="google_compute_firewall")]|length)==1 and
    ([.resource_changes[]|select(.type=="google_compute_instance")]|length)==2 and
    any(.resource_changes[]; .address|startswith("module.mynet_vm_1.")) and
    any(.resource_changes[]; .address|startswith("module.mynet_vm_2."))
  ' "$1" >/dev/null || harness_die "Phase 15 auto-mode VPC·firewall·local module VM 2개 계약 불일치"
}
source "$repo_root/lib/harness/safe-adapter.sh"
safe_adapter_main "$@"
