# Checkpoint — Foundation B 컨트롤러 구현 완료 — 2026-08-25 13:30

## The story so far

`grapefruit0205/gcp-lab-harness` private 저장소에 15개 Lab 설계와 Git pull/push 기반이 있다. 이번 작업에서 15개 Phase 상태를 `artifacts/runs/<run-id>/pipeline.json`에 원자적으로 저장하고, 허용 전이만 적용하며, plan/diff/evidence hash에 묶인 Extension 승인·반려와 resume next-action을 처리하는 Foundation B 라이브러리와 CLI를 구현했다. 실제 Google Cloud adapter와 foreground `run-all` 연결은 아직 없다.

## Decided

- D-002: 15개 Google Cloud 실습을 Phase별 CLI 자동화 하네스로 만든다.
- D-004: Phase 완료마다 한국어 커밋과 GitHub 푸시를 남긴다.
- D-006: 실습용 Google Cloud 계정·프로젝트 연동을 포함한다.
- D-009: 실행자는 Command Code `cmd`, 검증자는 VS Code Codex Extension이며 모델 override를 하지 않는다.
- D-010: GitHub 저장소 생성과 Phase 시작 전 pull, 완료 후 commit·push를 포함한다.
- D-011: GitHub 원격은 `grapefruit0205/gcp-lab-harness` private 저장소다.

## Implemented and observed

- `lib/harness/common.sh`, `state.sh`, `gate.sh`: 0700 run 디렉터리, 0600 atomic JSON, `flock` 상태 잠금, 15개 Phase cursor
- `bin/gcp-lab-harness`: `run init`, `status`, `resume`, `hash`, `gate prepare|approve|reject`
- `schemas/pipeline-state.schema.json`: pipeline 상태 기계 판독 계약
- `tests/offline-controller.sh`: 정상/금지 전이, stale 승인 거부, 승인·반려, 재개, 파일 권한 검사
- 2026-08-25 로컬 관찰: `validate-design`, offline controller test, `run-all --dry-run` PASS
- Cloud 명령과 Google Cloud 계정 변경은 실행하지 않음

## Waiting on the user

- Q-002: 실행 대상 Google Cloud 프로젝트·결제 계정·예산 한도가 필요하다.
- Q-003: 저장소 라이선스가 필요하다.
- Q-005: Command Code 고정 모델 실행 규칙을 영구 ballast pin으로 남길지 확인이 필요하다.
- A-002: 공식 Monitoring·Logging remote MCP를 read-only verifier로 가정한다.

## Next first action

Foundation A에서 `gcloud`와 Terraform 설치 경로를 구현·확인한다. Cloud apply 전에는 Q-002의 GCP project·billing·예산 값을 받아 allowlist와 비용 gate를 구성한다.

## Tried

- `gcloud`, Terraform은 현재 설치되어 있지 않아 Cloud 통합 검증을 하지 않았다. `gh`는 선택 도구다.
- 실제 `run-all`은 `doctor`, `config/harness.env`, Cloud adapter가 모두 준비될 때까지 명시적으로 차단한다.
- 승인 hash는 현재 review bundle과 일치할 때만 받는다. 실제 파일을 승인 직전에 다시 hash하는 연결은 supervisor 구현 때 추가해야 한다.
