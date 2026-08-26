# Checkpoint — Phase 08 실제 apply·실습 검증 성공 — 2026-08-26 15:36

## The story so far

D-031 승인 run `p08-260826-c924`는 Terraform 1개 생성 후 실제 Cloud machine 검증에 성공했다. manifest verified/Task1–8 passed, public ACL 생성·익명 hash·회수, CSEK rewrite/구키·신키 matrix/암호화 전체 세대 삭제, lifecycle/3세대 원본 복구/sync2 hash를 확인했다. 첫 실패 run `p08-260826-8c1d`는 앞서 정리 완료 상태다.

별도 gcloud 읽기 조회로 bucket1/객체 세대5(setup3+sync2), 공개 ACL·공개 IAM0, 암호화 객체0과 생성 identity/정책/state/hash를 대조했다. Python44·Terraform mock4/JSON guard3·Phase08 gate도 재통과했다. 증거는 `artifacts/runs/p08-260826-c924/phase-08/evidence/phase-08-{machine,postverify-audit}.json`이다.

최종 bucket destroy는 승인되지 않아 비공개 bucket `gcp-lab-p08-p08-260826-c924`를 유지한다. lab_completion.complete=false/destroy_pending=true이며 전체 정리나 비용0을 주장하지 않는다. 실행 소스는 이전 게시본 그대로이며 HEAD=origin/main `f39ffe0`이다. 이번 승인·성공 기록/guide 상태만 로컬 변경했고 새 commit/push는 하지 않았다.

## Decided

- D-031: bundle SHA `1222d79e290b309f117390ff457b5da1aa2577fef1a30bec32aa770ef575450a` 재apply·실습 검증 승인, Q-009 closed. 실행 성공.
- D-017/D-027: saved 사용자·코드·입력 고정과 최종 사용자 승인 경계 유지. 다른 사람 계정으로 바꿔 같은 run을 재사용하지 않음.
- 정상 성공 후 bucket 전체 destroy는 미승인. 이전 D-028/D-029 정리는 그대로 유지.

## Waiting on the user

현재 apply·실습 검증 요청은 완료. 최종 destroy·다음 Phase 진행은 사용자 요청 전 수행하지 않는다.

## Next first action

`cd /home/grapefruit/gcp-lab-harness && jq '{status,checks,cleanup}' artifacts/runs/p08-260826-c924/phase-08/manifest.json`으로 현재 verified 상태를 확인한다. 같은 run verify는 재실행하지 않는다.

## Tried

- 최초 verify HTTP401 → 실패 cleanup 성공. 오류 원문을 남기지 않은 기존 로그로는 요청 위치를 확정할 수 없어 안전한 단계·오류 형식 진단을 추가했다.
- 다운로드 오류의 JSON-only 판정 → 삭제된 정확한 bucket에 대한 읽기 전용 GET에서 일반 텍스트404를 관측했다. 상태 코드만의 오탐도 막도록 인증 전후 대조/구체 CSEK metadata 검사를 추가했다.
- 수정본 새 SHA를 D-031로 승인받아 성공했다. 실행 소스는 변경하지 않았으며 정상 destroy만 별도 남아 있다.
