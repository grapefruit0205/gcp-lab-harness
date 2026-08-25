#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
phase_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export HARNESS_REPO_ROOT="$repo_root"
source "$repo_root/lib/harness/config.sh"
source "$repo_root/lib/harness/terraform.sh"

usage() {
  printf '사용법: P03_CLIENT_SOURCE_CIDR=<CIDR> P03_DEFAULT_VPC_ACTION=preserve %s plan --run <id>\n' "$0"
  printf '        %s {apply|verify|destroy} --run <id> [--confirm-plan-sha <sha256>]\n' "$0"
}
action="${1:-}"
[[ "$action" == "plan" || "$action" == "apply" || "$action" == "verify" || "$action" == "destroy" ]] || { usage >&2; exit 2; }
shift
run_id=""
confirmed_sha=""
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --run) run_id="${2:-}"; shift 2 ;;
    --confirm-plan-sha) confirmed_sha="${2:-}"; shift 2 ;;
    *) usage >&2; exit 2 ;;
  esac
done
harness_validate_run_id "$run_id"
"$repo_root/scripts/preflight-gcp.sh" >/dev/null
harness_load_config "$repo_root/config/harness.env"

module_dir="$phase_dir/terraform"
run_dir="$repo_root/artifacts/runs/$run_id/phase-03"
work_dir="$run_dir/work"
plan_file="$run_dir/phase-03.tfplan"
plan_json="$run_dir/phase-03-plan.json"
manifest_file="$run_dir/manifest.json"
result_file="$run_dir/command-code-result.json"
tfvars_file="$work_dir/phase-03.auto.tfvars.json"
export TF_DATA_DIR="$run_dir/.terraform"
hash_name() { printf '%s' "$1" | sha256sum | awk '{print $1}'; }
tf_vars=(-var="project_id=$GCP_PROJECT_ID" -var="run_id=$run_id" -var="region=$GCP_REGION" -var="zone=$GCP_ZONE" -var="secondary_zone=$GCP_SECONDARY_ZONE")

case "$action" in
  plan)
    [[ ! -e "$run_dir" ]] || harness_die "이미 존재하는 Phase 03 run입니다: $run_id"
    : "${P03_CLIENT_SOURCE_CIDR:?P03_CLIENT_SOURCE_CIDR가 필요합니다.}"
    [[ "${P03_DEFAULT_VPC_ACTION:-}" == "preserve" ]] || harness_die "기존 default VPC는 P03_DEFAULT_VPC_ACTION=preserve로 명시해야 하며 자동 삭제하지 않습니다."
    [[ "$P03_CLIENT_SOURCE_CIDR" != "0.0.0.0/0" && "$P03_CLIENT_SOURCE_CIDR" != "::/0" ]] || harness_die "public 전체 CIDR은 허용하지 않습니다."
    gcloud compute networks describe default --project="$GCP_PROJECT_ID" --format=json >/dev/null 2>&1 || true
    mkdir -p "$work_dir"
    chmod 700 "$run_dir" "$work_dir"
    cp "$module_dir/main.tf" "$work_dir/main.tf"
    cp "$module_dir/.terraform.lock.hcl" "$work_dir/.terraform.lock.hcl"
    jq -n --arg cidr "$P03_CLIENT_SOURCE_CIDR" '{client_source_cidr: $cidr}' >"$tfvars_file"
    chmod 600 "$tfvars_file"
    terraform -chdir="$work_dir" init -backend=false -input=false >/dev/null
    harness_tf_timeout terraform -chdir="$work_dir" plan -input=false -lock=false "${tf_vars[@]}" -out="$plan_file"
    terraform -chdir="$work_dir" show -json "$plan_file" >"$plan_json"
    harness_tf_guard_plan "$plan_json" 17 '["google_compute_network","google_compute_subnetwork","google_service_account","google_compute_firewall","google_compute_instance"]'
    jq -e '
      ([.resource_changes[] | select(.type == "google_compute_network")] | length) == 3 and
      ([.resource_changes[] | select(.type == "google_compute_instance")] | length) == 4 and
      ([.resource_changes[] | select(.type == "google_compute_firewall") |
        .change.after.source_ranges[]] | all(. != "0.0.0.0/0" and . != "::/0"))
    ' "$plan_json" >/dev/null || harness_die "Phase 03 topology 또는 제한 ingress 계약이 plan에 없습니다."
    plan_sha="$(harness_sha256_file "$plan_file")"
    project_hash="$(hash_name "$GCP_PROJECT_ID")"
    resources_json="$(jq -n '[]')"
    add_resource() {
      local kind="$1" name="$2" location="$3"
      resources_json="$(jq --arg kind "$kind" --arg name_hash "$(hash_name "$name")" --arg region "$location" '. + [{kind:$kind,name_hash:$name_hash,region:$region}]' <<<"$resources_json")"
    }
    add_resource google_compute_network "mynetwork-$run_id" global
    add_resource google_compute_network "managementnet-$run_id" global
    add_resource google_compute_network "privatenet-$run_id" global
    add_resource google_compute_subnetwork "managementsubnet-$run_id" "$GCP_REGION"
    add_resource google_compute_subnetwork "privatesubnet-$run_id" "$GCP_REGION"
    add_resource google_service_account "p03-${run_id:0:19}" global
    for net in auto management private; do
      add_resource google_compute_firewall "$net-iap-ssh-$run_id" global
      add_resource google_compute_firewall "$net-client-icmp-$run_id" global
    done
    add_resource google_compute_firewall "auto-internal-icmp-$run_id" global
    add_resource google_compute_instance "mynet-us-vm-$run_id" "$GCP_ZONE"
    add_resource google_compute_instance "mynet-eu-vm-$run_id" "$GCP_SECONDARY_ZONE"
    add_resource google_compute_instance "managementnet-vm-$run_id" "$GCP_ZONE"
    add_resource google_compute_instance "privatenet-vm-$run_id" "$GCP_ZONE"
    jq -n \
      --arg phase "03" \
      --arg run_id "$run_id" \
      --arg project_hash "$project_hash" \
      --argjson resources "$resources_json" '
      {
        phase: $phase,
        run_id: $run_id,
        project_id_hash: $project_hash,
        status: "planned",
        resources: $resources,
        checks: [
          {id: "task-1-default-network", status: "manual-boundary", evidence: "기존 default VPC는 run 소유가 아니므로 read-only describe만 수행"},
          {id: "task-2-auto-network", status: "pending", evidence: "auto VPC·지역 VM·연결성은 검증; custom mode 전환은 별도 승인 plan이 필요"},
          {id: "task-3-custom-networks", status: "pending", evidence: "management/private VPC·subnet·VM 실제 상태 확인 필요"},
          {id: "task-4-connectivity", status: "pending", evidence: "외부 성공·동일 VPC 내부 성공·VPC 간 expected failure matrix 필요"},
          {id: "task-5-review", status: "pending", evidence: "machine verification과 Extension 검토 전"}
        ],
        cleanup: {status: "not_started", remaining_resource_count: 0}
      }' >"$manifest_file"
    chmod 600 "$plan_file" "$plan_json" "$manifest_file"
    printf 'PASS: Phase 03 저장 plan 생성 완료\nrun_id=%s\nplan_sha256=%s\n' "$run_id" "$plan_sha"
    ;;
  apply)
    harness_assert_saved_plan "$plan_file" "$confirmed_sha"
    harness_tf_apply_saved_plan "$work_dir" "$plan_file" "$manifest_file" "${tf_vars[@]}"
    printf 'PASS: Phase 03 리소스 apply 완료\n'
    ;;
  verify)
    harness_manifest_require_status "$manifest_file" "applied"
    "$phase_dir/verify.sh" --run "$run_id"
    tmp_manifest="$(mktemp "$run_dir/manifest.tmp.XXXXXX")"
    jq '.status = "verified" | .checks |= map(if .id == "task-1-default-network" or .id == "task-2-auto-network" then . else .status = "passed" | .evidence = "machine evidence에서 실제 topology와 packet path 확인" end)' "$manifest_file" >"$tmp_manifest"
    mv -f "$tmp_manifest" "$manifest_file"
    chmod 600 "$manifest_file"
    jq -n \
      --arg phase "phase-03" \
      --arg session_id "gcp-harness-$run_id-phase-03" \
      --arg run_id "$run_id" '
      {
        phase: $phase,
        status: "blocked",
        summary: "Phase 03 auto/custom topology와 실제 연결 matrix 검증 완료; default 삭제와 auto→custom 전환은 미실행 경계",
        session_id: $session_id,
        commands_run: ["terraform apply", "phases/03/verify.sh --run " + $run_id],
        checks: [
          {name: "Task 1: default VPC", status: "skipped", detail: "기존 리소스 삭제를 거부하고 read-only describe만 수행"},
          {name: "Task 2: auto network", status: "skipped", detail: "auto VPC와 지역 연결은 통과; auto→custom 변경은 두 번째 승인 plan 필요"},
          {name: "Task 3: custom networks", status: "passed", detail: "management/private topology 확인"},
          {name: "Task 4: connectivity", status: "passed", detail: "외부/동일 VPC 성공과 VPC 간 expected failure"},
          {name: "Task 5: Review", status: "passed", detail: "구조화 topology·matrix evidence 생성"}
        ],
        risks: ["Task 1 default VPC 삭제와 Task 2 auto→custom 전환은 안전한 별도 승인 설계 전까지 완료 아님"],
        next_action: "extension_review"
      }' >"$result_file"
    chmod 600 "$result_file"
    printf 'PASS: Phase 03 machine verification 완료 (두 conditional 경계는 완료로 간주하지 않음)\n'
    ;;
  destroy)
    [[ -d "$work_dir" ]] || harness_die "Phase 03 work directory가 없습니다: $work_dir"
    harness_tf_destroy "$work_dir" "${tf_vars[@]}"
    remaining_count=0
    for vm_spec in "mynet-us-vm-$run_id:$GCP_ZONE" "mynet-eu-vm-$run_id:$GCP_SECONDARY_ZONE" "managementnet-vm-$run_id:$GCP_ZONE" "privatenet-vm-$run_id:$GCP_ZONE"; do
      vm_name="${vm_spec%%:*}"; vm_zone="${vm_spec#*:}"
      gcloud compute instances describe "$vm_name" --zone="$vm_zone" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining_count++)) || true
      gcloud compute disks describe "$vm_name" --zone="$vm_zone" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining_count++)) || true
    done
    for subnet_name in "managementsubnet-$run_id" "privatesubnet-$run_id"; do
      gcloud compute networks subnets describe "$subnet_name" --region="$GCP_REGION" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining_count++)) || true
    done
    for net in auto management private; do
      for fw_name in "$net-iap-ssh-$run_id" "$net-client-icmp-$run_id"; do
        gcloud compute firewall-rules describe "$fw_name" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining_count++)) || true
      done
    done
    gcloud compute firewall-rules describe "auto-internal-icmp-$run_id" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining_count++)) || true
    for net_name in "mynetwork-$run_id" "managementnet-$run_id" "privatenet-$run_id"; do
      gcloud compute networks describe "$net_name" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining_count++)) || true
    done
    gcloud iam service-accounts describe "p03-${run_id:0:19}@$GCP_PROJECT_ID.iam.gserviceaccount.com" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining_count++)) || true
    [[ "$remaining_count" -eq 0 ]] || {
      harness_manifest_set_status "$manifest_file" "cleanup_required" || true
      harness_die "Phase 03 정리 후 잔여 리소스가 발견되었습니다: ${remaining_count}개"
    }
    tmp_manifest="$(mktemp "$run_dir/manifest.tmp.XXXXXX")"
    jq '.status = "destroyed" | .cleanup.status = "completed" | .cleanup.remaining_resource_count = 0' "$manifest_file" >"$tmp_manifest"
    mv -f "$tmp_manifest" "$manifest_file"
    chmod 600 "$manifest_file"
    printf 'PASS: Phase 03 destroy 및 잔여 핵심 리소스 0개 확인 완료\n'
    ;;
esac
