#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

mapfile -t phase_files < <(find docs/phases -maxdepth 1 -type f -name 'phase-[0-9][0-9]-*.md' | sort)
if [[ "${#phase_files[@]}" -ne 15 ]]; then
  printf 'FAIL: Phase 문서는 15개여야 하지만 %s개입니다.\n' "${#phase_files[@]}" >&2
  exit 1
fi

required_headings=(
  '## 목적'
  '## 범위와 원본 매핑'
  '## 구현 작업'
  '## 실행 계약'
  '## 검증 게이트'
  '## 안전·비용 가드레일'
  '## 완료 조건'
  '## Command Code·Extension handoff 지시'
  '## Git 종료 조건'
)

for phase_file in "${phase_files[@]}"; do
  for heading in "${required_headings[@]}"; do
    if ! grep -Fqx "$heading" "$phase_file"; then
      printf 'FAIL: %s에 필수 제목이 없습니다: %s\n' "$phase_file" "$heading" >&2
      exit 1
    fi
  done
done

mapfile -t actual_numbers < <(printf '%s\n' "${phase_files[@]}" | sed -E 's#.*phase-([0-9]{2})-.*#\1#')
mapfile -t expected_numbers < <(seq -w 1 15)
if [[ "${actual_numbers[*]}" != "${expected_numbers[*]}" ]]; then
  printf 'FAIL: Phase 번호는 01부터 15까지 연속이어야 합니다. 현재: %s\n' "${actual_numbers[*]}" >&2
  exit 1
fi

if grep -E -- '--(model|effort)([=[:space:]]|$)' \
  scripts/handoff-execute.sh \
  scripts/start-command-code.sh \
  scripts/handoff-next.sh >/dev/null; then
  printf 'FAIL: cmd 실행 스크립트는 --model 또는 --effort를 전달하면 안 됩니다.\n' >&2
  exit 1
fi

if ! grep -Fq 'git pull --ff-only origin "$branch"' scripts/sync-before-phase.sh; then
  printf 'FAIL: Phase 동기화는 git pull --ff-only만 사용해야 합니다.\n' >&2
  exit 1
fi

jq empty schemas/*.json
bash -n scripts/*.sh
bash -n bin/gcp-lab-harness
bash -n lib/harness/*.sh
bash -n tests/*.sh
terraform fmt -check -recursive foundation/terraform
terraform -chdir=foundation/terraform/account-check init -backend=false -input=false >/dev/null
terraform -chdir=foundation/terraform/account-check validate
git diff --check
printf 'PASS: Phase 15개, cmd 고정 모델 상속, JSON Schema, Bash 문법, whitespace를 확인했습니다.\n'
