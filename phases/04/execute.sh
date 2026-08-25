#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
phase_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export HARNESS_REPO_ROOT="$repo_root"
source "$repo_root/lib/harness/config.sh"
source "$repo_root/lib/harness/terraform.sh"

usage() {
  cat <<'USAGE'
사용법:
  phases/04/execute.sh plan --run <id>
  phases/04/execute.sh apply --run <id> --confirm-plan-sha <sha256>
  phases/04/execute.sh verify --run <id>
  phases/04/execute.sh destroy --run <id>
USAGE
}

action="${1:-}"
[[ "$action" == "plan" || "$action" == "apply" || "$action" == "verify" || "$action" == "destroy" ]] || {
  usage >&2
  exit 2
}
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
run_dir="$repo_root/artifacts/runs/$run_id/phase-04"
work_dir="$run_dir/work"
plan_file="$run_dir/phase-04.tfplan"
plan_json="$run_dir/phase-04-plan.json"
manifest_file="$run_dir/manifest.json"
result_file="$run_dir/command-code-result.json"
export TF_DATA_DIR="$run_dir/.terraform"

hash_name() { printf '%s' "$1" | sha256sum | awk '{print $1}'; }

prepare_work_dir() {
  mkdir -p "$work_dir"
  chmod 700 "$run_dir" "$work_dir"
  cp "$module_dir/main.tf" "$work_dir/main.tf"
  cp "$module_dir/.terraform.lock.hcl" "$work_dir/.terraform.lock.hcl"
}

tf_vars=(
  -var="project_id=$GCP_PROJECT_ID"
  -var="run_id=$run_id"
  -var="region=$GCP_REGION"
  -var="zone=$GCP_ZONE"
)

case "$action" in
  plan)
    [[ ! -e "$run_dir" ]] || harness_die "이미 존재하는 Phase 04 run입니다: $run_id"
    prepare_work_dir
    terraform -chdir="$work_dir" init -backend=false -input=false >/dev/null
    harness_tf_timeout terraform -chdir="$work_dir" plan -input=false -lock=false "${tf_vars[@]}" -out="$plan_file"
    terraform -chdir="$work_dir" show -json "$plan_file" >"$plan_json"

    harness_tf_guard_plan "$plan_json" 12 '[
      "google_compute_network",
      "google_compute_subnetwork",
      "google_compute_firewall",
      "google_storage_bucket",
      "google_storage_bucket_object",
      "google_service_account",
      "google_storage_bucket_iam_member",
      "google_compute_instance",
      "google_compute_router",
      "google_compute_router_nat"
    ]'
    jq -e '
      ([.resource_changes[] | select(.type == "google_compute_instance")] | length) == 2 and
      ([.resource_changes[] | select(.type == "google_compute_instance") |
        .change.after.network_interface[0].access_config // []] | flatten | length) == 0 and
      ([.resource_changes[] | select(.type == "google_compute_subnetwork") |
        .change.after.private_ip_google_access] | sort) == [false, true]
    ' "$plan_json" >/dev/null || harness_die "PGA control/enabled VM 또는 외부 IP 없음 계약이 plan에 없습니다."

    plan_sha="$(harness_sha256_file "$plan_file")"
    project_hash="$(printf '%s' "$GCP_PROJECT_ID" | sha256sum | awk '{print $1}')"
    jq -n \
      --arg phase "04" \
      --arg run_id "$run_id" \
      --arg project_hash "$project_hash" \
      --arg region "$GCP_REGION" \
      --arg zone "$GCP_ZONE" \
      --arg vpc_hash "$(hash_name "privatenet-$run_id")" \
      --arg control_subnet_hash "$(hash_name "privatenet-control-$run_id")" \
      --arg enabled_subnet_hash "$(hash_name "privatenet-enabled-$run_id")" \
      --arg control_vm_hash "$(hash_name "vm-control-$run_id")" \
      --arg enabled_vm_hash "$(hash_name "vm-enabled-$run_id")" \
      --arg bucket_hash "$(hash_name "gcp-lab-p04-$run_id")" \
      --arg object_hash "$(hash_name "gcp-lab-p04-$run_id/access.svg")" \
      --arg router_hash "$(hash_name "nat-router-$run_id")" \
      --arg nat_hash "$(hash_name "nat-config-$run_id")" \
      --arg fw_hash "$(hash_name "privatenet-iap-ssh-$run_id")" \
      --arg sa_hash "$(hash_name "p04-${run_id:0:19}")" '
      {
        phase: $phase,
        run_id: $run_id,
        project_id_hash: $project_hash,
        status: "planned",
        resources: [
          {kind: "google_compute_network", name_hash: $vpc_hash, region: "global"},
          {kind: "google_compute_subnetwork", name_hash: $control_subnet_hash, region: $region},
          {kind: "google_compute_subnetwork", name_hash: $enabled_subnet_hash, region: $region},
          {kind: "google_compute_firewall", name_hash: $fw_hash, region: "global"},
          {kind: "google_storage_bucket", name_hash: $bucket_hash, region: "US"},
          {kind: "google_storage_bucket_object", name_hash: $object_hash, region: "US"},
          {kind: "google_service_account", name_hash: $sa_hash, region: "global"},
          {kind: "google_storage_bucket_iam_member", name_hash: $sa_hash, region: "global"},
          {kind: "google_compute_instance", name_hash: $control_vm_hash, region: $zone},
          {kind: "google_compute_instance", name_hash: $enabled_vm_hash, region: $zone},
          {kind: "google_compute_router", name_hash: $router_hash, region: $region},
          {kind: "google_compute_router_nat", name_hash: $nat_hash, region: $region}
        ],
        checks: [
          {id: "task-1-vm-no-external-ip", status: "pending", evidence: "apply 후 두 probe VM의 access config와 IAP SSH 확인 필요"},
          {id: "task-2-pga-enabled", status: "pending", evidence: "동일 Storage probe의 control 실패와 enabled 성공 확인 필요"},
          {id: "task-3-cloud-nat", status: "pending", evidence: "동일 internet probe의 control 실패와 enabled 성공 확인 필요"},
          {id: "task-4-nat-logging", status: "pending", evidence: "실제 egress 후 NAT log correlation 확인 필요"},
          {id: "task-5-review", status: "pending", evidence: "machine verification과 Extension 검토 전"}
        ],
        cleanup: {status: "not_started", remaining_resource_count: 0}
      }' >"$manifest_file"
    chmod 600 "$plan_file" "$plan_json" "$manifest_file"
    printf 'PASS: Phase 04 저장 plan 생성 완료\nrun_id=%s\nplan_sha256=%s\n' "$run_id" "$plan_sha"
    ;;

  apply)
    harness_assert_saved_plan "$plan_file" "$confirmed_sha"
    harness_tf_apply_saved_plan "$work_dir" "$plan_file" "$manifest_file" "${tf_vars[@]}"
    printf 'PASS: Phase 04 리소스 apply 완료\n'
    ;;

  verify)
    harness_manifest_require_status "$manifest_file" "applied"
    "$phase_dir/verify.sh" --run "$run_id"
    tmp_manifest="$(mktemp "$run_dir/manifest.tmp.XXXXXX")"
    jq '.status = "verified" | .checks |= map(.status = "passed" | .evidence = "machine evidence에서 실제 control/enabled 경로 확인")' "$manifest_file" >"$tmp_manifest"
    mv -f "$tmp_manifest" "$manifest_file"
    chmod 600 "$manifest_file"
    jq -n \
      --arg phase "phase-04" \
      --arg session_id "gcp-harness-$run_id-phase-04" \
      --arg run_id "$run_id" '
      {
        phase: $phase,
        status: "waiting_extension_review",
        summary: "Phase 04 PGA와 NAT의 disabled/enabled 경로 및 NAT log 검증 완료",
        session_id: $session_id,
        commands_run: ["terraform apply", "phases/04/verify.sh --run " + $run_id],
        checks: [
          {name: "Task 1: 외부 IP 없는 VM", status: "passed", detail: "control/enabled VM 모두 외부 IP 없음"},
          {name: "Task 2: Private Google Access", status: "passed", detail: "control 실패와 enabled Storage 성공"},
          {name: "Task 3: Cloud NAT", status: "passed", detail: "control egress 실패와 enabled egress 성공"},
          {name: "Task 4: Cloud NAT Logging", status: "passed", detail: "실제 traffic 뒤 NAT log 확인"},
          {name: "Task 5: Review", status: "passed", detail: "경로별 evidence 생성"}
        ],
        risks: ["전후 효과를 한 VM을 변경하는 대신 동일 사양 control/enabled VM 쌍으로 비교함"],
        next_action: "extension_review"
      }' >"$result_file"
    chmod 600 "$result_file"
    printf 'PASS: Phase 04 machine verification 완료\n'
    ;;

  destroy)
    [[ -d "$work_dir" ]] || harness_die "Phase 04 work directory가 없습니다: $work_dir"
    harness_tf_destroy "$work_dir" "${tf_vars[@]}"
    remaining_count=0
    for vm_name in "vm-control-$run_id" "vm-enabled-$run_id"; do
      gcloud compute instances describe "$vm_name" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining_count++)) || true
      gcloud compute disks describe "$vm_name" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining_count++)) || true
    done
    for subnet_name in "privatenet-control-$run_id" "privatenet-enabled-$run_id"; do
      gcloud compute networks subnets describe "$subnet_name" --region="$GCP_REGION" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining_count++)) || true
    done
    gcloud compute firewall-rules describe "privatenet-iap-ssh-$run_id" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining_count++)) || true
    gcloud compute routers describe "nat-router-$run_id" --region="$GCP_REGION" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining_count++)) || true
    gcloud compute routers nats describe "nat-config-$run_id" --router="nat-router-$run_id" --region="$GCP_REGION" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining_count++)) || true
    gcloud storage buckets describe "gs://gcp-lab-p04-$run_id" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining_count++)) || true
    gcloud compute networks describe "privatenet-$run_id" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining_count++)) || true
    gcloud iam service-accounts describe "p04-${run_id:0:19}@$GCP_PROJECT_ID.iam.gserviceaccount.com" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining_count++)) || true
    [[ "$remaining_count" -eq 0 ]] || {
      harness_manifest_set_status "$manifest_file" "cleanup_required" || true
      harness_die "Phase 04 정리 후 잔여 리소스가 발견되었습니다: ${remaining_count}개"
    }
    tmp_manifest="$(mktemp "$run_dir/manifest.tmp.XXXXXX")"
    jq '.status = "destroyed" | .cleanup.status = "completed" | .cleanup.remaining_resource_count = 0' "$manifest_file" >"$tmp_manifest"
    mv -f "$tmp_manifest" "$manifest_file"
    chmod 600 "$manifest_file"
    printf 'PASS: Phase 04 destroy 및 잔여 리소스 0개 확인 완료\n'
    ;;
esac
