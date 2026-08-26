# Checkpoint — Phase09 apply 성공·DB 권한 누락 진단·보완 준비 — 2026-08-26 17:35

## The story so far

D-039 승인 plan `3d8e72d72c34a5b2b97097490959b0ed9d4b2a55d42ddcdbb5020d170f9483e2`의 apply는 exit0,10added/0changed/0destroyed다. 같은 run `p09-260826-eb03` verify는 proxy DB readiness에서 MySQL1044로 실패했다. 자동 삭제 없이 VM2/SQL1과 state·로그를 보존했다. 읽기 전용 실측에서 Proxy·private 양쪽 모두 root@% 인증은 성공하지만 SHOW GRANTS는 USAGE만 있고 wordpress 접근이1044다. Provider7.45.0 소스의 기본 root 삭제 동작과 자동화의 계정/권한 준비 누락을 확인했다.

로컬 보완은 root가 없으면 users.insert, 있으면 users.update의 databaseRoles query로 cloudsqlsuperuser 추가(기존 역할 회수 없음),1044 별도 분류/맹목 재시도 중단이다. Python64·TF validate/mock3/JSON guard2가 통과했다. 아직 새 replan·Cloud 권한 보완은 실행하지 않았다. 변경 소스 때문에 옛 SHA로 apply/verify하면 안 된다. 실행 프로세스 없음. commit/push 없음. Phase08/shared lib/원문 변경 없음.

## Decided

- D-039: 이전 exact SHA의 apply·실제 검증 승인, Q-016 closed. 일반 쉘 실행을 다시 묻지 않는다.
- D-036/D-037: 실패 환경·state·로그 보존 → 진단 → 수정 → 새 계획 승인 → apply/verify. 삭제·교체 승인 없음.
- D-038: 기존 저장 계정/project와 Phase08 유지, 같은 run/state로 복구한다. 다른 Phase/shared의 자동 삭제 경로는 실행하지 않는다.

## Waiting on the user

현재는 진단에 따른 새 계획 준비 중이다. 새 root DB 관리자 역할 action과 새 bundle SHA는 승인받기 전 적용하지 않는다. Q-011은 현재1044 원인 확인, 전체 WordPress/SQL E2E는 미통과다. 과거 별도 run PSA 잔여(Q-012)와 shared 복구 이관(Q-014)은 남아 있다.

## Next first action

`cd /home/grapefruit/gcp-lab-harness && ./phases/09/execute.sh replan --run p09-260826-eb03`로 같은 state에서 새 계획을 만들고 no-op/16개 보존 여부를 확인한다. 새 exact SHA 승인 전 apply/DB 역할 변경 금지.

## Tried

- 비밀번호 API operation DONE만 확인해 DB 준비 완료로 간주한 경로: root 인증은 됐지만 USAGE뿐이라 wordpress 접근1044. users.insert/update 역할 설정 보완 필요.
- PHP/mysqli 누락·TLS 강제·방화벽 가설은 실제 양쪽 SQL 인증/권한 조회 성공으로 현재1044 원인에서 제외했다.
- 이전 자동 destroy는 VM/SQL을 삭제했다. 현재 Phase09 전용 실패 보존 경로는 실제 verify 실패에도 VM2/SQL1을 유지했다.
- state SHA `0b745001ff3e0f4a9904773fe59d6b9afcb25e4da890dc3e9dffab7621b7cd1a`; DB 진단 근거 `artifacts/runs/p09-260826-eb03/phase-09/evidence/read-only-db-privileges.json`. 원시 로그/상태/비밀은 Git 제외다.
