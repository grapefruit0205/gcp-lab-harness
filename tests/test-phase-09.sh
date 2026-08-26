#!/usr/bin/env bash
set -Eeuo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for script in "$repo_root/phases/09"/{execute,verify,support,recovery}.sh "$0"; do bash -n "$script"; done
python3 "$repo_root/tests/test-phase-09.py"
terraform -chdir="$repo_root/phases/09/terraform" fmt -check -recursive
terraform -chdir="$repo_root/phases/09/terraform" init -backend=false -input=false >/dev/null
terraform -chdir="$repo_root/phases/09/terraform" validate
terraform -chdir="$repo_root/phases/09/terraform" test -json -verbose |
  python3 "$repo_root/tests/test-phase-09.py" --terraform-plans
printf 'PASS: Phase09 local tests·Terraform mock·plan guard (Cloud 미사용)\n'
