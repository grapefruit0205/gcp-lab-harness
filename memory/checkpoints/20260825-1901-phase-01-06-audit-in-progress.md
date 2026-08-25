# Checkpoint — Phase 01–06 누락 감사 및 보완 — 2026-08-25 18:02

## The story so far

Phase 06 독립 검증에서 실제 guest 구성·서비스·백업·유지보수 증거가 빠졌고 기존 검증이 리소스 존재만으로 통과한다는 사실을 확인했다. 범위를 Phase 01–06으로 확장해 원본 Task와 실행 adapter를 다시 대조하고 있다. Phase 01·03은 현재 저장소에 adapter가 없고, Phase 02·04·05·06은 Terraform 리소스와 실제 동작 검증 사이의 누락이 있다. Cloud apply 없이 Terraform·guest automation·verify·evidence 계층을 보완한다.

## Decided

- D-012: 별도 예산 한도 없이 GCP 계정 연동과 실제 Cloud apply를 진행하되 allowlist·plan 승인·수량·timeout·cleanup 보호를 유지한다.
- D-013: 승인된 canary 프로젝트에서 Cloud apply를 단계적으로 진행하고 각 단계가 끝날 때 보고한다.
- D-014: 누구나 `git clone` 후 bootstrap 스크립트로 실행할 수 있도록 README에 기록한다.
- D-015: `grapefruit0205/gcp-lab-harness`를 public 저장소로 전환한다.
- D-016: Linux는 clone 후 Bash, Windows는 PowerShell→WSL로 bootstrap하고 Command Code·Extension·next handoff를 연결한다.
- 구현 원칙: GCP 리소스·IAM·metadata는 Terraform, VM 내부 작업은 guest script, 실제 완료 판정은 `verify.sh`와 evidence로 분리한다.

## Waiting on the user

- 없음. 기존 Phase 06 Cloud 리소스의 승인·정리는 이번 로컬 보완과 별개로 사용자 게이트를 유지한다.

## Next first action

Phase 05의 guest readiness·권한·노출 누락을 확정한 뒤 Phase 01–06 coverage matrix와 adapter 보완 패치를 작성한다.

## Tried

- 첫 account-check에 `google_project.lifecycle_state`를 가정했지만 provider 7.45.0에 없는 속성이어서 validate가 실패했다. ACTIVE 검사는 gcloud preflight에만 두고 Terraform data 조회로 좁혀 성공했다.
- 서비스 계정 canary는 삭제 후 복구 가능 기간이 있어 잔존 없는 cleanup 증명에 부적합했다. 즉시 destroy 가능한 빈 custom-mode VPC canary로 변경했다.
- PowerShell wrapper는 현재 Linux 환경에 Windows/PowerShell 런타임이 없어 실제 실행하지 못했고 코드 경로만 연결했다.
- 다른 작업 복제본의 Phase 01·03 adapter는 0.0.0.0/0 노출, 외부 IP 증거 기록, 실제 내부 연결 검증 부재가 있어 그대로 복사하지 않는다.
- 기존 Phase 06 verifier는 Terraform 리소스 존재만 확인해 guest 작업 전체가 없어도 PASS가 나므로 완료 증거로 사용할 수 없다.
