# Checkpoint — Phase09 보존 복구 준비 — 2026-08-26 17:05

## The story so far

Phase08 성공 run과 bucket은 보존한다. Phase09 두 번의 apply는 성공했지만 guest 검증이 실패했고, 이전 자동 cleanup으로 VM/SQL은 이미 삭제됐다. D-036/D-037에 따라 추가 destroy는 금지한다. 두 run 모두 VPC/PSA3개와 공통 API3개 state가 남았다. 최신 run `p09-260826-eb03`의 같은 state에서 복구할 예정이다.

이번 요청(D-038)은 재생성 준비다. 읽기 전용 조회로 최신 VPC peering ACTIVE, SQL0을 확인했다. 당시 proxy는 연결 수락 직후 DB 연결이 종료됐고 PHP CLI/mysqli는 설치돼 있었다. SQL8.0, TLS 강제 없음; 기존 진단이 MySQL errno를 버려 원인은 미확정이다. 공식 문서상 삭제한 SQL 이름은 즉시 재사용 가능하다.

기존 승인 소스만 `artifacts/phase-09-eb03-approved-source.tar`(0600)에 보존했다. state/자격 증명 복사가 아니다. 이번 턴 구현 소스 변경·Cloud 변경·commit/push는 아직 없다. 진행 중 프로세스도 없다. shared apply와 Phase09 verify에 자동 destroy 분기가 있어 실행 금지다. Phase08 승인 소스를 보호하며 Phase09 전용 보존 apply/replan 경로를 구현할 예정이다.

## Decided

- D-036/D-037: 실패 시 보존 → 비밀 없는 진단 → 수정 → 변경 plan 승인 → apply → 재검증. 자동 전체 삭제와 이전 cleanup 재시도는 더 이상 승인되지 않는다.
- D-038: 기존 저장 계정/프로젝트와 Phase08을 유지하며 Phase09 재생성 준비. 실제 변경에는 새 exact plan SHA 승인(D-017)이 필요하다. Git 게시는 미요청.

## Waiting on the user

현재 구현·계획 준비는 진행 가능. 새 저장 계획이 나온 뒤 exact SHA 승인 필요. Q-011 DB 원인, Q-012 이전 PSA, Q-014 코드 이관은 아직 미해결이다.

## Next first action

`/home/grapefruit/gcp-lab-harness/phases/09/sql_lab.py`와 `guest_install.py`를 읽고 Phase09 전용 실패 보존 apply/replan 및 안전한 guest 재시도를 구현한다. 기존 apply/verify/destroy는 실행하지 않는다.

## Tried

- apply16 성공 뒤 proxy `stage=db-ready/reason=db-connect/exit31` 실패. root 초기화·PHP/config lint 이후이며 WordPress 설치 전이다. 원인 해결을 주장하지 않는다.
- PHP 누락·TLS 강제·SQL 이름 재사용 대기 가설은 startup 로그·state 설정·공식 문서로 반증됐다.
- 자동 cleanup 중 SIGINT로 중단했지만 이미 제출된 SQL 삭제는 완료됐다. state6은 유지한다. `cleanup_required`는 과거 기록이지 삭제 재개 지시가 아니다.
- shared apply는 내부/외부 두 곳에서 자동 destroy한다. verifier trap만 변경해서는 충분하지 않다. 공유 Phase08 소스는 변경하지 않는다.
