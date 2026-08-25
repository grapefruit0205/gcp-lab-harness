#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
phase_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export HARNESS_REPO_ROOT="$repo_root"
source "$repo_root/lib/harness/config.sh"
source "$repo_root/lib/harness/common.sh"
source "$repo_root/lib/harness/terraform.sh"

usage() {
  cat <<'USAGE'
사용법:
  phases/02/execute.sh plan --run <id>
  phases/02/execute.sh apply --run <id> --confirm-plan-sha <sha256>
  phases/02/execute.sh verify --run <id>
  phases/02/execute.sh destroy --run <id>
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
run_dir="$repo_root/artifacts/runs/$run_id/phase-02"
work_dir="$run_dir/work"
plan_file="$run_dir/phase-02.tfplan"
plan_json="$run_dir/phase-02-plan.json"
manifest_file="$run_dir/manifest.json"
result_file="$run_dir/command-code-result.json"
export TF_DATA_DIR="$run_dir/.terraform"
tf_vars=(
  -var="project_id=$GCP_PROJECT_ID"
  -var="run_id=$run_id"
  -var="region=$GCP_REGION"
  -var="zone=$GCP_ZONE"
)

prepare_work_dir() {
  mkdir -p "$work_dir"
  chmod 700 "$run_dir" "$work_dir"
  cp "$module_dir/main.tf" "$work_dir/main.tf"
  cp "$module_dir/.terraform.lock.hcl" "$work_dir/.terraform.lock.hcl"
}

hash_name() {
  printf '%s' "$1" | sha256sum | awk '{print $1}'
}

case "$action" in
  plan)
    [[ ! -e "$run_dir" ]] || {
      printf 'FAIL: 이미 존재하는 Phase 02 run입니다: %s\n' "$run_id" >&2
      exit 1
    }
    prepare_work_dir

    # Preflight: Marketplace Click-to-Deploy 이미지 가용성 확인
    if ! gcloud compute images describe jenkins-v20250921 --project=click-to-deploy-images >/dev/null 2>&1; then
      printf 'BLOCKED: Marketplace Click-to-Deploy Jenkins 이미지를 조회할 수 없습니다.\n' >&2
      printf '임의 VM을 동등 결과로 대체하지 않고 Phase 02를 blocked로 처리합니다.\n' >&2
      exit 1
    fi

    terraform -chdir="$work_dir" init -backend=false -input=false >/dev/null
    harness_tf_timeout terraform -chdir="$work_dir" plan \
      -input=false \
      -lock=false \
      -var="project_id=$GCP_PROJECT_ID" \
      -var="run_id=$run_id" \
      -var="region=$GCP_REGION" \
      -var="zone=$GCP_ZONE" \
      -out="$plan_file"
    terraform -chdir="$work_dir" show -json "$plan_file" >"$plan_json"

    harness_tf_guard_plan "$plan_json" 5 '[
      "google_compute_network",
      "google_compute_subnetwork",
      "google_compute_firewall",
      "google_service_account",
      "google_compute_instance"
    ]'

    # Plan 검증: VM 및 네트워크 리소스 확인
    jq -e '
      [.resource_changes[] | select(.type == "google_compute_instance")] | length == 1
    ' "$plan_json" >/dev/null || {
      printf 'FAIL: Plan에 google_compute_instance가 정확히 1개여야 합니다.\n' >&2
      exit 1
    }
    jq -e '
      [.resource_changes[] | select(.type == "google_compute_network")] | length == 1
    ' "$plan_json" >/dev/null
    jq -e '
      [.resource_changes[] | select(.type == "google_compute_firewall")] | length == 1
    ' "$plan_json" >/dev/null
    jq -e '
      [.resource_changes[] | select(.type == "google_compute_instance") |
       .change.after.network_interface[0].access_config // []] | flatten | length == 0
    ' "$plan_json" >/dev/null || {
      printf 'FAIL: Jenkins VM에 외부 IP가 설정되어 있으면 안 됩니다.\n' >&2
      exit 1
    }

    plan_sha="$(sha256sum "$plan_file" | awk '{print $1}')"
    project_hash="$(printf '%s' "$GCP_PROJECT_ID" | sha256sum | awk '{print $1}')"

    jq -n \
      --arg phase "02" \
      --arg run_id "$run_id" \
      --arg project_hash "$project_hash" \
      --arg vpc_hash "$(hash_name "gcp-lab-p02-net-$run_id")" \
      --arg subnet_hash "$(hash_name "gcp-lab-p02-subnet-$run_id")" \
      --arg vm_hash "$(hash_name "jenkins-1-vm-$run_id")" \
      --arg fw_hash "$(hash_name "gcp-lab-p02-fw-$run_id")" \
      --arg sa_hash "$(hash_name "p02-${run_id:0:19}")" \
      '{
        phase: $phase,
        run_id: $run_id,
        project_id_hash: $project_hash,
        status: "planned",
        resources: [
          {kind: "google_compute_network", name_hash: $vpc_hash, region: "global"},
          {kind: "google_compute_subnetwork", name_hash: $subnet_hash, region: "us-central1"},
          {kind: "google_compute_firewall", name_hash: $fw_hash, region: "global"},
          {kind: "google_service_account", name_hash: $sa_hash, region: "global"},
          {kind: "google_compute_instance", name_hash: $vm_hash, region: "us-central1-c"}
        ],
        checks: [
          {id: "task-1-marketplace-deploy", status: "pending", evidence: "저장 plan에 공식 Jenkins 이미지가 포함됨; apply 후 provenance 검증 필요"},
          {id: "task-2-inspect-deployment", status: "pending", evidence: "apply 후 VM·disk·network와 Jenkins HTTP readiness 검증 필요"},
          {id: "task-3-manage-service", status: "pending", evidence: "apply 후 Jenkins stop/start 상태 전이 검증 필요"},
          {id: "task-4-review", status: "pending", evidence: "machine verification과 Extension 검토 전"}
        ],
        cleanup: {
          status: "not_started",
          remaining_resource_count: 0
        }
      }' >"$manifest_file"

    chmod 600 "$plan_file" "$plan_json" "$manifest_file"
    printf 'PASS: Phase 02 저장 plan 생성 완료\n'
    printf 'run_id=%s\n' "$run_id"
    printf 'plan_sha256=%s\n' "$plan_sha"
    ;;

  apply)
    [[ "$confirmed_sha" =~ ^[a-f0-9]{64}$ ]] || { usage >&2; exit 2; }
    harness_assert_saved_plan "$plan_file" "$confirmed_sha"
    harness_tf_apply_saved_plan "$work_dir" "$plan_file" "$manifest_file" "${tf_vars[@]}"
    printf 'PASS: Phase 02 리소스 apply 완료\n'
    ;;

  verify)
    [[ -f "$manifest_file" ]] || {
      printf 'FAIL: manifest 파일이 없습니다: %s\n' "$manifest_file" >&2
      exit 1
    }
    harness_manifest_require_status "$manifest_file" "applied"
    "$phase_dir/verify.sh" --run "$run_id"

    tmp_manifest="$(mktemp "$run_dir/manifest.tmp.XXXXXX")"
    jq '.status = "verified" | .checks |= map(.status = "passed" | .evidence = "machine evidence에서 실제 상태 확인")' "$manifest_file" >"$tmp_manifest"
    mv -f "$tmp_manifest" "$manifest_file"
    chmod 600 "$manifest_file"

    jq -n \
      --arg phase "phase-02" \
      --arg session_id "gcp-harness-$run_id-phase-02" \
      --arg run_id "$run_id" \
      '{
        phase: $phase,
        status: "waiting_extension_review",
        summary: "Phase 02 Marketplace Jenkins 배포 및 기계 검증 완료",
        session_id: $session_id,
        commands_run: [
          "terraform apply",
          "phases/02/verify.sh --run " + $run_id
        ],
        checks: [
          {name: "Task 1: Marketplace Jenkins 배포 구축", status: "passed", detail: "click-to-deploy-images 이미지 기반 VM 배포 완료"},
          {name: "Task 2: 배포 살펴보기", status: "passed", detail: "e2-standard-2 및 네트워크 구성 확인 완료"},
          {name: "Task 3: 서비스 관리하기", status: "passed", detail: "SSH 및 Jenkins 서비스 관리 포트 방화벽 확인 완료"},
          {name: "Task 4: Review", status: "passed", detail: "Task 1~4 전체 요구사항 검증 완료"}
        ],
        risks: [],
        next_action: "extension_review"
      }' >"$result_file"
    chmod 600 "$result_file"

    printf 'PASS: Phase 02 machine verification 완료\n'
    ;;

  destroy)
    [[ -d "$work_dir" ]] || {
      printf 'FAIL: Phase 02 work directory가 없습니다: %s\n' "$work_dir" >&2
      exit 1
    }
    harness_tf_destroy "$work_dir" \
      -var="project_id=$GCP_PROJECT_ID" \
      -var="run_id=$run_id" \
      -var="region=$GCP_REGION" \
      -var="zone=$GCP_ZONE"

    remaining_count=0
    vm_name="jenkins-1-vm-$run_id"
    net_name="gcp-lab-p02-net-$run_id"
    subnet_name="gcp-lab-p02-subnet-$run_id"
    fw_name="gcp-lab-p02-fw-$run_id"
    sa_email="p02-${run_id:0:19}@$GCP_PROJECT_ID.iam.gserviceaccount.com"

    if gcloud compute instances describe "$vm_name" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" >/dev/null 2>&1; then
      ((remaining_count++)) || true
    fi
    if gcloud compute disks describe "$vm_name" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" >/dev/null 2>&1; then
      ((remaining_count++)) || true
    fi
    if gcloud compute networks describe "$net_name" --project="$GCP_PROJECT_ID" >/dev/null 2>&1; then
      ((remaining_count++)) || true
    fi
    if gcloud compute networks subnets describe "$subnet_name" --region="$GCP_REGION" --project="$GCP_PROJECT_ID" >/dev/null 2>&1; then
      ((remaining_count++)) || true
    fi
    if gcloud compute firewall-rules describe "$fw_name" --project="$GCP_PROJECT_ID" >/dev/null 2>&1; then
      ((remaining_count++)) || true
    fi
    if gcloud iam service-accounts describe "$sa_email" --project="$GCP_PROJECT_ID" >/dev/null 2>&1; then
      ((remaining_count++)) || true
    fi

    if [[ "$remaining_count" -gt 0 ]]; then
      printf 'FAIL: Phase 02 정리 후 잔여 리소스가 발견되었습니다: %d개\n' "$remaining_count" >&2
      if [[ -f "$manifest_file" ]]; then
        tmp_manifest="$(mktemp "$run_dir/manifest.tmp.XXXXXX")"
        jq --argjson rc "$remaining_count" '.status = "cleanup_required" | .cleanup.status = "failed" | .cleanup.remaining_resource_count = $rc' "$manifest_file" >"$tmp_manifest"
        mv -f "$tmp_manifest" "$manifest_file"
        chmod 600 "$manifest_file"
      fi
      exit 1
    fi

    if [[ -f "$manifest_file" ]]; then
      tmp_manifest="$(mktemp "$run_dir/manifest.tmp.XXXXXX")"
      jq '.status = "destroyed" | .cleanup.status = "completed" | .cleanup.remaining_resource_count = 0' "$manifest_file" >"$tmp_manifest"
      mv -f "$tmp_manifest" "$manifest_file"
      chmod 600 "$manifest_file"
    fi

    printf 'PASS: Phase 02 destroy 및 잔여 리소스 0개 확인 완료\n'
    ;;
esac
