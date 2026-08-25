#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT

printf 'INFO: Phase 04 테스트 시작\n'

# 1. verify.sh --offline 검사
"$repo_root/phases/04/verify.sh" --offline

# 2. phase-gate 검사
"$repo_root/scripts/phase-gate.sh" "$repo_root/docs/phases/phase-04-private-access-nat.md"

# 3. Terraform validate 검사
terraform -chdir="$repo_root/phases/04/terraform" fmt -check
terraform -chdir="$repo_root/phases/04/terraform" init -backend=false -input=false >/dev/null
terraform -chdir="$repo_root/phases/04/terraform" validate

# 4. Phase Manifest Schema 검증
mock_manifest="$test_root/mock-manifest.json"
project_hash="$(printf 'test-project' | sha256sum | awk '{print $1}')"
vpc_hash="$(printf 'privatenet-test' | sha256sum | awk '{print $1}')"
subnet_hash="$(printf 'privatenet-us-test' | sha256sum | awk '{print $1}')"
vm_hash="$(printf 'vm-internal-test' | sha256sum | awk '{print $1}')"
bucket_hash="$(printf 'gcp-lab-p04-test' | sha256sum | awk '{print $1}')"
router_hash="$(printf 'nat-router-test' | sha256sum | awk '{print $1}')"
nat_hash="$(printf 'nat-config-test' | sha256sum | awk '{print $1}')"

jq -n \
  --arg phase "04" \
  --arg run_id "testrun001" \
  --arg project_hash "$project_hash" \
  --arg vpc_hash "$vpc_hash" \
  --arg subnet_hash "$subnet_hash" \
  --arg vm_hash "$vm_hash" \
  --arg bucket_hash "$bucket_hash" \
  --arg router_hash "$router_hash" \
  --arg nat_hash "$nat_hash" \
  '{
    phase: $phase,
    run_id: $run_id,
    project_id_hash: $project_hash,
    status: "verified",
    resources: [
      {kind: "google_compute_network", name_hash: $vpc_hash, region: "global"},
      {kind: "google_compute_subnetwork", name_hash: $subnet_hash, region: "us-central1"},
      {kind: "google_compute_instance", name_hash: $vm_hash, region: "us-central1-c"},
      {kind: "google_storage_bucket", name_hash: $bucket_hash, region: "US"},
      {kind: "google_compute_router", name_hash: $router_hash, region: "us-central1"},
      {kind: "google_compute_router_nat", name_hash: $nat_hash, region: "us-central1"}
    ],
    checks: [
      {id: "task-1-vm-no-external-ip", status: "passed", evidence: "VM network_interface access_config 0개 확인"},
      {id: "task-2-pga-enabled", status: "passed", evidence: "private_ip_google_access = true 확인"},
      {id: "task-3-cloud-nat", status: "passed", evidence: "router_nat nat-config 상태 확인"},
      {id: "task-4-nat-logging", status: "passed", evidence: "log_config filter ALL 확인"},
      {id: "task-5-review", status: "passed", evidence: "Task 1~5 전체 요구사항 검증 완료"}
    ],
    cleanup: {
      status: "completed",
      remaining_resource_count: 0
    }
  }' >"$mock_manifest"

# Schema validation using python jsonschema
python3 -c "
import json, jsonschema

with open('$repo_root/schemas/phase-manifest.schema.json') as sf:
    schema = json.load(sf)
with open('$mock_manifest') as mf:
    manifest = json.load(mf)

jsonschema.validate(instance=manifest, schema=schema)
print('PASS: Phase 04 manifest JSON Schema 검증 통과')
"

# 5. Command Code Result Schema 검증
mock_result="$test_root/mock-result.json"
jq -n \
  --arg phase "phase-04" \
  --arg session_id "gcp-harness-testrun001-phase-04" \
  '{
    phase: $phase,
    status: "waiting_extension_review",
    summary: "Phase 04 Private Google Access 및 Cloud NAT 배포 검증 완료",
    session_id: $session_id,
    commands_run: [
      "terraform apply",
      "phases/04/verify.sh --run testrun001"
    ],
    checks: [
      {name: "Task 1: VM 인스턴스 외부 IP 없음 검증", status: "passed", detail: "vm-internal에 외부 IP 없음"},
      {name: "Task 2: Private Google Access 활성화 검증", status: "passed", detail: "PGA 활성화 확인"},
      {name: "Task 3: Cloud NAT 게이트웨이 구성 검증", status: "passed", detail: "Cloud NAT 정상 동작"},
      {name: "Task 4: Cloud NAT Logging 구성 검증", status: "passed", detail: "로깅 활성화 확인"},
      {name: "Task 5: Review", status: "passed", detail: "전체 검증 완료"}
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
print('PASS: Phase 04 Command Code result JSON Schema 검증 통과')
"

printf 'PASS: Phase 04 전체 테스트 성공\n'
