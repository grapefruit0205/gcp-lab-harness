#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT

printf 'INFO: Phase 02 테스트 시작\n'

# 1. verify.sh --offline 검사
"$repo_root/phases/02/verify.sh" --offline

# 2. phase-gate 검사
"$repo_root/scripts/phase-gate.sh" "$repo_root/docs/phases/phase-02-infrastructure-preview.md"

# 3. Terraform validate 검사
terraform -chdir="$repo_root/phases/02/terraform" fmt -check
terraform -chdir="$repo_root/phases/02/terraform" init -backend=false -input=false >/dev/null
terraform -chdir="$repo_root/phases/02/terraform" validate

# 4. Phase Manifest Schema 검증
mock_manifest="$test_root/mock-manifest.json"
project_hash="$(printf 'test-project' | sha256sum | awk '{print $1}')"
vpc_hash="$(printf 'gcp-lab-p02-net-test' | sha256sum | awk '{print $1}')"
subnet_hash="$(printf 'gcp-lab-p02-subnet-test' | sha256sum | awk '{print $1}')"
vm_hash="$(printf 'jenkins-1-vm-test' | sha256sum | awk '{print $1}')"
fw_hash="$(printf 'gcp-lab-p02-fw-test' | sha256sum | awk '{print $1}')"

jq -n \
  --arg phase "02" \
  --arg run_id "testrun002" \
  --arg project_hash "$project_hash" \
  --arg vpc_hash "$vpc_hash" \
  --arg subnet_hash "$subnet_hash" \
  --arg vm_hash "$vm_hash" \
  --arg fw_hash "$fw_hash" \
  '{
    phase: $phase,
    run_id: $run_id,
    project_id_hash: $project_hash,
    status: "verified",
    resources: [
      {kind: "google_compute_network", name_hash: $vpc_hash, region: "global"},
      {kind: "google_compute_subnetwork", name_hash: $subnet_hash, region: "us-central1"},
      {kind: "google_compute_firewall", name_hash: $fw_hash, region: "global"},
      {kind: "google_compute_instance", name_hash: $vm_hash, region: "us-central1-c"}
    ],
    checks: [
      {id: "task-1-marketplace-deploy", status: "passed", evidence: "click-to-deploy-images 이미지 배포 확인"},
      {id: "task-2-inspect-deployment", status: "passed", evidence: "VM 및 네트워크 상태 확인"},
      {id: "task-3-manage-service", status: "passed", evidence: "서비스 관리 포트 확인"},
      {id: "task-4-review", status: "passed", evidence: "Task 1~4 전체 검증 완료"}
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
print('PASS: Phase 02 manifest JSON Schema 검증 통과')
"

# 5. Command Code Result Schema 검증
mock_result="$test_root/mock-result.json"
jq -n \
  --arg phase "phase-02" \
  --arg session_id "gcp-harness-testrun002-phase-02" \
  '{
    phase: $phase,
    status: "waiting_extension_review",
    summary: "Phase 02 Marketplace Jenkins 배포 검증 완료",
    session_id: $session_id,
    commands_run: [
      "terraform apply",
      "phases/02/verify.sh --run testrun002"
    ],
    checks: [
      {name: "Task 1: Marketplace Jenkins 배포 구축", status: "passed", detail: "click-to-deploy-images 기반 배포 완료"},
      {name: "Task 2: 배포 살펴보기", status: "passed", detail: "e2-standard-2 및 네트워크 구성 확인 완료"},
      {name: "Task 3: 서비스 관리하기", status: "passed", detail: "SSH 및 Jenkins 포트 방화벽 확인 완료"},
      {name: "Task 4: Review", status: "passed", detail: "전체 검증 완료"}
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
print('PASS: Phase 02 Command Code result JSON Schema 검증 통과')
"

printf 'PASS: Phase 02 전체 테스트 성공\n'
