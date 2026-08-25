# Checkpoint — Canary 1단계 plan 준비 — 2026-08-25 13:51

## The story so far

15개 Lab 자동화 저장소의 GCP 계정·Terraform 연결을 마쳤다. 사용자가 `kdt5-05`를 실제 apply 대상으로 승인해 단일 custom-mode VPC를 만드는 canary 스크립트와 저장 plan을 준비했다. plan은 create 1·change 0·destroy 0이며 실제 apply는 아직 하지 않았다. 공개 clone·bootstrap 사용법을 README에 추가했고 GitHub 저장소를 public으로 전환했다.

## Decided

- D-012: 별도 예산 한도 없이 GCP 계정 연동과 실제 Cloud apply를 진행하되 allowlist·plan 승인·수량·timeout·cleanup 보호를 유지한다.
- D-013: `kdt5-05`에서 canary Cloud apply를 단계적으로 진행하고 각 단계가 끝날 때 보고한다.
- D-014: 누구나 `git clone` 후 bootstrap 스크립트로 실행할 수 있도록 README에 기록한다.
- D-015: `grapefruit0205/gcp-lab-harness`를 public 저장소로 전환한다.

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
