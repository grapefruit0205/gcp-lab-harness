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

## Foundation B 상태·승인 컨트롤러 — state: verified — 2026-08-25

Evidence: `lib/harness/`, `schemas/pipeline-state.schema.json`, `tests/offline-controller.sh`; offline test PASS
Checked: 2026-08-25 — 15개 Phase 초기화, 허용/금지 전이, stale approval 거부, 승인·반려, resume를 확인했으며 Cloud에는 실행하지 않음

## Foundation A 도구·GCP 계정 preflight — state: verified — 2026-08-25

Evidence: `scripts/install-toolchain.sh`, `config/toolchain.lock.env`, `scripts/gcp-auth-login.sh`, `scripts/configure-gcp-project.sh`, `scripts/preflight-gcp.sh`; 설치 재실행과 실제 계정 preflight PASS
Checked: 2026-08-25 — gcloud 581.0.0, Terraform 1.15.8, 사용자 로그인·ADC, 단일 project allowlist와 billing 연결을 로컬에서 확인함. 실제 계정 식별자는 Git에 저장하지 않음

## Terraform Google provider 계정 연결 — state: verified — 2026-08-25

Evidence: `foundation/terraform/account-check/`, provider lock, `scripts/verify-terraform-gcp.sh`; provider 7.45.0 refresh-only plan PASS
Checked: 2026-08-25 — ADC로 허용 프로젝트 data source 조회에 성공했으며 Cloud resource apply는 하지 않음

## Phase 시작 전 fast-forward-only 동기화 보호 — state: verified — 2026-08-25

Evidence: `scripts/sync-before-phase.sh`, `scripts/validate-design.sh`; dirty tree 거부와 실제 `origin/main`의 `Already up to date` 결과
Checked: 2026-08-25 — local/remote SHA `6f0ca8e2d83b428cf8a6fc469e4c670f75186704` 일치 후 실행

## 로컬 Git 초기 커밋 — state: verified — 2026-08-25

Evidence: `git log -1 --format='%h %s'`가 한국어 root commit을 반환하고 working tree가 clean함
Checked: 2026-08-25 — GitHub `origin/main`에 포함됨

## GitHub public 저장소 — state: verified — 2026-08-25

Evidence: `https://github.com/grapefruit0205/gcp-lab-harness` 설정의 `This repository is currently public`, read/write deploy key, `git push`, 무인증 HTTPS `git ls-remote`, `git pull --ff-only`
Checked: 2026-08-25 — GitHub 공개 전환 확인, 공개 clone과 local/remote SHA 확인

## Foundation canary 저장 plan — state: verified — 2026-08-25

Evidence: `foundation/terraform/apply-canary/`, `scripts/foundation-canary.sh`; run `canary001` plan이 `google_compute_network` create 1·change 0·destroy 0과 SHA256 `2ed0c69f7a2bc7526b3206af08d385637c614a867c728a49d3dfd5546382ecea`를 출력
Checked: 2026-08-25 — `kdt5-05` allowlist와 저장 plan 정책 통과, 실제 apply는 미실행

## Not implemented

<!-- Listed explicitly so absence is a fact, not a gap. Copy must not claim these.
Checked: 2026-08-25 — this section goes stale in the other direction: a line left here after the
capability shipped makes you claim less than you have earned. Sweep it on the same 90-day clock. -->

- 실제 canary Cloud apply·verify·destroy 성공
- Lab 01–15별 Google Cloud 리소스 adapter
- 실제 `run-all` foreground supervisor와 Command Code·Cloud adapter 자동 연결
- Google Cloud 계정 통합 테스트
- 전체 15개 Lab E2E 실행

## Permanently excluded

<!-- Decided against. Copy must never imply these. Link the ledger decision: D-### -->
