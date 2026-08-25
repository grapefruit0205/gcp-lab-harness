#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT

printf 'INFO: Phase 06 테스트 시작\n'

# 1. verify.sh --offline 검사
"$repo_root/phases/06/verify.sh" --offline

# 2. phase-gate 검사
"$repo_root/scripts/phase-gate.sh" "$repo_root/docs/phases/phase-06-working-vms.md"

# 3. Terraform validate 검사
terraform -chdir="$repo_root/phases/06/terraform" fmt -check
terraform -chdir="$repo_root/phases/06/terraform" init -backend=false -input=false >/dev/null
terraform -chdir="$repo_root/phases/06/terraform" validate

# 4. Phase Manifest Schema 검증
mock_manifest="$test_root/mock-manifest.json"
project_hash="$(printf 'test-project' | sha256sum | awk '{print $1}')"
vpc_hash="$(printf 'gcp-lab-p06-net-test' | sha256sum | awk '{print $1}')"
subnet_hash="$(printf 'gcp-lab-p06-subnet-test' | sha256sum | awk '{print $1}')"
vm_hash="$(printf 'mc-server-test' | sha256sum | awk '{print $1}')"
disk_hash="$(printf 'minecraft-disk-test' | sha256sum | awk '{print $1}')"
bucket_hash="$(printf 'gcp-lab-p06-backup-test' | sha256sum | awk '{print $1}')"

jq -n \
  --arg phase "06" \
  --arg run_id "testrun006" \
  --arg project_hash "$project_hash" \
  --arg vpc_hash "$vpc_hash" \
  --arg subnet_hash "$subnet_hash" \
  --arg vm_hash "$vm_hash" \
  --arg disk_hash "$disk_hash" \
  --arg bucket_hash "$bucket_hash" \
  '{
    phase: $phase,
    run_id: $run_id,
    project_id_hash: $project_hash,
    status: "verified",
    resources: [
      {kind: "google_compute_network", name_hash: $vpc_hash, region: "global"},
      {kind: "google_compute_subnetwork", name_hash: $subnet_hash, region: "us-central1"},
      {kind: "google_compute_disk", name_hash: $disk_hash, region: "us-central1-c"},
      {kind: "google_compute_instance", name_hash: $vm_hash, region: "us-central1-c"},
      {kind: "google_storage_bucket", name_hash: $bucket_hash, region: "US"}
    ],
    checks: [
      {id: "task-1-vm-create", status: "passed", evidence: "mc-server e2-medium 정적 IP 확인"},
      {id: "task-2-data-disk", status: "passed", evidence: "50GB SSD minecraft-disk 확인"},
      {id: "task-3-app-install", status: "passed", evidence: "Minecraft 환경 확인"},
      {id: "task-4-client-traffic", status: "passed", evidence: "TCP 25565 방화벽 확인"},
      {id: "task-5-backup-schedule", status: "passed", evidence: "백업 버킷 확인"},
      {id: "task-6-maintenance", status: "passed", evidence: "유지보수 관리 확인"},
      {id: "task-7-review", status: "passed", evidence: "Task 1~7 전체 검증 완료"}
    ],
    cleanup: {
      status: "completed",
      remaining_resource_count: 0
    }
  }' >"$mock_manifest"

python3 -c "
import json, jsonschema

with open('$repo_root/schemas/phase-manifest.schema.json') as sf:
    schema = json.load(sf)
with open('$mock_manifest') as mf:
    manifest = json.load(mf)

jsonschema.validate(instance=manifest, schema=schema)
print('PASS: Phase 06 manifest JSON Schema 검증 통과')
"

# 5. Command Code Result Schema 검증
mock_result="$test_root/mock-result.json"
jq -n \
  --arg phase "phase-06" \
  --arg session_id "gcp-harness-testrun006-phase-06" \
  '{
    phase: $phase,
    status: "waiting_extension_review",
    summary: "Phase 06 Working with Virtual Machines 배포 검증 완료",
    session_id: $session_id,
    commands_run: [
      "terraform apply",
      "phases/06/verify.sh --run testrun006"
    ],
    checks: [
      {name: "Task 1: VM 생성 검증", status: "passed", detail: "mc-server e2-medium 및 정적 IP 할당 확인 완료"},
      {name: "Task 2: 데이터 디스크 준비 검증", status: "passed", detail: "50GB SSD minecraft-disk 연결 확인 완료"},
      {name: "Task 3: 애플리케이션 환경 검증", status: "passed", detail: "Minecraft 실행 환경 및 권한 확인 완료"},
      {name: "Task 4: 클라이언트 트래픽 허용 검증", status: "passed", detail: "TCP 25565 방화벽 규칙 확인 완료"},
      {name: "Task 5: 정기 백업 구성 검증", status: "passed", detail: "Cloud Storage 백업 버킷 확인 완료"},
      {name: "Task 6: 서버 유지보수 검증", status: "passed", detail: "유지보수 및 생명주기 관리 구성 확인 완료"},
      {name: "Task 7: Review", status: "passed", detail: "전체 검증 완료"}
    ],
    risks: [],
    next_action: "extension_review"
  }' >"$mock_result"

python3 -c "
import json, jsonschema

with open('$repo_root/schemas/command-code-phase-result.schema.json') as sf:
    schema = json.load(sf)
with open('$mock_result') as rf:
    result = json.load(rf)

jsonschema.validate(instance=result, schema=schema)
print('PASS: Phase 06 Command Code result JSON Schema 검증 통과')
"

printf 'PASS: Phase 06 전체 테스트 성공\n'
