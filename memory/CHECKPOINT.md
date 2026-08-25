# Checkpoint — GitHub pull·commit 흐름 반영 — 2026-08-25 12:15

## The story so far

한국어 Google Cloud Lab 01–15를 원본과 1:1인 실행 Phase 문서로 설계했다. 각 Phase는 clean tree에서 `git pull --ff-only`로 시작하고 Command Code `cmd` 실행, VS Code Codex Extension 검증, 사용자 승인, cleanup, 한국어 commit, push 순으로 닫힌다. pull 보호 스크립트와 dry-run 검사를 통과했고 설계 전체를 로컬 main의 한국어 초기 커밋으로 남겼다. 실제 Cloud adapter와 GitHub origin은 아직 없다.

## Decided

- D-002: 15개 Google Cloud 실습을 Phase별 CLI 자동화 하네스로 만든다.
- D-004: Phase 완료마다 한국어 커밋과 GitHub 푸시를 남긴다.
- D-006: 실습용 Google Cloud 계정·프로젝트 연동을 포함한다.
- D-009: 실행자는 Command Code `cmd`, 검증자는 VS Code Codex Extension이며 모델 override를 하지 않는다.
- D-010: GitHub 저장소 생성과 Phase 시작 전 pull, 완료 후 commit·push를 포함한다.

## Waiting on the user

- Q-001: GitHub 저장소 이름과 공개 범위가 필요하다.
- Q-002: 실행 대상 Google Cloud 프로젝트·결제 계정·예산 한도가 필요하다.
- Q-003: 저장소 라이선스가 필요하다.
- Q-005: Command Code 고정 모델 실행 규칙을 영구 ballast pin으로 남길지 확인이 필요하다.
- A-001: 확정 전까지 로컬 저장소 이름을 `gcp-lab-harness`로 가정한다.
- A-002: 공식 Monitoring·Logging remote MCP를 read-only verifier로 가정한다.

## Next first action

사용자에게 GitHub 저장소 이름·공개 범위를 받은 뒤 빈 원격 저장소를 만들고 `origin` 연결·push·`pull --ff-only`를 검증한다.

## Tried

- 처음에 실행 명령을 Codex CLI/`code`로 읽었으나 D-009에 따라 Command Code `cmd`로 전체 설계를 sweep했다.
- `gcloud`, Terraform, GitHub CLI는 현재 설치되어 있지 않아 Cloud/GitHub 통합 검증을 하지 않았다.
- 현재 SSH 인증은 기존 `grapefruit0205/Mywiki` 저장소의 deploy key라 새 저장소 생성 권한으로 사용할 수 없다.
