# PRODUCT TRUTH — gcp-lab-harness

Rule: every entry carries evidence (code path, test, screenshot), a date, and the date it was last checked against the code. External claims may be sourced **only** from the Implemented section. Re-confirm any entry checked more than 90 days ago before using it in a claim. Code states are never blended: implemented / wired / operational / verified (see the ballast proof-standard skill).

## Implemented

<!-- ## <capability> — <state: implemented|wired|operational|verified> — 2026-08-25
Evidence: <code path / test / screenshot>
Checked: 2026-08-25 — re-confirm against the code once this is over 90 days old -->

## 15개 Phase 설계와 원본 Task coverage — state: verified — 2026-08-25

Evidence: `docs/phases/phase-01-*.md`부터 `phase-15-*.md`, `references/google-cloud-labs-ko/`, `scripts/validate-design.sh`의 PASS
Checked: 2026-08-25 — 원본별 Task 수와 Phase coverage 행 수 일치, Google Cloud 계정에는 실행하지 않음

## Command Code·Extension handoff 골격 — state: implemented — 2026-08-25

Evidence: `scripts/handoff-execute.sh`, `scripts/prepare-extension-review.sh`, `prompts/phase-execute.md`, `prompts/phase-review.md`, `schemas/`
Checked: 2026-08-25 — Bash·정적 정책 검사 통과, 실제 GCP Phase handoff는 미실행

## 단일 실행 dry-run — state: verified — 2026-08-25

Evidence: `bin/gcp-lab-harness`, `scripts/run-all.sh`; `./scripts/run-all.sh --dry-run`이 Phase 01–15 순서를 출력하고 외부 변경 없이 종료
Checked: 2026-08-25

## Phase 시작 전 fast-forward-only 동기화 보호 — state: implemented — 2026-08-25

Evidence: `scripts/sync-before-phase.sh`, `scripts/validate-design.sh`; dirty working tree fixture가 pull 전에 거부됨
Checked: 2026-08-25 — 실제 origin pull은 GitHub 저장소 생성 전이라 미실행

## 로컬 Git 초기 커밋 — state: verified — 2026-08-25

Evidence: `git log -1 --format='%h %s'`가 한국어 root commit을 반환하고 working tree가 clean함
Checked: 2026-08-25 — GitHub remote와 push는 아직 없음

## GitHub private 저장소 — state: operational — 2026-08-25

Evidence: `https://github.com/grapefruit0205/gcp-lab-harness`가 private 빈 저장소로 생성됐고 로컬 `origin`이 repo 전용 SSH host alias를 가리킴
Checked: 2026-08-25 — deploy key 등록과 최초 push는 사용자 승인 대기

## Not implemented

<!-- Listed explicitly so absence is a fact, not a gap. Copy must not claim these.
Checked: 2026-08-25 — this section goes stale in the other direction: a line left here after the
capability shipped makes you claim less than you have earned. Sweep it on the same 90-day clock. -->

- Google Cloud 리소스 plan/apply/verify/destroy adapter
- 실제 `run-all` 상태 영속화·승인 대기·자동 resume controller
- Google Cloud 계정 통합 테스트
- 전체 15개 Lab E2E 실행
- GitHub 최초 push
- 실제 GitHub origin을 대상으로 한 pull

## Permanently excluded

<!-- Decided against. Copy must never imply these. Link the ledger decision: D-### -->
