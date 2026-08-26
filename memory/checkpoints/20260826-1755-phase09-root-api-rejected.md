# Checkpoint — Phase09 DB 권한 보완 승인·적용 진행 — 2026-08-26 17:49

## The story so far

D-039 승인 plan `3d8e72d72c34a5b2b97097490959b0ed9d4b2a55d42ddcdbb5020d170f9483e2`의 apply는 exit0,10added/0changed/0destroyed다. 같은 run `p09-260826-eb03` verify는 proxy DB readiness에서 MySQL1044로 실패했다. 자동 삭제 없이 VM2/SQL1과 state·로그를 보존했다. 읽기 전용 실측에서 Proxy·private 양쪽 모두 root@% 인증은 성공하지만 SHOW GRANTS는 USAGE만 있고 wordpress 접근이1044다. Provider7.45.0 소스의 기본 root 삭제 동작과 자동화의 계정/권한 준비 누락을 확인했다.

로컬 보완은 root가 없으면 users.insert, 있으면 users.update의 databaseRoles query로 cloudsqlsuperuser 추가(기존 역할 회수 없음),1044 별도 분류/맹목 재시도 중단이다. Python64·TF validate/mock3/JSON guard2·Phase09 gate·Phase07–15 suite·새 독자 안내서 로컬 리허설이 통과했다. 실제 같은 state replan은16no-op/추가·변경·삭제·교체0, 새 bundle SHA `7ce28fea77bfd9f4e1eb8076c848c489411a9494bed7208a4f7e44345d6d758d`다. manifest planned; 실제 source/input/baseline/state/Cloud identity/plan/action/bundle·schema·0600 audit도 통과했다. state SHA는 apply 직후와 동일하다.

사용자가 리소스를 삭제하지 않고 DB 권한 보완 적용·실제 동작 확인을 명시하여 D-040으로 승인하고 Q-017을 닫았다. 새7ce28… 저장 계획 apply를 session33615에서 실행 중이다. 로그는 ignored `artifacts/phase-09-root-role-cloud-apply.log`. 아직 API 역할 보완 완료/실제 SQL 성공을 판정하지 않는다. 승인 소스는 수정하지 않으며 Phase09 전용 실패 보존 경로를 사용한다. commit/push·Phase08/shared lib/원문 변경 없음.

## Decided

- D-040:7ce28… exact SHA의 DB 권한 보완·비밀번호 갱신·실제 검증 승인, Q-017 closed. 일반 쉘 실행·동일 승인은 다시 묻지 않는다.
- D-036/D-037: 실패 환경·state·로그 보존 → 진단 → 수정 → 새 계획 승인 → apply/verify. 삭제·교체 승인 없음.
- D-038: 기존 저장 계정/project와 Phase08 유지, 같은 run/state로 복구한다. 다른 Phase/shared의 자동 삭제 경로는 실행하지 않는다.

## Waiting on the user

현재 승인 대기 없음. 리소스 삭제/교체·다른 Phase·Git 게시 권한은 없다. 보존 중 과금은 계속된다. Q-011 전체 E2E, 과거 별도 run PSA 잔여(Q-012)와 shared 복구 이관(Q-014)은 남아 있다.

## Next first action

session33615와 `/home/grapefruit/gcp-lab-harness/artifacts/phase-09-root-role-cloud-apply.log`를 확인하고 성공하면 같은 run의 execute.sh verify를 실행한다. 실패하면 리소스를 유지하고 diagnose한다.

## Tried

- 비밀번호 API operation DONE만 확인해 DB 준비 완료로 간주한 경로: root 인증은 됐지만 USAGE뿐이라 wordpress 접근1044. users.insert/update 역할 설정 보완 필요.
- PHP/mysqli 누락·TLS 강제·방화벽 가설은 실제 양쪽 SQL 인증/권한 조회 성공으로 현재1044 원인에서 제외했다.
- 이전 자동 destroy는 VM/SQL을 삭제했다. 현재 Phase09 전용 실패 보존 경로는 실제 verify 실패에도 VM2/SQL1을 유지했다.
- state SHA `0b745001ff3e0f4a9904773fe59d6b9afcb25e4da890dc3e9dffab7621b7cd1a`; DB 진단 근거 `artifacts/runs/p09-260826-eb03/phase-09/evidence/read-only-db-privileges.json`. 원시 로그/상태/비밀은 Git 제외다.
