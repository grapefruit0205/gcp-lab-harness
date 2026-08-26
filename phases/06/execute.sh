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
  P06_CLIENT_SOURCE_CIDR=<IPv4_CIDR 또는 공개 접속 0.0.0.0/0> \
  P06_MINECRAFT_SERVER_URL=<HTTPS_URL> \
  P06_MINECRAFT_SERVER_SHA256=<SHA256> \
  P06_JRE_PACKAGE_VERSION=<APT_VERSION> \
  P06_EULA_ACCEPTED=true \
    phases/06/execute.sh plan --run <id>
  phases/06/execute.sh apply --run <id> --confirm-plan-sha <sha256>
  phases/06/execute.sh verify --run <id>
  phases/06/execute.sh destroy --run <id>
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
run_dir="$repo_root/artifacts/runs/$run_id/phase-06"
work_dir="$run_dir/work"
plan_file="$run_dir/phase-06.tfplan"
plan_json="$run_dir/phase-06-plan.json"
manifest_file="$run_dir/manifest.json"
result_file="$run_dir/command-code-result.json"
tfvars_file="$work_dir/phase-06.auto.tfvars.json"
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
    [[ ! -e "$run_dir" ]] || harness_die "이미 존재하는 Phase 06 run입니다: $run_id"
    : "${P06_CLIENT_SOURCE_CIDR:?P06_CLIENT_SOURCE_CIDR가 필요합니다.}"
    : "${P06_MINECRAFT_SERVER_URL:?P06_MINECRAFT_SERVER_URL이 필요합니다.}"
    : "${P06_MINECRAFT_SERVER_SHA256:?P06_MINECRAFT_SERVER_SHA256이 필요합니다.}"
    : "${P06_JRE_PACKAGE_VERSION:?P06_JRE_PACKAGE_VERSION이 필요합니다.}"
    [[ "${P06_EULA_ACCEPTED:-}" == "true" ]] || harness_die "P06_EULA_ACCEPTED=true의 명시적 동의가 필요합니다."
    [[ "$P06_MINECRAFT_SERVER_SHA256" =~ ^[a-f0-9]{64}$ ]] || harness_die "Minecraft artifact SHA-256 형식이 잘못되었습니다."
    python3 "$phase_dir/network-policy.py" cidr --cidr "$P06_CLIENT_SOURCE_CIDR"
    command -v curl >/dev/null 2>&1 || harness_die "artifact preflight에 curl이 필요합니다."

    artifact_tmp="$(mktemp)"
    trap 'rm -f "$artifact_tmp"' EXIT
    curl --proto '=https' --tlsv1.2 --fail --location --silent --show-error --max-time 300 \
      --output "$artifact_tmp" "$P06_MINECRAFT_SERVER_URL"
    actual_artifact_sha="$(sha256sum "$artifact_tmp" | awk '{print $1}')"
    [[ "$actual_artifact_sha" == "$P06_MINECRAFT_SERVER_SHA256" ]] || harness_die "Minecraft artifact checksum이 승인값과 다릅니다."
    rm -f "$artifact_tmp"
    trap - EXIT

    prepare_work_dir
    jq -n \
      --arg client_source_cidr "$P06_CLIENT_SOURCE_CIDR" \
      --arg minecraft_server_url "$P06_MINECRAFT_SERVER_URL" \
      --arg minecraft_server_sha256 "$P06_MINECRAFT_SERVER_SHA256" \
      --arg jre_package_version "$P06_JRE_PACKAGE_VERSION" '
      {
        client_source_cidr: $client_source_cidr,
        minecraft_server_url: $minecraft_server_url,
        minecraft_server_sha256: $minecraft_server_sha256,
        jre_package_version: $jre_package_version,
        minecraft_eula_accepted: true
      }' >"$tfvars_file"
    chmod 600 "$tfvars_file"

    terraform -chdir="$work_dir" init -backend=false -input=false >/dev/null
    harness_tf_timeout terraform -chdir="$work_dir" plan -input=false -lock=false "${tf_vars[@]}" -out="$plan_file"
    terraform -chdir="$work_dir" show -json "$plan_file" >"$plan_json"
    harness_tf_guard_plan "$plan_json" 10 '[
      "google_compute_network",
      "google_compute_subnetwork",
      "google_compute_address",
      "google_compute_firewall",
      "google_storage_bucket",
      "google_service_account",
      "google_storage_bucket_iam_member",
      "google_compute_disk",
      "google_compute_instance"
    ]'
    jq -e '
      ([.resource_changes[] | select(.type == "google_compute_instance")] | length) == 1 and
      ([.resource_changes[] | select(.type == "google_compute_disk")] | length) == 1
    ' "$plan_json" >/dev/null || harness_die "Phase 06 VM/disk 계약이 plan에 없습니다."
    python3 "$phase_dir/network-policy.py" plan --cidr "$P06_CLIENT_SOURCE_CIDR" "$plan_json"

    plan_sha="$(harness_sha256_file "$plan_file")"
    project_hash="$(printf '%s' "$GCP_PROJECT_ID" | sha256sum | awk '{print $1}')"
    jq -n \
      --arg phase "06" \
      --arg run_id "$run_id" \
      --arg project_hash "$project_hash" \
      --arg region "$GCP_REGION" \
      --arg zone "$GCP_ZONE" \
      --arg vpc_hash "$(hash_name "gcp-lab-p06-net-$run_id")" \
      --arg subnet_hash "$(hash_name "gcp-lab-p06-subnet-$run_id")" \
      --arg address_hash "$(hash_name "mc-ip-$run_id")" \
      --arg ssh_fw_hash "$(hash_name "minecraft-iap-ssh-$run_id")" \
      --arg app_fw_hash "$(hash_name "minecraft-rule-$run_id")" \
      --arg sa_hash "$(hash_name "p06-${run_id:0:19}")" \
      --arg vm_hash "$(hash_name "mc-server-$run_id")" \
      --arg disk_hash "$(hash_name "minecraft-disk-$run_id")" \
      --arg bucket_hash "$(hash_name "gcp-lab-p06-backup-$run_id")" \
      --arg artifact_hash "$P06_MINECRAFT_SERVER_SHA256" \
      --arg client_cidr_hash "$(hash_name "$P06_CLIENT_SOURCE_CIDR")" '
      {
        phase: $phase,
        run_id: $run_id,
        project_id_hash: $project_hash,
        status: "planned",
        resources: [
          {kind: "google_compute_network", name_hash: $vpc_hash, region: "global"},
          {kind: "google_compute_subnetwork", name_hash: $subnet_hash, region: $region},
          {kind: "google_compute_address", name_hash: $address_hash, region: $region},
          {kind: "google_compute_firewall", name_hash: $ssh_fw_hash, region: "global"},
          {kind: "google_compute_firewall", name_hash: $app_fw_hash, region: "global"},
          {kind: "google_service_account", name_hash: $sa_hash, region: "global"},
          {kind: "google_storage_bucket", name_hash: $bucket_hash, region: "US"},
          {kind: "google_storage_bucket_iam_member", name_hash: $sa_hash, region: "global"},
          {kind: "google_compute_disk", name_hash: $disk_hash, region: $zone},
          {kind: "google_compute_instance", name_hash: $vm_hash, region: $zone}
        ],
        checks: [
          {id: "task-1-vm-create", status: "pending", evidence: "apply 후 metadata·service account·startup readiness 확인 필요"},
          {id: "task-2-data-disk", status: "pending", evidence: "filesystem·UUID·fstab와 stop/start 후 mount 유지 확인 필요"},
          {id: "task-3-app-install", status: "pending", evidence: "JRE version·artifact checksum·EULA·systemd readiness 확인 필요"},
          {id: "task-4-client-traffic", status: "pending", evidence: "승인 CIDR과 실제 외부 TCP 25565 probe 확인 필요"},
          {id: "task-5-backup-schedule", status: "pending", evidence: "즉시 backup·object hash·복구 가능 archive·cron 확인 필요"},
          {id: "task-6-maintenance", status: "pending", evidence: "shutdown hook과 VM stop/start 후 복구 확인 필요"},
          {id: "task-7-review", status: "pending", evidence: "machine verification과 Extension 검토 전"}
        ],
        artifact_sha256: $artifact_hash,
        client_source_cidr_sha256: $client_cidr_hash,
        cleanup: {status: "not_started", remaining_resource_count: 0}
      }' >"$manifest_file"
    chmod 600 "$plan_file" "$plan_json" "$manifest_file"
    printf 'PASS: Phase 06 저장 plan 생성 완료\nrun_id=%s\nplan_sha256=%s\n' "$run_id" "$plan_sha"
    ;;

  apply)
    harness_assert_saved_plan "$plan_file" "$confirmed_sha"
    harness_tf_apply_saved_plan "$work_dir" "$plan_file" "$manifest_file" "${tf_vars[@]}"
    printf 'PASS: Phase 06 리소스 apply 완료\n'
    ;;

  verify)
    harness_manifest_require_status "$manifest_file" "applied"
    "$phase_dir/verify.sh" --run "$run_id"
    tmp_manifest="$(mktemp "$run_dir/manifest.tmp.XXXXXX")"
    jq '.status = "verified" | .checks |= map(.status = "passed" | .evidence = "machine evidence에서 실제 guest/network/backup/lifecycle 상태 확인")' "$manifest_file" >"$tmp_manifest"
    mv -f "$tmp_manifest" "$manifest_file"
    chmod 600 "$manifest_file"
    jq -n \
      --arg phase "phase-06" \
      --arg session_id "gcp-harness-$run_id-phase-06" \
      --arg run_id "$run_id" '
      {
        phase: $phase,
        status: "waiting_extension_review",
        summary: "Phase 06 disk·Minecraft·traffic·backup·maintenance 실제 동작 검증 완료",
        session_id: $session_id,
        commands_run: ["terraform apply", "phases/06/verify.sh --run " + $run_id],
        checks: [
          {name: "Task 1: VM", status: "passed", detail: "제한 사양과 guest startup readiness"},
          {name: "Task 2: 데이터 디스크", status: "passed", detail: "ext4 UUID mount/fstab와 maintenance 후 유지"},
          {name: "Task 3: 애플리케이션", status: "passed", detail: "고정 JRE/artifact checksum/EULA/systemd"},
          {name: "Task 4: 클라이언트 트래픽", status: "passed", detail: "승인된 IPv4 source의 TCP 25565와 IAP-only SSH, 실제 TCP probe"},
          {name: "Task 5: 백업", status: "passed", detail: "즉시 업로드, hash와 archive 복구성, cron"},
          {name: "Task 6: 유지보수", status: "passed", detail: "shutdown hook과 stop/start 복구"},
          {name: "Task 7: Review", status: "passed", detail: "구조화 machine evidence 생성"}
        ],
        risks: [],
        next_action: "extension_review"
      }' >"$result_file"
    chmod 600 "$result_file"
    printf 'PASS: Phase 06 machine verification 완료\n'
    ;;

  destroy)
    [[ -d "$work_dir" ]] || harness_die "Phase 06 work directory가 없습니다: $work_dir"
    destroy_zone="$(jq -r '.resources[] | select(.kind == "google_compute_instance") | .region' "$manifest_file" | head -n 1)"
    destroy_region="$(jq -r '.resources[] | select(.kind == "google_compute_subnetwork") | .region' "$manifest_file" | head -n 1)"
    [[ -n "$destroy_zone" && -n "$destroy_region" ]] || harness_die "manifest에서 destroy 위치를 결정할 수 없습니다."
    destroy_vars=(-var="project_id=$GCP_PROJECT_ID" -var="run_id=$run_id" -var="region=$destroy_region" -var="zone=$destroy_zone")
    harness_tf_destroy "$work_dir" "${destroy_vars[@]}"
    remaining_count=0
    gcloud compute instances describe "mc-server-$run_id" --zone="$destroy_zone" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining_count++)) || true
    gcloud compute disks describe "mc-server-$run_id" --zone="$destroy_zone" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining_count++)) || true
    gcloud compute disks describe "minecraft-disk-$run_id" --zone="$destroy_zone" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining_count++)) || true
    for address_name in "mc-ip-$run_id" "mc-server-ip-$run_id"; do
      gcloud compute addresses describe "$address_name" --region="$destroy_region" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining_count++)) || true
    done
    gcloud compute networks subnets describe "gcp-lab-p06-subnet-$run_id" --region="$destroy_region" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining_count++)) || true
    for fw_name in "minecraft-iap-ssh-$run_id" "minecraft-rule-$run_id"; do
      gcloud compute firewall-rules describe "$fw_name" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining_count++)) || true
    done
    gcloud storage buckets describe "gs://gcp-lab-p06-backup-$run_id" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining_count++)) || true
    gcloud compute networks describe "gcp-lab-p06-net-$run_id" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining_count++)) || true
    gcloud iam service-accounts describe "p06-${run_id:0:19}@$GCP_PROJECT_ID.iam.gserviceaccount.com" --project="$GCP_PROJECT_ID" >/dev/null 2>&1 && ((remaining_count++)) || true
    [[ "$remaining_count" -eq 0 ]] || {
      harness_manifest_set_status "$manifest_file" "cleanup_required" || true
      harness_die "Phase 06 정리 후 잔여 리소스가 발견되었습니다: ${remaining_count}개"
    }
    tmp_manifest="$(mktemp "$run_dir/manifest.tmp.XXXXXX")"
    jq '.status = "destroyed" | .cleanup.status = "completed" | .cleanup.remaining_resource_count = 0' "$manifest_file" >"$tmp_manifest"
    mv -f "$tmp_manifest" "$manifest_file"
    chmod 600 "$manifest_file"
    printf 'PASS: Phase 06 destroy 및 잔여 리소스 0개 확인 완료\n'
    ;;
esac
