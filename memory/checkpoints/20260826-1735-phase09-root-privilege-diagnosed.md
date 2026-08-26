# Checkpoint — Phase09 복구 apply 성공·실제 검증 진행 — 2026-08-26 17:25

## The story so far

사용자가 Q-016 exact SHA 실행 제안에 “ㅇㅇ apply ㄱㄱ”으로 승인했다(D-039). 승인된 저장 plan apply(session60283)는 exit0,10added/0changed/0destroyed·root API 초기화 완료다. manifest applied, 현재 bundle에 대한 apply-completed receipt/state hash 일치를 확인했다. 같은 run 실제 verifier를 session94183에서 시작했다. 로그는 `artifacts/phase-09-preserve-cloud-{apply,verify}.log`. 아직 WordPress/SQL 경로 성공을 판정하지 않는다. 실행 소스는 수정하지 않으며 실패 시 자동 삭제가 없는 Phase09 전용 경로다. 아래 planned 상태는 실행 직전 기록이다.

Phase09의 실패 자동 전체 삭제를 없앤 전용 apply/replan/diagnose/재검증 경로를 구현했다(D-038). shared lib와 Phase08, 원문은 변경하지 않았다. 로컬 Python58·TF validate/mock3/JSON guard2·Phase09 gate·07–15 suite·새 독자 문서 로컬 리허설이 통과했다. 실제 DB 장애 원인은 아직 미확정이며 Cloud 재apply는 하지 않았다.

기존 run `p09-260826-eb03`의 VM/SQL은 과거 자동 cleanup으로 이미 없어졌다. 최신 diagnose는 VM/disk/SQL/subnet/firewall/SA0, VPC1/range1의 기존 identity를 확인했고 PSA connection도 이전 읽기 전용 조회에서 ACTIVE였다. 같은 work/state에서 복구 plan을 만들었다:10create/0update/0delete/6no-op. state SHA는 전후 `70c8146655a4f64b43b74a258fb7f7d589d4efc60fcd132e503d00f7865e52d6`로 같다.

새 bundle SHA는 `3d8e72d72c34a5b2b97097490959b0ed9d4b2a55d42ddcdbb5020d170f9483e2`. manifest planned. source/input/baseline/state/Cloud identity/binary/action/bundle·schema·0600을 실제 읽기 전용 재검사했다. 로그는 ignored `artifacts/phase-09-preserve-{diagnosis,replan,local-tests,suite,before-apply-check}.log`. 실행 중 프로세스 없음. commit/push 없음.

## Decided

- D-039: 위 exact SHA의 apply·실제 검증 승인. Q-016 closed. 동일 승인·일반 쉘 실행을 다시 묻지 않는다.

- D-036/D-037: 실패하면 리소스/state/로그 보존 → 진단 → 수정 → 변경 plan 승인 → apply/verify. 이전 cleanup 재시도도 새 삭제 지시 없이는 금지.
- D-038: 저장된 본인 계정/project와 Phase08 유지, 기존 Phase09 state 재사용. 실제 생성은 Q-016 새 exact SHA 승인 후.
- Phase09 새 코드만 보존 경로로 이관했다. 다른 Phase/shared 자동 삭제 경로는 Q-014 미해결이므로 실행하지 않는다.

## Waiting on the user

현재 승인 대기 없음. Q-016은 D-039로 해결됐다. 삭제/교체/Git 게시 미포함. Q-011 DB 원인과 Q-012 과거 PSA 잔여는 아직 미해결.

## Next first action

session94183과 `/home/grapefruit/gcp-lab-harness/artifacts/phase-09-preserve-cloud-verify.log`를 확인한다. 성공하면 Task1–6 evidence·VM/SQL inventory를 재대조하고, 실패하면 `execute.sh diagnose --run p09-260826-eb03`와 guest errno/로그로 원인을 좁힌다. destroy·새 SHA 미승인 apply 금지.

## Tried

- 이전 apply16 두 번 성공 후 WordPress/DB 검증 실패. 최신 실패는 proxy db-ready/db-connect/exit31이며 하위 errno는 기존 진단이 버려 unknown.
- PHP CLI/mysqli 누락·TLS 강제 가설은 로그/state로 반증됐다. SQL 이름은 공식 문서상 즉시 재사용 가능하여 불필요한 suffix를 추가하지 않았다.
- 기존 자동 destroy는 SIGINT로 중단했지만 이미 제출된 SQL 삭제는 완료됐다. state6과 네트워크를 보존한다.
- shared apply의 내부/외부 auto-destroy를 피하도록 Phase09 전용 실행 경로를 만들었다. 단순 verifier trap 수정으로는 부족했다.
- 테스트가 Bash EXIT 시 함수 local 변수 소멸을 잡아 prefix 전역 trap 상태로 수정했다. 실패/timeout/중단 code 회귀가 통과했다.
