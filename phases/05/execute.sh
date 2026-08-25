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
  phases/05/execute.sh plan --run <id>
  phases/05/execute.sh apply --run <id> --confirm-plan-sha <sha256>
  phases/05/execute.sh verify --run <id>
  phases/05/execute.sh destroy --run <id>
USAGE
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
run_dir="$repo_root/artifacts/runs/$run_id/phase-05"
work_dir="$run_dir/work"
plan_file="$run_dir/phase-05.tfplan"
plan_json="$run_dir/phase-05-plan.json"
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
    [[ ! -e "$run_dir" ]] || harness_die "이미 존재하는 Phase 05 run입니다: $run_id"
    prepare_work_dir
    terraform -chdir="$work_dir" init -backend=false -input=false >/dev/null
    harness_tf_timeout terraform -chdir="$work_dir" plan -input=false -lock=false "${tf_vars[@]}" -out="$plan_file"
    terraform -chdir="$work_dir" show -json "$plan_file" >"$plan_json"
    harness_tf_guard_plan "$plan_json" 8 '[
      "google_compute_network",
      "google_compute_subnetwork",
      "google_compute_firewall",
      "google_service_account",
      "google_compute_instance"
    ]'
    jq -e '
      ([.resource_changes[] | select(.type == "google_compute_instance")] | length) == 3 and
      ([.resource_changes[] | select(.type == "google_compute_instance") |
        .change.after.network_interface[0].access_config // []] | flatten | length) == 0 and
      ([.resource_changes[] | select(.type == "google_compute_firewall") |
        .change.after.source_ranges[]] | all(. == "35.235.240.0/20"))
    ' "$plan_json" >/dev/null || harness_die "세 VM 외부 IP 없음 또는 IAP-only ingress 계약이 plan에 없습니다."

    plan_sha="$(harness_sha256_file "$plan_file")"
    project_hash="$(printf '%s' "$GCP_PROJECT_ID" | sha256sum | awk '{print $1}')"
    jq -n \
      --arg phase "05" \
      --arg run_id "$run_id" \
      --arg project_hash "$project_hash" \
      --arg region "$GCP_REGION" \
      --arg zone "$GCP_ZONE" \
      --arg vpc_hash "$(hash_name "gcp-lab-p05-net-$run_id")" \
      --arg subnet_hash "$(hash_name "gcp-lab-p05-subnet-$run_id")" \
      --arg ssh_fw_hash "$(hash_name "gcp-lab-p05-fw-ssh-$run_id")" \
      --arg rdp_fw_hash "$(hash_name "gcp-lab-p05-fw-rdp-$run_id")" \
      --arg sa_hash "$(hash_name "p05-${run_id:0:19}")" \
      --arg u_vm_hash "$(hash_name "utility-vm-$run_id")" \
      --arg w_vm_hash "$(hash_name "windows-vm-$run_id")" \
      --arg c_vm_hash "$(hash_name "custom-vm-$run_id")" '
      {
        phase: $phase,
        run_id: $run_id,
        project_id_hash: $project_hash,
        status: "planned",
        resources: [
          {kind: "google_compute_network", name_hash: $vpc_hash, region: "global"},
          {kind: "google_compute_subnetwork", name_hash: $subnet_hash, region: $region},
          {kind: "google_compute_firewall", name_hash: $ssh_fw_hash, region: "global"},
          {kind: "google_compute_firewall", name_hash: $rdp_fw_hash, region: "global"},
          {kind: "google_service_account", name_hash: $sa_hash, region: "global"},
          {kind: "google_compute_instance", name_hash: $u_vm_hash, region: $zone},
          {kind: "google_compute_instance", name_hash: $w_vm_hash, region: $zone},
          {kind: "google_compute_instance", name_hash: $c_vm_hash, region: $zone}
        ],
        checks: [
          {id: "task-1-utility-vm", status: "pending", evidence: "apply 후 serial/SSH/guest OS 검증 필요"},
          {id: "task-2-windows-vm", status: "pending", evidence: "apply 후 guest agent와 RDP readiness 검증 필요; 비밀번호·GUI는 manual boundary"},
          {id: "task-3-custom-vm", status: "pending", evidence: "apply 후 SSH와 guest CPU/memory 검증 필요"},
          {id: "task-4-review", status: "pending", evidence: "machine verification과 Extension 검토 전"}
        ],
        cleanup: {status: "not_started", remaining_resource_count: 0}
      }' >"$manifest_file"
    chmod 600 "$plan_file" "$plan_json" "$manifest_file"
    printf 'PASS: Phase 05 저장 plan 생성 완료\nrun_id=%s\nplan_sha256=%s\n' "$run_id" "$plan_sha"
    ;;

  apply)
    harness_assert_saved_plan "$plan_file" "$confirmed_sha"
    harness_tf_apply_saved_plan "$work_dir" "$plan_file" "$manifest_file" "${tf_vars[@]}"
    printf 'PASS: Phase 05 리소스 apply 완료\n'
    ;;

  verify)
    harness_manifest_require_status "$manifest_file" "applied"
    "$phase_dir/verify.sh" --run "$run_id"
    tmp_manifest="$(mktemp "$run_dir/manifest.tmp.XXXXXX")"
    jq '.status = "verified" | .checks |= map(.status = "passed" | .evidence = "machine evidence에서 실제 guest readiness 확인")' "$manifest_file" >"$tmp_manifest"
    mv -f "$tmp_manifest" "$manifest_file"
    chmod 600 "$manifest_file"
    jq -n \
      --arg phase "phase-05" \
      --arg session_id "gcp-harness-$run_id-phase-05" \
      --arg run_id "$run_id" '
      {
        phase: $phase,
        status: "waiting_extension_review",
        summary: "Phase 05 Linux·Windows·custom VM 사양과 guest readiness 검증 완료",
        session_id: $session_id,
        commands_run: ["terraform apply", "phases/05/verify.sh --run " + $run_id],
        checks: [
          {name: "Task 1: 유틸리티 VM", status: "passed", detail: "외부 IP 없음, SSH와 guest readiness"},
          {name: "Task 2: Windows VM", status: "passed", detail: "guest agent가 보고한 RDP service/port readiness; 비밀번호·GUI 미실행"},
          {name: "Task 3: 커스텀 VM", status: "passed", detail: "e2-custom-2-4096과 guest CPU/memory"},
          {name: "Task 4: Review", status: "passed", detail: "세 VM 구조화 evidence 생성"}
        ],
        risks: ["Windows 비밀번호 생성과 RDP GUI 로그인은 의도적으로 manual boundary"],
        next_action: "extension_review"
      }' >"$result_file"
    chmod 600 "$result_file"
    printf 'PASS: Phase 05 machine verification 완료\n'
    ;;

  destroy)
    [[ -d "$work_dir" ]] || harness_die "Phase 05 work directory가 없습니다: $work_dir"
    harness_tf_destroy "$work_dir" "${tf_vars[@]}"
    remaining_count=0
    for vm_name in "utility-vm-$run_id" "windows-vm-$run_id" "custom-vm-$run_id"; do
      gcloud compute instances describe "$vm_name" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining_count++)) || true
      gcloud compute disks describe "$vm_name" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining_count++)) || true
    done
    gcloud compute networks subnets describe "gcp-lab-p05-subnet-$run_id" --region="$GCP_REGION" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining_count++)) || true
    for fw_name in "gcp-lab-p05-fw-ssh-$run_id" "gcp-lab-p05-fw-rdp-$run_id"; do
      gcloud compute firewall-rules describe "$fw_name" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining_count++)) || true
    done
    gcloud compute networks describe "gcp-lab-p05-net-$run_id" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining_count++)) || true
    gcloud iam service-accounts describe "p05-${run_id:0:19}@$GCP_PROJECT_ID.iam.gserviceaccount.com" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining_count++)) || true
    [[ "$remaining_count" -eq 0 ]] || {
      harness_manifest_set_status "$manifest_file" "cleanup_required" || true
      harness_die "Phase 05 정리 후 잔여 리소스가 발견되었습니다: ${remaining_count}개"
    }
    tmp_manifest="$(mktemp "$run_dir/manifest.tmp.XXXXXX")"
    jq '.status = "destroyed" | .cleanup.status = "completed" | .cleanup.remaining_resource_count = 0' "$manifest_file" >"$tmp_manifest"
    mv -f "$tmp_manifest" "$manifest_file"
    chmod 600 "$manifest_file"
    printf 'PASS: Phase 05 destroy 및 잔여 리소스 0개 확인 완료\n'
    ;;
esac
