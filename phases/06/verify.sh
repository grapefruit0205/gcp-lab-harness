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

verify_offline() {
  bash -n "$phase_dir/execute.sh" "$phase_dir/verify.sh"
  terraform -chdir="$phase_dir/terraform" fmt -check >/dev/null
  terraform -chdir="$phase_dir/terraform" init -backend=false -input=false >/dev/null
  terraform -chdir="$phase_dir/terraform" validate >/dev/null
  for token in \
    "Task 1. VM 생성하기" \
    "Task 2. 데이터 디스크 준비하기" \
    "Task 3. 애플리케이션 설치 및 실행하기" \
    "Task 4. 클라이언트 트래픽 허용하기" \
    "Task 5. 정기 백업 예약하기" \
    "Task 6. 서버 유지보수하기" \
    "Task 7. Review"; do
    grep -Fq "$token" "$repo_root/docs/phases/phase-06-working-vms.md" || harness_die "Phase 06 문서 필수 항목 누락: $token"
  done
  for token in \
    'minecraft_server_sha256' \
    'minecraft_eula_accepted' \
    'mkfs.ext4' \
    'blkid -s UUID' \
    'minecraft.service' \
    'minecraft-backup' \
    'shutdown-script'; do
    grep -Fq "$token" "$phase_dir/terraform/main.tf" || harness_die "Phase 06 guest 계약 누락: $token"
  done
  ! grep -Fq 'source_ranges = ["0.0.0.0/0"]' "$phase_dir/terraform/main.tf" || harness_die "Phase 06에 public 전체 ingress가 있습니다."
  printf 'PASS: Phase 06 offline 계약 검증 완료\n'
}

verify_cloud() {
  harness_validate_run_id "$run_id"
  "$repo_root/scripts/preflight-gcp.sh" >/dev/null
  harness_load_config "$repo_root/config/harness.env"

  local run_dir="$repo_root/artifacts/runs/$run_id/phase-06"
  local manifest_file="$run_dir/manifest.json"
  local tfvars_file="$run_dir/work/phase-06.auto.tfvars.json"
  local evidence_dir="$run_dir/evidence"
  local evidence_file="$evidence_dir/phase-06-machine.json"
  local vm_name="mc-server-$run_id"
  local disk_name="minecraft-disk-$run_id"
  local bucket_name="gcp-lab-p06-backup-$run_id"
  local app_fw_name="minecraft-rule-$run_id"
  local ssh_fw_name="minecraft-iap-ssh-$run_id"

  harness_manifest_require_status "$manifest_file" "applied"
  harness_require_file "$tfvars_file" "Phase 06 고정 입력" || return
  mkdir -p "$evidence_dir"
  chmod 700 "$evidence_dir"

  guest() {
    local command="$1"
    timeout 90 gcloud compute ssh "$vm_name" \
      --zone="$GCP_ZONE" \
      --project="$GCP_PROJECT_ID" \
      --tunnel-through-iap \
      --quiet \
      --command="$command"
  }
  guest_ready() {
    local value
    value="$(gcloud compute instances get-guest-attributes "$vm_name" \
      --zone="$GCP_ZONE" \
      --project="$GCP_PROJECT_ID" \
      --query-path='gcp-lab-harness/readiness' \
      --format='value(queryValue.items[0].value)' 2>/dev/null || true)"
    [[ "$value" == "ready" ]]
  }
  app_ready() {
    guest 'sudo systemctl is-active --quiet minecraft.service && sudo ss -ltn | grep -Eq "[:.]25565[[:space:]]"' >/dev/null 2>&1
  }

  if ! harness_wait_until 1200 15 guest_ready; then
    harness_die "startup script가 제한 시간 안에 readiness를 보고하지 않았습니다."
  fi
  if ! harness_wait_until 300 10 app_ready; then
    harness_die "Minecraft systemd service 또는 TCP 25565가 ready가 아닙니다."
  fi

  local vm_json disk_json bucket_json app_fw_json ssh_fw_json
  vm_json="$(gcloud compute instances describe "$vm_name" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" --format=json)"
  disk_json="$(gcloud compute disks describe "$disk_name" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" --format=json)"
  bucket_json="$(gcloud storage buckets describe "gs://$bucket_name" --project="$GCP_PROJECT_ID" --format=json)"
  app_fw_json="$(gcloud compute firewall-rules describe "$app_fw_name" --project="$GCP_PROJECT_ID" --format=json)"
  ssh_fw_json="$(gcloud compute firewall-rules describe "$ssh_fw_name" --project="$GCP_PROJECT_ID" --format=json)"
  jq -e '.status == "RUNNING" and (.machineType | endswith("/e2-medium"))' <<<"$vm_json" >/dev/null || harness_die "VM 상태 또는 machine type 불일치"
  jq -e '.sizeGb >= 50 and (.type | endswith("/pd-ssd"))' <<<"$disk_json" >/dev/null || harness_die "data disk 크기 또는 type 불일치"
  jq -e '.iamConfiguration.publicAccessPrevention == "enforced" and .iamConfiguration.uniformBucketLevelAccess.enabled == true' <<<"$bucket_json" >/dev/null || harness_die "backup bucket 비공개 정책 불일치"
  jq -e '.sourceRanges | length == 1 and .[0] != "0.0.0.0/0" and .[0] != "::/0"' <<<"$app_fw_json" >/dev/null || harness_die "Minecraft firewall source가 제한되지 않았습니다."
  jq -e '.sourceRanges == ["35.235.240.0/20"]' <<<"$ssh_fw_json" >/dev/null || harness_die "SSH firewall가 IAP-only가 아닙니다."
  [[ "$(jq -r '.sourceRanges[0]' <<<"$app_fw_json")" == "$(jq -r '.client_source_cidr' "$tfvars_file")" ]] || harness_die "실제 client CIDR가 승인 입력과 다릅니다."

  local before_state
  before_state="$(guest 'set -eu; source_dev=$(findmnt -n -o SOURCE /srv/minecraft); uuid=$(sudo blkid -s UUID -o value "$source_dev"); fstype=$(findmnt -n -o FSTYPE /srv/minecraft); grep -Fq "UUID=$uuid /srv/minecraft ext4" /etc/fstab; systemctl is-active --quiet minecraft.service; test -f /srv/minecraft/world/level.dat; test -x /usr/local/sbin/minecraft-backup; grep -Fq /usr/local/sbin/minecraft-backup /etc/cron.d/minecraft-backup; artifact=$(sha256sum /srv/minecraft/server.jar | awk "{print \$1}"); jre=$(dpkg-query -W -f="\${Version}" openjdk-17-jre-headless); boot=$(cat /var/lib/gcp-lab-harness/boot-count); printf "%s|%s|%s|%s|%s" "$uuid" "$fstype" "$artifact" "$jre" "$boot"')"
  IFS='|' read -r before_uuid before_fstype artifact_sha jre_version before_boot <<<"$before_state"
  [[ "$before_uuid" =~ ^[A-Fa-f0-9-]+$ && "$before_fstype" == "ext4" ]] || harness_die "data disk UUID/filesystem/mount 검사 실패"
  [[ "$artifact_sha" == "$(jq -r '.minecraft_server_sha256' "$tfvars_file")" ]] || harness_die "guest server artifact checksum 불일치"
  [[ "$jre_version" == "$(jq -r '.jre_package_version' "$tfvars_file")" ]] || harness_die "guest JRE package version 불일치"
  [[ "$before_boot" =~ ^[0-9]+$ ]] || harness_die "guest boot count 증거가 유효하지 않습니다."

  local public_ip
  public_ip="$(jq -r '.networkInterfaces[0].accessConfigs[0].natIP // empty' <<<"$vm_json")"
  [[ "$public_ip" =~ ^[0-9a-fA-F:.]+$ ]] || harness_die "외부 TCP probe 대상 IP가 유효하지 않습니다."
  timeout 15 bash -c "</dev/tcp/$public_ip/25565" || harness_die "외부 client TCP 25565 probe가 실패했습니다."

  local backup_object backup_tmp archive_file digest_file expected_digest actual_digest
  backup_object="$(guest 'sudo /usr/local/sbin/minecraft-backup')"
  [[ "$backup_object" =~ ^backups/minecraft-[0-9]{8}T[0-9]{6}Z\.tar\.gz$ ]] || harness_die "backup script가 유효한 object name을 반환하지 않았습니다."
  backup_tmp="$(mktemp -d)"
  trap 'rm -rf -- "$backup_tmp"' RETURN
  archive_file="$backup_tmp/archive.tar.gz"
  digest_file="$backup_tmp/archive.sha256"
  timeout 300 gcloud storage cp "gs://$bucket_name/$backup_object" "$archive_file" >/dev/null
  timeout 300 gcloud storage cp "gs://$bucket_name/$backup_object.sha256" "$digest_file" >/dev/null
  expected_digest="$(tr -d '[:space:]' <"$digest_file")"
  actual_digest="$(sha256sum "$archive_file" | awk '{print $1}')"
  [[ "$expected_digest" == "$actual_digest" ]] || harness_die "backup object와 sidecar hash가 일치하지 않습니다."
  tar -tzf "$archive_file" >/dev/null || harness_die "backup archive를 복구 가능한 tar로 읽을 수 없습니다."
  rm -rf -- "$backup_tmp"
  trap - RETURN

  timeout 600 gcloud compute instances stop "$vm_name" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" --quiet >/dev/null
  timeout 600 gcloud compute instances start "$vm_name" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" --quiet >/dev/null
  if ! harness_wait_until 1200 15 app_ready; then
    harness_die "maintenance stop/start 후 Minecraft service가 복구되지 않았습니다."
  fi
  local after_state shutdown_value
  after_state="$(guest 'set -eu; source_dev=$(findmnt -n -o SOURCE /srv/minecraft); uuid=$(sudo blkid -s UUID -o value "$source_dev"); systemctl is-active --quiet minecraft.service; test -f /srv/minecraft/world/level.dat; printf "%s|%s" "$uuid" "$(cat /var/lib/gcp-lab-harness/boot-count)"')"
  IFS='|' read -r after_uuid after_boot <<<"$after_state"
  [[ "$after_uuid" == "$before_uuid" ]] || harness_die "maintenance 전후 data disk UUID가 다릅니다."
  [[ "$after_boot" =~ ^[0-9]+$ && "$after_boot" -gt "$before_boot" ]] || harness_die "maintenance 후 startup script 재실행 증거가 없습니다."
  shutdown_value="$(gcloud compute instances get-guest-attributes "$vm_name" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" --query-path='gcp-lab-harness/shutdown' --format='value(queryValue.items[0].value)' 2>/dev/null || true)"
  [[ "$shutdown_value" == "observed" ]] || harness_die "shutdown hook 실행 증거가 없습니다."
  timeout 15 bash -c "</dev/tcp/$public_ip/25565" || harness_die "maintenance 후 외부 TCP probe가 복구되지 않았습니다."

  jq -n \
    --arg phase "06" \
    --arg run_id "$run_id" \
    --arg disk_uuid_hash "$(printf '%s' "$before_uuid" | sha256sum | awk '{print $1}')" \
    --arg artifact_sha "$artifact_sha" \
    --arg jre_version "$jre_version" \
    --arg backup_sha "$actual_digest" \
    --arg backup_object_hash "$(printf '%s' "$backup_object" | sha256sum | awk '{print $1}')" \
    --arg public_ip_hash "$(printf '%s' "$public_ip" | sha256sum | awk '{print $1}')" \
    --argjson before_boot "$before_boot" \
    --argjson after_boot "$after_boot" '
    {
      phase: $phase,
      run_id: $run_id,
      checks: {
        disk_uuid_mount_fstab: "passed",
        artifact_checksum_eula_systemd: "passed",
        external_tcp_probe: "passed",
        backup_hash_and_recoverability: "passed",
        cron_registered: "passed",
        shutdown_startup_hooks: "passed",
        maintenance_recovery: "passed"
      },
      disk_uuid_sha256: $disk_uuid_hash,
      artifact_sha256: $artifact_sha,
      jre_package_version: $jre_version,
      backup_sha256: $backup_sha,
      backup_object_name_sha256: $backup_object_hash,
      external_ip_sha256: $public_ip_hash,
      boot_count_before: $before_boot,
      boot_count_after: $after_boot
    }' >"$evidence_file"
  chmod 600 "$evidence_file"
  printf 'PASS: Phase 06 disk·app·traffic·backup·maintenance 실제 동작 검증 완료\n'
}

if [[ "$mode" == "offline" ]]; then
  verify_offline
else
  verify_cloud
fi
