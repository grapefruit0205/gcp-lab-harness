#!/usr/bin/env bash
set -Eeuo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for script in "$repo_root/phases/08"/{execute,verify,support}.sh "$0"; do bash -n "$script"; done
python3 "$repo_root/tests/test-phase-08.py"
terraform -chdir="$repo_root/phases/08/terraform" fmt -check -recursive
terraform -chdir="$repo_root/phases/08/terraform" init -backend=false -input=false >/dev/null
terraform -chdir="$repo_root/phases/08/terraform" validate
terraform -chdir="$repo_root/phases/08/terraform" test -json -verbose |
  python3 "$repo_root/tests/test-phase-08.py" --terraform-plans
printf 'PASS: Phase 08 회귀·Terraform mock·실제 plan JSON guard 검증 완료 (Cloud 미사용)\n'
