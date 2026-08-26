# Checkpoint — Phase09 역할 API 거부·분리 요청 새 계획 — 2026-08-26 17:56

## The story so far

D-039 승인 plan `3d8e72d72c34a5b2b97097490959b0ed9d4b2a55d42ddcdbb5020d170f9483e2`의 apply는 exit0,10added/0changed/0destroyed다. 같은 run `p09-260826-eb03` verify는 proxy DB readiness에서 MySQL1044로 실패했다. 자동 삭제 없이 VM2/SQL1과 state·로그를 보존했다. 읽기 전용 실측에서 Proxy·private 양쪽 모두 root@% 인증은 성공하지만 SHOW GRANTS는 USAGE만 있고 wordpress 접근이1044다. Provider7.45.0 소스의 기본 root 삭제 동작과 자동화의 계정/권한 준비 누락을 확인했다.

로컬 보완은 root가 없으면 users.insert, 있으면 users.update의 databaseRoles query로 cloudsqlsuperuser 추가(기존 역할 회수 없음),1044 별도 분류/맹목 재시도 중단이다. Python64·TF validate/mock3/JSON guard2·Phase09 gate·Phase07–15 suite·새 독자 안내서 로컬 리허설이 통과했다. 실제 같은 state replan은16no-op/추가·변경·삭제·교체0, 새 bundle SHA `7ce28fea77bfd9f4e1eb8076c848c489411a9494bed7208a4f7e44345d6d758d`다. manifest planned; 실제 source/input/baseline/state/Cloud identity/plan/action/bundle·schema·0600 audit도 통과했다. state SHA는 apply 직후와 동일하다.

사용자가 리소스 유지·DB 권한 보완 적용·실제 동작 확인을 명시해 D-040으로 승인했다(Q-017 closed).7ce28… apply는Terraform0/0/0 완료 후 initialization의API HTTP400으로 exit1이었다. SQL operation은UPDATE_USER/DONE/INTERNAL_ERROR, 원문 미보관으로 세부 원인은unknown이다. 실제 재조회에서VM2/SQL1/disk2·identity 보존, root 인증 성공·USAGE/wordpress1044 지속을 확인했다. 실제 WordPress verifier는 시작하지 않았다. 로그는 ignored `artifacts/phase-09-root-role-cloud-apply.log`, `phase-09-root-role-postfailure-{diagnosis,db}.log`다.

공식gcloud assign-roles 소스와 비교해 BUILT_IN 명시·비밀번호 없는 역할 요청 완료 후 별도 비밀번호 갱신으로 보완했다. 총600초deadline·역할 실패 시 비밀번호 갱신 중단·원문 없는 고정 API 오류 분류를 추가했다. Python70/TF validate/mock/guard 통과. 새 실제 replan은16no-op, bundle SHA `e701120a9f6d8ef03a5df23bf41f8d0e056d6238cd7d7ca3dee37ce14658e707`이며 Q-018 승인 질문을 비동기로 보냈다. 새 Cloud변경은 미실행. audit session22789, suite52462와 문서 리허설 agent phase09_separated_role_rehearsal이 진행 중이다. commit/push·Phase08/shared lib/원문 변경 없음. 옛7ce28… SHA 실행 금지.

## Decided

- D-040:7ce28… exact SHA의 DB 권한 보완·비밀번호 갱신·실제 검증 승인, Q-017 closed. 일반 쉘 실행·동일 승인은 다시 묻지 않는다.
- D-036/D-037: 실패 환경·state·로그 보존 → 진단 → 수정 → 새 계획 승인 → apply/verify. 삭제·교체 승인 없음.
- D-038: 기존 저장 계정/project와 Phase08 유지, 같은 run/state로 복구한다. 다른 Phase/shared의 자동 삭제 경로는 실행하지 않는다.

## Waiting on the user

Q-018: e701… 새 exact 계획의 같은 DB 권한 범위·분리 요청·실제 검증 승인 대기. 리소스 삭제/교체·다른 Phase·Git 게시 권한 없음. 보존 중 과금 지속. Q-011 전체E2E, 과거 별도 run PSA 잔여(Q-012)와 shared 복구 이관(Q-014)은 남아 있다.

## Next first action

`tail -n 12 /home/grapefruit/gcp-lab-harness/artifacts/phase-09-separated-role-before-apply-check.log`로 새 계획의 읽기 전용 검사를 확인한다. Q-018 사용자 승인 없이는 새 apply를 실행하지 않는다.

## Tried

- 비밀번호 API operation DONE만 확인해 DB 준비 완료로 간주한 경로: root 인증은 됐지만 USAGE뿐이라 wordpress 접근1044. users.insert/update 역할 설정 보완 필요.
- 기존 root에type 없이 역할+비밀번호를 합친API는HTTP400/INTERNAL_ERROR. 형식 차이는 확인했으나 정확한backend원인은unknown이며 새 분리 요청 성공은 아직미검증이다.
- PHP/mysqli 누락·TLS 강제·방화벽 가설은 실제 양쪽 SQL 인증/권한 조회 성공으로 현재1044 원인에서 제외했다.
- 이전 자동 destroy는 VM/SQL을 삭제했다. 현재 Phase09 전용 실패 보존 경로는 실제 verify 실패에도 VM2/SQL1을 유지했다.
- 현재 state SHA `d1e523baadbd1945e1f3d34b2f6633226542119341c70b65c417cf9b71d571e6`; DB 진단 근거 `artifacts/runs/p09-260826-eb03/phase-09/evidence/read-only-db-privileges.json`. 원시 로그/상태/비밀은 Git 제외다.
