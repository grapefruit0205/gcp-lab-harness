# Checkpoint — Phase 08 게시 완료·Phase 09 새 계획 승인 대기 — 2026-08-26 16:01

## The story so far

Phase08 실제 검증 성공 기록을 `dad0cc000d9d876bb13d4353359dca16c1914b3f`로 한국어 commit·push하고 원격 main 일치를 확인했다. clean ff-only pull 완료. 성공 run `p08-260826-c924` bucket은 삭제 미요청으로 보존한다.

Phase09 실행 보완·Python33/TF mock3·JSON guard2/Phase gate/07–15 suite가 통과했다. 실제 사용자·artifact·권한/일부 quota preflight와 새 run `p09-260826-5d82`의 저장 plan(16create/0change/0destroy)을 완료했다. SQL1(MySQL8 Enterprise 1vCPU/3.75GB), VM2, 전용 VPC, API3개와 client /32다. bundle SHA는 `d418a5b7ed219126889882f2e1e296b1e34dcea26b256dc329774119fb561cf4`이며 source/input/action/binary/schema 일치도 재검사했다.

Phase09 Cloud apply·실제 SQL/HTTP E2E는 아직 없다. Phase09 수정은 로컬 미커밋이다. Q-010의 exact SHA 승인 후에만 apply·즉시 verify한다. SQL 삭제 뒤 PSA 정리가 최대4일 지연될 수 있고 API3개는 유지된다. 자동 정시 삭제/비용 중지는 없다.

## Decided

- D-031: bundle SHA `1222d79e290b309f117390ff457b5da1aa2577fef1a30bec32aa770ef575450a` 재apply·실습 검증 승인, Q-009 closed. 실행 성공.
- D-017/D-027: saved 사용자·코드·입력 고정과 최종 사용자 승인 경계 유지. 다른 사람 계정으로 바꿔 같은 run을 재사용하지 않음.
- 정상 성공 후 bucket 전체 destroy는 미승인. 이전 D-028/D-029 정리는 그대로 유지.
- D-032: 현재 Phase08 기록 stage/commit/push와 Phase09 실행 준비. 새 Phase09 exact plan SHA 승인 경계 유지.

## Waiting on the user

Q-010: 위 Phase09 exact bundle SHA로 apply·SQL/WordPress 실습 검증을 할지 사용자 승인 대기. 정상 성공 후 전체 destroy나 Phase08 bucket 삭제는 포함하지 않는다.

## Next first action

`cd /home/grapefruit/gcp-lab-harness && sha256sum artifacts/runs/p09-260826-5d82/phase-09/plan-bundle.json && jq -r .status artifacts/runs/p09-260826-5d82/phase-09/manifest.json`으로 승인 대상 SHA·planned 상태를 읽기 전용 재확인한다.

## Tried

- 최초 verify HTTP401 → 실패 cleanup 성공. 오류 원문을 남기지 않은 기존 로그로는 요청 위치를 확정할 수 없어 안전한 단계·오류 형식 진단을 추가했다.
- 다운로드 오류의 JSON-only 판정 → 삭제된 정확한 bucket에 대한 읽기 전용 GET에서 일반 텍스트404를 관측했다. 상태 코드만의 오탐도 막도록 인증 전후 대조/구체 CSEK metadata 검사를 추가했다.
- 수정본 새 SHA를 D-031로 승인받아 성공했다. 실행 소스는 변경하지 않았으며 정상 destroy만 별도 남아 있다.
- Phase09 기존 plan은 `P09_CLIENT_SOURCE_CIDR` 누락으로 중단했다. 자동 /32 탐지와 고정 artifact 준비를 추가했다.
- `gcloud sql users set-password --prompt-for-password --quiet`는 현재 SDK에서 입력을 받지 않는다. 비밀번호를 인자/로컬 파일에 넣지 않는 SQL API 경로로 교체했다.
- Phase gate에 숫자09만 전달하면 실패한다. 문서 경로를 전달해야 하며 수정 후 gate/suite 통과했다. apply 인자도 `--approved-plan-sha`가 아니라 `--confirm-plan-sha`다.
