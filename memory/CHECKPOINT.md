# Checkpoint — Phase 01–15 보완 통합·push 준비 — 2026-08-25

## The story so far

원격의 선택형 단일 모델 실행 경로와 이번 Phase 01–15 adapter 보완을 통합했다. 공통 source-task 계약, action-plan/plan-bundle, 민감 plan 정제, artifact 전이 guard, 실패 cleanup과 Phase별 잔여 inventory가 구현돼 있다. Monitoring·ALB evidence는 현재 run의 metric·log로 한정한다. Windows는 WSL 없이 PowerShell→Git for Windows Bash를 사용한다. 전체 offline suite와 Google provider schema 검증은 통과했지만 개정 adapter의 Cloud E2E는 아직 실행하지 않았다.

## Decided

- D-017: 같은 Command Code 고정 모델의 구현·자기 검증 선택 경로를 유지한다.
- D-018: README는 Windows Desktop 링크·프롬프트를 가장 먼저 설명한다.
- D-019: Windows는 WSL을 요구하지 않는다.
- Phase `execute.sh`·`verify.sh`만 Command Code 무확인 허용 목록에 넣고 직접 `gcloud`·`terraform`·`rm`은 포괄 허용하지 않는다.
- 정상 검증 리소스는 사용자 승인 전 유지하되 apply·post-apply 실패 시 manifest 소유 범위만 자동 cleanup한다.

## Waiting on the user

- Cloud 비용이 발생하는 새 run의 plan/apply 승인과 Extension 또는 단일 모델 review의 사용자 승인.

## Next first action

새 run ID로 Phase 01 plan을 만들고 exact plan hash를 보고한 뒤 사용자 승인을 기다린다. 전체 15개 Phase Cloud E2E, Windows 실기동, MCP OAuth는 별도 검증한다.

## Tried

- 원격 `main`이 두 커밋 앞서 있어 현재 변경을 stash로 보존한 뒤 `git pull --ff-only`했다.
- 원격 단일 모델 기능과 Phase 보완이 같은 파일을 수정해 충돌했으며 두 기능을 모두 유지하도록 수동 통합했다.
- Terraform Registry가 한 번 timeout됐지만 단일 재시도에서 설계 검증이 통과했다.
