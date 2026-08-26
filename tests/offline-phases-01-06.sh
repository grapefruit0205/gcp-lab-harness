#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for phase in 01 02 03 04 05 06; do
  "$repo_root/phases/$phase/verify.sh" --offline
done

# Phase 06의 명시적 공개 예외는 해당 verifier의 plan/live 정책과 mock test로 검사한다.
if grep -rnF 'source_ranges = ["0.0.0.0/0"]' "$repo_root/phases"/{01,02,03,04,05}/terraform >/dev/null; then
  printf 'FAIL: Phase 01–05에 public 전체 ingress가 있습니다.\n' >&2
  exit 1
fi

if grep -rnF 'scopes = ["cloud-platform"]' "$repo_root/phases"/{01,02,03,04,05,06}/terraform >/dev/null; then
  printf 'FAIL: Phase 01–06 VM에 cloud-platform scope가 있습니다.\n' >&2
  exit 1
fi

for phase in 01 02 03 04 05 06; do
  grep -Fq 'status: "pending"' "$repo_root/phases/$phase/execute.sh" || {
    printf 'FAIL: Phase %s plan check가 pending으로 시작하지 않습니다.\n' "$phase" >&2
    exit 1
  }
done

printf 'PASS: Phase 01–06 offline 계약 검증 완료\n'
