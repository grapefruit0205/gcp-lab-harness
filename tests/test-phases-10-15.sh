#!/usr/bin/env bash
set -Eeuo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 "$repo_root/tests/test-phases-10-15.py"
bash -n "$repo_root/lib/harness/safe-adapter.sh" "$0"
for phase in 10 11 12 13 14 15; do
  bash -n "$repo_root/phases/$phase/execute.sh" "$repo_root/phases/$phase/verify.sh"
  terraform -chdir="$repo_root/phases/$phase/terraform" fmt -check -recursive
  terraform -chdir="$repo_root/phases/$phase/terraform" init -backend=false -input=false -lockfile=readonly >/dev/null
  terraform -chdir="$repo_root/phases/$phase/terraform" validate
  terraform -chdir="$repo_root/phases/$phase/terraform" test
  "$repo_root/phases/$phase/verify.sh" --offline
done
printf 'PASS: Phase10–15 회귀·Bash·Terraform validate (Cloud 미사용)\n'
