# Checkpoint — Phase09 apply 성공·DB 권한 보완 no-op 계획 승인 대기 — 2026-08-26 17:40

## The story so far

D-039 승인 plan `3d8e72d72c34a5b2b97097490959b0ed9d4b2a55d42ddcdbb5020d170f9483e2`의 apply는 exit0,10added/0changed/0destroyed다. 같은 run `p09-260826-eb03` verify는 proxy DB readiness에서 MySQL1044로 실패했다. 자동 삭제 없이 VM2/SQL1과 state·로그를 보존했다. 읽기 전용 실측에서 Proxy·private 양쪽 모두 root@% 인증은 성공하지만 SHOW GRANTS는 USAGE만 있고 wordpress 접근이1044다. Provider7.45.0 소스의 기본 root 삭제 동작과 자동화의 계정/권한 준비 누락을 확인했다.

로컬 보완은 root가 없으면 users.insert, 있으면 users.update의 databaseRoles query로 cloudsqlsuperuser 추가(기존 역할 회수 없음),1044 별도 분류/맹목 재시도 중단이다. Python64·TF validate/mock3/JSON guard2·Phase09 gate·Phase07–15 suite·새 독자 안내서 로컬 리허설이 통과했다. 실제 같은 state replan은16no-op/추가·변경·삭제·교체0, 새 bundle SHA `7ce28fea77bfd9f4e1eb8076c848c489411a9494bed7208a4f7e44345d6d758d`다. manifest planned; 실제 source/input/baseline/state/Cloud identity/plan/action/bundle·schema·0600 audit도 통과했다. state SHA는 apply 직후와 동일하다.

새 DB 권한 보완/재apply/실제 재검증은 Q-017 승인 전이므로 미실행이다. 변경 소스 때문에 옛3d8e… SHA를 실행하거나 guard를 우회하면 안 된다. 실행 프로세스 없음. commit/push 없음. Phase08/shared lib/원문 변경 없음. 원시 로그는 ignored `artifacts/phase-09-root-role-{replan,before-apply-check,local-tests,suite}.log`다.

## Decided

- D-039: 이전 exact SHA의 apply·실제 검증 승인, Q-016 closed. 일반 쉘 실행을 다시 묻지 않는다.
- D-036/D-037: 실패 환경·state·로그 보존 → 진단 → 수정 → 새 계획 승인 → apply/verify. 삭제·교체 승인 없음.
- D-038: 기존 저장 계정/project와 Phase08 유지, 같은 run/state로 복구한다. 다른 Phase/shared의 자동 삭제 경로는 실행하지 않는다.

## Waiting on the user

Q-017: 위 새 exact SHA의16개 Terraform no-op·root@% DB 관리자 역할 추가·난수 비밀번호 교체·SQL/WordPress 재검증 승인. 기존 역할 회수/리소스 재생성/삭제/Git 게시 없음. 보존 중 과금은 계속된다. Q-011은 현재1044 원인 확인, 전체 WordPress/SQL E2E는 미통과다. 과거 별도 run PSA 잔여(Q-012)와 shared 복구 이관(Q-014)은 남아 있다.

## Next first action

`cd /home/grapefruit/gcp-lab-harness && sha256sum artifacts/runs/p09-260826-eb03/phase-09/plan-bundle.json`으로 Q-017의7ce28… SHA를 재확인한다. 사용자 승인 전 apply/DB 역할 변경 금지.

## Tried

- 비밀번호 API operation DONE만 확인해 DB 준비 완료로 간주한 경로: root 인증은 됐지만 USAGE뿐이라 wordpress 접근1044. users.insert/update 역할 설정 보완 필요.
- PHP/mysqli 누락·TLS 강제·방화벽 가설은 실제 양쪽 SQL 인증/권한 조회 성공으로 현재1044 원인에서 제외했다.
- 이전 자동 destroy는 VM/SQL을 삭제했다. 현재 Phase09 전용 실패 보존 경로는 실제 verify 실패에도 VM2/SQL1을 유지했다.
- state SHA `0b745001ff3e0f4a9904773fe59d6b9afcb25e4da890dc3e9dffab7621b7cd1a`; DB 진단 근거 `artifacts/runs/p09-260826-eb03/phase-09/evidence/read-only-db-privileges.json`. 원시 로그/상태/비밀은 Git 제외다.
