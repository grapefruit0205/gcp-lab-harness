# Checkpoint — Phase09 HTTP400 수정·실제 검증 완료, 리소스 유지 — 2026-08-26 18:11

## The story so far

Phase09 run `p09-260826-eb03`의 MySQL1044/역할 API400 복구가 실제 검증까지 완료됐다. BUILT_IN 명시·역할 operation 완료 후 별도 비밀번호 요청으로 보완했다. D-041 승인 bundle `e701120a9f6d8ef03a5df23bf41f8d0e056d6238cd7d7ca3dee37ce14658e707` apply와 verify 모두 exit0, Terraform0added/0changed/0destroyed이며 이번 실행에서400이 재발하지 않았다.

Task1–6 모두 passed·manifest verified다. Proxy SQL 쓰기/private SQL 읽기·양쪽 WordPress HTTP200/DB probe를 확인했다. 사후 읽기 전용 검사도 활성 cloudsqlsuperuser·DB 선택 errno0·VM2 RUNNING/SQL1 RUNNABLE/disk2와 모든 identity 보존을 확인했다. 70tests/TF/gate, 안내서·프로젝트 복구 스킬의 로컬 리허설도 통과했다. 최종 destroy는 요청대로 미실행이며 과금은 계속된다. command-code-result는 waiting_extension_review다. Phase08/shared lib/원문·commit/push 변경 없음.

## Decided

- D-041: e701… 수정 계획 적용·실제 검증 완료, Q-018 closed. 동일 승인·일반 쉘은 다시 묻지 않는다.
- D-036/D-037: 실패해도 리소스/state/로그 보존·진단한다. 자동 destroy 금지.
- 기존 저장 계정/project·Phase08 유지, 다른 Phase·Git 게시·삭제/교체 승인 없음.

## Waiting on the user

현재 작업의 승인 대기·미완료 단계 없음. 최종 destroy·Git 게시에는 별도 지시가 필요하다. 과거 별도 run PSA 잔여(Q-012)와 다른 Phase의 shared 복구 이관(Q-014)은 이번 범위 밖이다.

## Next first action

상태 재확인 요청 시 `jq '{status,checks}' /home/grapefruit/gcp-lab-harness/artifacts/runs/p09-260826-eb03/phase-09/manifest.json`을 읽고 답한다. 추가 apply/verify/destroy는 불필요하다.

## Tried

- API 비밀번호 초기화 성공만으로 DB 사용 가능을 판단한 경로: root USAGE뿐이라 wordpress1044. 실제 권한/SQL 검사가 필요했다.
- type 없는 역할+비밀번호 동시 요청:400/INTERNAL_ERROR. 옛 backend 원문이 없어 단일 원인을 분리 입증하지 못했지만 새 분리 요청·양쪽 실제 SQL/HTTP 검증은 통과했다.
- 이전 전체cleanup은 VM/SQL을 삭제했다. 현재 전용 보존 경로는 실제 실패에도 환경을 유지했다.
- 현재 state SHA `4b4cbeebaaa1c51c4a9e55126f9d6f7f91749b67cf53613a54ae0f247dc0379b`; 현재bundle apply receipt와 일치. 원시 로그/state/비밀은Git 제외다.
