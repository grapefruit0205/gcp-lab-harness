# Checkpoint — Command Code 기반 15-Phase 설계 완료 — 2026-08-25 11:58

## The story so far

한국어 Google Cloud Lab 01–15를 원본과 1:1인 실행 Phase 문서로 설계했다. Ubuntu Bash에서 인증된 Command Code CLI `cmd`가 현재 고정 모델을 상속해 실행하고, VS Code Codex Extension이 독립 검증한 뒤 사용자가 승인하면 cleanup·한국어 commit·push·다음 Phase로 전이하는 계약이다. 원본 Markdown·이미지 28개를 references에 보존했고 단일 진입점의 dry-run과 최소 정적 검사를 통과했다. 실제 Cloud adapter와 외부 변경은 아직 없다.

## Decided

- D-002: 15개 Google Cloud 실습을 Phase별 CLI 자동화 하네스로 만든다.
- D-004: Phase 완료마다 한국어 커밋과 GitHub 푸시를 남긴다.
- D-006: 실습용 Google Cloud 계정·프로젝트 연동을 포함한다.
- D-009: 실행자는 Command Code `cmd`, 검증자는 VS Code Codex Extension이며 모델 override를 하지 않는다.

## Waiting on the user

- Q-001: GitHub 저장소 이름과 공개 범위가 필요하다.
- Q-002: 실행 대상 Google Cloud 프로젝트·결제 계정·예산 한도가 필요하다.
- Q-003: 저장소 라이선스가 필요하다.
- Q-005: Command Code 고정 모델 실행 규칙을 영구 ballast pin으로 남길지 확인이 필요하다.
- Q-006: Git 작성자 이름과 이메일이 로컬에 설정되어 있지 않다.
- A-001: 확정 전까지 로컬 저장소 이름을 `gcp-lab-harness`로 가정한다.
- A-002: 공식 Monitoring·Logging remote MCP를 read-only verifier로 가정한다.

## Next first action

사용자에게 GitHub 저장소 이름·공개 범위, GCP project·billing·예산, 라이선스를 받아 Foundation과 실제 Phase adapter 구현을 시작한다.

## Tried

- 처음에 실행 명령을 Codex CLI/`code`로 읽었으나 D-009에 따라 Command Code `cmd`로 전체 설계를 sweep했다.
- `gcloud`, Terraform, GitHub CLI는 현재 설치되어 있지 않아 Cloud/GitHub 통합 검증을 하지 않았다.
