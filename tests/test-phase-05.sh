#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT

printf 'INFO: Phase 05 테스트 시작\n'

# 1. verify.sh --offline 검사
"$repo_root/phases/05/verify.sh" --offline

# 2. phase-gate 검사
"$repo_root/scripts/phase-gate.sh" "$repo_root/docs/phases/phase-05-creating-vms.md"

# 3. Terraform validate 검사
terraform -chdir="$repo_root/phases/05/terraform" fmt -check
terraform -chdir="$repo_root/phases/05/terraform" init -backend=false -input=false >/dev/null
terraform -chdir="$repo_root/phases/05/terraform" validate

# 4. Phase Manifest Schema 검증
mock_manifest="$test_root/mock-manifest.json"
project_hash="$(printf 'test-project' | sha256sum | awk '{print $1}')"
vpc_hash="$(printf 'gcp-lab-p05-net-test' | sha256sum | awk '{print $1}')"
subnet_hash="$(printf 'gcp-lab-p05-subnet-test' | sha256sum | awk '{print $1}')"
u_vm_hash="$(printf 'utility-vm-test' | sha256sum | awk '{print $1}')"
w_vm_hash="$(printf 'windows-vm-test' | sha256sum | awk '{print $1}')"
c_vm_hash="$(printf 'custom-vm-test' | sha256sum | awk '{print $1}')"

jq -n \
  --arg phase "05" \
  --arg run_id "testrun005" \
  --arg project_hash "$project_hash" \
  --arg vpc_hash "$vpc_hash" \
  --arg subnet_hash "$subnet_hash" \
  --arg u_vm_hash "$u_vm_hash" \
  --arg w_vm_hash "$w_vm_hash" \
  --arg c_vm_hash "$c_vm_hash" \
  '{
    phase: $phase,
    run_id: $run_id,
    project_id_hash: $project_hash,
    status: "verified",
    resources: [
      {kind: "google_compute_network", name_hash: $vpc_hash, region: "global"},
      {kind: "google_compute_subnetwork", name_hash: $subnet_hash, region: "us-central1"},
      {kind: "google_compute_instance", name_hash: $u_vm_hash, region: "us-central1-c"},
      {kind: "google_compute_instance", name_hash: $w_vm_hash, region: "us-central1-c"},
      {kind: "google_compute_instance", name_hash: $c_vm_hash, region: "us-central1-c"}
    ],
    checks: [
      {id: "task-1-utility-vm", status: "passed", evidence: "utility-vm e2-medium 외부 IP 없음 확인"},
      {id: "task-2-windows-vm", status: "passed", evidence: "windows-vm e2-standard-2 64GB SSD 확인"},
      {id: "task-3-custom-vm", status: "passed", evidence: "custom-vm e2-custom-2-4096 확인"},
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
print('PASS: Phase 05 manifest JSON Schema 검증 통과')
"

# 5. Command Code Result Schema 검증
mock_result="$test_root/mock-result.json"
jq -n \
  --arg phase "phase-05" \
  --arg session_id "gcp-harness-testrun005-phase-05" \
  '{
    phase: $phase,
    status: "waiting_extension_review",
    summary: "Phase 05 Virtual Machines 생성 검증 완료",
    session_id: $session_id,
    commands_run: [
      "terraform apply",
      "phases/05/verify.sh --run testrun005"
    ],
    checks: [
      {name: "Task 1: 유틸리티 VM 생성", status: "passed", detail: "utility-vm e2-medium 및 외부 IP 없음 확인 완료"},
      {name: "Task 2: Windows VM 생성", status: "passed", detail: "windows-vm e2-standard-2 및 64GB SSD 확인 완료"},
      {name: "Task 3: 커스텀 VM 생성", status: "passed", detail: "custom-vm e2-custom-2-4096 확인 완료"},
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
print('PASS: Phase 05 Command Code result JSON Schema 검증 통과')
"

printf 'PASS: Phase 05 전체 테스트 성공\n'
