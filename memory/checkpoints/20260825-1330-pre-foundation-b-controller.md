# Checkpoint — GitHub push·pull 검증 완료 — 2026-08-25 13:14

## The story so far

한국어 Google Cloud Lab 01–15 설계가 `grapefruit0205/gcp-lab-harness` private GitHub 저장소의 `main`에 있다. 사용자 승인 후 repo 전용 deploy key를 Read/write로 등록했고, 두 한국어 커밋을 push해 local/remote SHA 일치를 확인한 다음 실제 `git pull --ff-only`도 통과했다. `gh`는 런타임 필수 도구에서 선택 도구로 내렸다. 실제 Google Cloud adapter는 아직 없다.

## Decided

- D-002: 15개 Google Cloud 실습을 Phase별 CLI 자동화 하네스로 만든다.
- D-004: Phase 완료마다 한국어 커밋과 GitHub 푸시를 남긴다.
- D-006: 실습용 Google Cloud 계정·프로젝트 연동을 포함한다.
- D-009: 실행자는 Command Code `cmd`, 검증자는 VS Code Codex Extension이며 모델 override를 하지 않는다.
- D-010: GitHub 저장소 생성과 Phase 시작 전 pull, 완료 후 commit·push를 포함한다.
- D-011: GitHub 원격은 `grapefruit0205/gcp-lab-harness` private 저장소다.

## Waiting on the user

- Q-002: 실행 대상 Google Cloud 프로젝트·결제 계정·예산 한도가 필요하다.
- Q-003: 저장소 라이선스가 필요하다.
- Q-005: Command Code 고정 모델 실행 규칙을 영구 ballast pin으로 남길지 확인이 필요하다.
- A-001: 확정 전까지 로컬 저장소 이름을 `gcp-lab-harness`로 가정한다.
- A-002: 공식 Monitoring·Logging remote MCP를 read-only verifier로 가정한다.

## Next first action

사용자에게 GCP project·billing·예산과 라이선스를 받아 Foundation 구현을 시작한다.

## Tried

- 처음에 실행 명령을 Codex CLI/`code`로 읽었으나 D-009에 따라 Command Code `cmd`로 전체 설계를 sweep했다.
- `gcloud`, Terraform은 현재 설치되어 있지 않아 Cloud 통합 검증을 하지 않았다. `gh`는 선택 도구다.
- 현재 SSH 인증은 기존 `grapefruit0205/Mywiki` 저장소의 deploy key라 새 저장소 생성 권한으로 사용할 수 없다.
- 기존 Mywiki key 대신 별도 SSH host alias와 repo 전용 deploy key를 사용해 충돌을 피했다.
