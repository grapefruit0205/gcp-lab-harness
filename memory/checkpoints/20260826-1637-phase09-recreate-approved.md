# Checkpoint — Phase 09 재생성 plan 승인 대기 — 2026-08-26 16:35

## The story so far

Phase08 실제 검증 성공 기록을 `dad0cc000d9d876bb13d4353359dca16c1914b3f`로 한국어 commit·push하고 원격 main 일치를 확인했다. clean ff-only pull 완료. 성공 run `p08-260826-c924` bucket은 삭제 미요청으로 보존한다.

Phase09 첫 run `p09-260826-5d82`는 D-033 승인으로 apply16개·root 초기화에 성공했지만 WordPress guest 설정에서 실패했다(Q-011 원인 미확정). 자동 cleanup 후 VM/disk/SQL/SA/run IAM0, 전용 VPC/PSA range/connection3개는 producer 사용 중 Error9로 남았다(Q-012). 공통 API3개는 유지 대상이고 state6개를 보존한다. frozen source `artifacts/approved-code/phase09-5d82`로 재시도했으나 동일 오류다.

사용자의 재생성 요청(D-034)에 따라 새 installer의 PHP/config lint·DB SELECT1 readiness·설치 단계/오류 종류 진단을 보완했다. 비밀은 stdin/guest config에만 전달하고 진단은 허용 목록으로 제한했다. Python44/TF mock3·JSON guard2/Phase gate/07–15 suite·새 독자 문서 로컬 리허설이 통과했다. 실제 WordPress 문제 해결·Cloud E2E 성공을 주장하지 않는다.

새 run `p09-260826-eb03`의 saved plan은 SQL1/VM2를 포함해16create/0change/0destroy다. 현재 본인 OAuth·allowlist·동일 region과 client /32·artifact hash·일부 IAM/quota preflight를 통과했다. bundle SHA `bc763bc4bec0092bdbd0a1fd8efc3e564df8a2ed6c0952bb43762fce102fb7ab`, source/input/action/binary/bundle/schema 일치 재확인. manifest planned이며 새 apply·verify는 하지 않았다. Phase09 로컬 변경은 미커밋이고 추가 게시도 하지 않았다. 현재 실행 중인 shell/agent는 없다.

## Decided

- D-034: 같은 실행 환경에서 새 run 재생성 준비. 새 exact saved plan 승인 전 생성·추가 Git 게시는 하지 않는다.
- 이전 승인 소스는 `artifacts/approved-code/phase09-5d82`에 보존했고 source hash 검사를 통과했다. config/artifacts는 원본에 대한 symlink이며 원본 state/lock을 공유한다. 새 소스 수정 뒤에도 이전 cleanup은 이 경로로 실행한다.
- 16:29 이전 run destroy 재시도(session 60162)는 exit1로 종료했다. 결과는 `artifacts/phase-09-prior-cleanup-retry.log`; PSA 잔여 정리는 계속 미완료다.

- D-031: bundle SHA `1222d79e290b309f117390ff457b5da1aa2577fef1a30bec32aa770ef575450a` 재apply·실습 검증 승인, Q-009 closed. 실행 성공.
- D-017/D-027: saved 사용자·코드·입력 고정과 최종 사용자 승인 경계 유지. 다른 사람 계정으로 바꿔 같은 run을 재사용하지 않음.
- 정상 성공 후 bucket 전체 destroy는 미승인. 이전 D-028/D-029 정리는 그대로 유지.
- D-032: 현재 Phase08 기록 stage/commit/push와 Phase09 실행 준비. 새 Phase09 exact plan SHA 승인 경계 유지.
- D-033: Q-010 exact SHA의 apply·SQL/WordPress 검증·실패 run cleanup 승인. 정상 성공 후 destroy·Phase08 변경·추가 commit/push는 미포함.

## Waiting on the user

Q-013: 새 run `p09-260826-eb03`, exact SHA `bc763bc4bec0092bdbd0a1fd8efc3e564df8a2ed6c0952bb43762fce102fb7ab`의 apply·즉시 SQL/WordPress verify·실패 run cleanup 승인. 비용 발생·자동 만료 없음·API3개 유지·PSA 지연 범위 포함. 새 exact SHA 승인은 아직 없다. Q-011 원인·Q-012 이전 잔여 정리는 미해결, Phase08 보존.

## Next first action

사용자가 Q-013을 승인한 경우에만 `/home/grapefruit/gcp-lab-harness`에서 `./phases/09/execute.sh apply --run p09-260826-eb03 --confirm-plan-sha bc763bc4bec0092bdbd0a1fd8efc3e564df8a2ed6c0952bb43762fce102fb7ab`를 실행하고 성공 즉시 `./phases/09/execute.sh verify --run p09-260826-eb03`를 실행한다. 승인 전 생성 금지. 기존 run cleanup은 frozen snapshot 경로에서만 실행한다.

## Tried

- 최초 verify HTTP401 → 실패 cleanup 성공. 오류 원문을 남기지 않은 기존 로그로는 요청 위치를 확정할 수 없어 안전한 단계·오류 형식 진단을 추가했다.
- 다운로드 오류의 JSON-only 판정 → 삭제된 정확한 bucket에 대한 읽기 전용 GET에서 일반 텍스트404를 관측했다. 상태 코드만의 오탐도 막도록 인증 전후 대조/구체 CSEK metadata 검사를 추가했다.
- 수정본 새 SHA를 D-031로 승인받아 성공했다. 실행 소스는 변경하지 않았으며 정상 destroy만 별도 남아 있다.
- Phase09 기존 plan은 `P09_CLIENT_SOURCE_CIDR` 누락으로 중단했다. 자동 /32 탐지와 고정 artifact 준비를 추가했다.
- `gcloud sql users set-password --prompt-for-password --quiet`는 현재 SDK에서 입력을 받지 않는다. 비밀번호를 인자/로컬 파일에 넣지 않는 SQL API 경로로 교체했다.
- Phase gate에 숫자09만 전달하면 실패한다. 문서 경로를 전달해야 하며 수정 후 gate/suite 통과했다. apply 인자도 `--approved-plan-sha`가 아니라 `--confirm-plan-sha`다.
- WordPress 설정 실패를 권한 부족으로 단정할 수 없다: startup2개 정상, OS Login/Admin/IAP/actAs 모두 true. stdout/stderr 억제로 정확한 세부 오류는 남지 않았다. 같은 run verify 재실행은 금지다.
- SQL 삭제 후 PSA Delete는 실제 Error9/producer 사용 중이었다. state 제거·강제 peering 삭제·code hash 완화 없이 승인 소스와 state를 유지한다.
- PHP CLI 누락 가설은 startup 로그의 php8.2-cli 설치·mysqli/mysqlnd 로드로 반증됐다. 권한·PHP 부족을 실제 원인으로 단정하지 않는다.
