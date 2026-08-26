# Checkpoint — Phase10–12 실기 통과·Phase13 보존 복구 — 2026-08-26 22:55

## The story so far

D-047 위임으로 Phase15까지 재질문 없이 저장계획/SHA/소유권/비용을 검사하며 진행한다. Phase10 p10-260826-2106 실제 415602행·TIMESTAMP·8쿼리, Phase11 p11-260826-2224 Task1–7, Phase12 p12-260826-2236 VPN/BGP·GLOBAL 통신·단일 터널 장애 후 잔여 경로 통과. Phase12는 원문 장애 실험으로 터널 하나만 삭제했고 나머지는 유지한다. 최신 게시 a97d2cd.

Phase13 p13-260826-2243 초기 c643e6…25개 Terraform 생성 후 중지 VM 직렬 로그를 읽는 post-apply 경로가 실패했다(session94518 종료1). 리소스/state는 보존했다. 실행 중에만 가능한 API이므로 중지 전 receipt 저장·정확한 builder ID 확인 후 동일 builder 재시작/reset/재수집/중지 복구를 구현했다. 로컬49회귀·Phase13 TFmock2/gate 통과, 아직 Cloud 재apply 전. Phase14/15 정적 gate/mock 통과, Cloud 실행 전.

## Decided

- D-047: 이번 Phase10–15 구현/apply/검증/보존 복구 위임; 매 SHA 재질문 없음, 기술 가드 유지.
- D-045: 관련 검증 변경 한국어 commit/push; 비밀·개인 설정·state·원시 로그 제외.
- D-036/D-037: 실패 전체 destroy 금지, 동일 run으로 복구; 이전 Phase08/09·다른 run 제외.
- D-043/D-044: Task 하위 콘솔 확인법과 실제·수동 검증 경계를 함께 보고.

## Waiting on the user

없음. 현재 범위는 D-047로 진행한다. Q014 legacy/Q019 catalog/Q012·020 PSA는 별도 범위다.

## Next first action

`cd /home/grapefruit/gcp-lab-harness && ./phases/13/execute.sh replan --run p13-260826-2243`로 보존 state의 새 계획을 생성하고 25 no-op/삭제·교체0 및 builder 조건부 복구 action을 검사한 뒤 새 SHA apply/verify를 실행한다.

## Tried

- P13 중지 builder get-serial-port-output → resource not ready; 실행 중 receipt 저장 후 stop, 기존 builder만 복구하여 재수집 시점 별도 표시.
- P11 group resource.metadata.user_labels →400; metadata.user_labels로 수정.
- P11 CPU metadata 비정렬조회→400;60초 ALIGN_MEAN으로 실제 통과, bool uptime 평균하지 않음.
- P11 dashboard v3→v1으로 수정.
- P10 AVRO logical 옵션 생략→INTEGER; true 재적재로 TIMESTAMP/8쿼리 통과.
