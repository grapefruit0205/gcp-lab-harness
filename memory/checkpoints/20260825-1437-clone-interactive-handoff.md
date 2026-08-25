# Checkpoint — clone 기반 대화형 handoff 진입점 — 2026-08-25 14:00

## The story so far

public 저장소를 Linux `$HOME`에 clone한 뒤 Bash bootstrap 하나로 사용자 명령 설치, gcloud 로그인·ADC, 프로젝트 allowlist와 Terraform 연결을 구성하도록 진입점을 고쳤다. Command Code 대화형 세션에서 자연어로 현재 Phase를 구현하고 machine verification 뒤 VS Code Codex Extension으로 handoff하며, 승인·반려 뒤 같은 session을 재개하는 CLI를 연결했다. Windows PowerShell은 WSL의 동일 Bash 하네스를 호출한다. canary plan은 create 1·change 0·destroy 0 상태이며 실제 apply는 아직 하지 않았다.

## Decided

- D-012: 별도 예산 한도 없이 GCP 계정 연동과 실제 Cloud apply를 진행하되 allowlist·plan 승인·수량·timeout·cleanup 보호를 유지한다.
- D-013: `kdt5-05`에서 canary Cloud apply를 단계적으로 진행하고 각 단계가 끝날 때 보고한다.
- D-014: 누구나 `git clone` 후 bootstrap 스크립트로 실행할 수 있도록 README에 기록한다.
- D-015: `grapefruit0205/gcp-lab-harness`를 public 저장소로 전환한다.
- D-016: Linux는 clone 후 Bash, Windows는 PowerShell→WSL로 bootstrap하고 Command Code·Extension·next handoff를 연결한다.

## Waiting on the user

- canary apply 전에 저장 plan SHA256 `2ed0c69f7a2bc7526b3206af08d385637c614a867c728a49d3dfd5546382ecea` 승인이 필요하다.
- Q-003: 저장소 라이선스가 필요하다.
- Q-005: Command Code 고정 모델 실행 규칙을 영구 ballast pin으로 남길지 확인이 필요하다.
- A-002: 공식 Monitoring·Logging remote MCP를 read-only verifier로 가정한다.

## Next first action

사용자가 저장 plan SHA256을 승인하면 `./scripts/foundation-canary.sh apply --run canary001 --confirm-plan-sha 2ed0c69f7a2bc7526b3206af08d385637c614a867c728a49d3dfd5546382ecea`를 실행한다.

## Tried

- 첫 account-check에 `google_project.lifecycle_state`를 가정했지만 provider 7.45.0에 없는 속성이어서 validate가 실패했다. ACTIVE 검사는 gcloud preflight에만 두고 Terraform data 조회로 좁혀 성공했다.
- 서비스 계정 canary는 삭제 후 복구 가능 기간이 있어 잔존 없는 cleanup 증명에 부적합했다. 즉시 destroy 가능한 빈 custom-mode VPC canary로 변경했다.
- PowerShell wrapper는 현재 Linux 환경에 Windows/PowerShell 런타임이 없어 실제 실행하지 못했고 코드 경로만 연결했다.
