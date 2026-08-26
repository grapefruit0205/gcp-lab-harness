# Checkpoint — Phase09 종료 잔여3개·90개 Task 콘솔 안내 게시 준비 — 2026-08-26 18:27

## The story so far

Phase09 run `p09-260826-eb03`은 DB1044/API400 보완 후 실제 SQL/WordPress Task1–6 검증을 통과했다. 이후 D-042 요청으로 destroy했고 SQL/VM2/disk2/subnet/firewall/SA·전용 IAM은 없어졌다. PSA producer 사용 중 Error9로 VPC·할당 범위·연결3개만 남아 cleanup_required다. state에는 잔여3개와 활성 유지 API3개가 있고, 새 백업·강제 삭제/state 제거는 하지 않았다. Phase08과 이전 run 잔여는 보존했다.

D-043에 따라 모든15개 Phase/90개 Task의 콘솔 경로·통과 기준·한계/보조 확인을 문서·AGENTS·prompt·review 출력 경로에 연결했다. 8개 안내 회귀 테스트·90개 coverage·Phase09 70tests/TF/gate·controller·Phase01–15 offline suite·독립 문서 리허설 통과. 수정된 Cloud 실행 소스는 e701… 그대로이고 shared adapter/다른 Phase Cloud 코드는 미변경이다. 관련 파일의 검증·stage·한국어 commit·push를 진행한다. 새 pin catalog 항목만 사용자 확인 전이다.

## Decided

- D-042: 현재 Phase09 run 정상 종료 destroy 승인, Phase08·다른 run 잔여·공통 API 보존.
- D-043: Phase별 Task 콘솔 확인법을 항상 안내하고 관련 변경을 로컬·원격 Git에 반영한다.
- D-036/D-037: 실패해도 리소스/state/로그 보존·진단한다. 자동 destroy 금지.

## Waiting on the user

- Q-019: 제시한 phase-task-console-check exact 항목의 ballast catalog 저장만 확인 대기. AGENTS·문서·보고 동작은 D-043대로 반영했다.
- Q-020: 현재 run PSA producer 해제 후 같은 run 정리 필요. 강제 peering 삭제/state 제거는 금지하며 이전 run Q-012와 구분한다.
- 다른 Phase의 보존 복구 이관(Q-014)은 별도이며 기존 자동 실패 destroy 경로 실행 금지.

## Next first action

`git -C /home/grapefruit/gcp-lab-harness status --short`로 게시 중인 파일 상태를 확인한다. Cloud 재생성/재apply는 하지 않는다.

## Tried

- API 비밀번호 초기화 성공만으로 DB 사용 가능을 판단한 경로: root USAGE뿐이라 wordpress1044. 실제 권한/SQL 검사가 필요했다.
- type 없는 역할+비밀번호 동시 요청:400/INTERNAL_ERROR. 옛 backend 원문이 없어 단일 원인을 분리 입증하지 못했지만 새 분리 요청·양쪽 실제 SQL/HTTP 검증은 통과했다.
- 명시적 destroy의 PSA 삭제: SQL 삭제 성공 뒤에도 producer 사용 중 Error9. 같은 요청을 무작정 반복하거나 강제 peering 삭제하지 않는다.
- 삭제 전 apply receipt/state SHA는 역사적 증거다. 현재 state는 종료 정리로 변경됐으며 예전 apply receipt로 재verify하지 않는다. 비밀/state/원시 로그는 Git 제외다.
