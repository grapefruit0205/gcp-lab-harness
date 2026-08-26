# Checkpoint — Phase11 그룹 필터 보존 복구 — 2026-08-26 22:31

## The story so far

D-047로 현재 계정·허용 프로젝트의 Phase10–15 구현/apply/검증/복구가 재질문 없이 위임됐다. Phase10 p10-260826-2106은 실제415602행·시간3개TIMESTAMP·8쿼리/Task1–5 통과, 리소스 보존. 관련 변경 de18392까지 main에 게시했다.

Phase11 p11-260826-2224 초기 e364e9… 적용은 그룹의 resource.metadata.user_labels 필터400으로 실패했다. VM3·VPC/subnet/firewall·SA·dashboard·policy 등10개는 생성되어 보존 중. 공식 문서의 metadata.user_labels로 TF/검증/회귀를 수정했다. Phase12는 원문 동일region 다른zone onprem을 자동 선택하도록5파일 수정했고 mock2개/gate 통과; 아직 Cloud 실행 전. Phase13–15 실기 전이다.

## Decided

- D-047: 이번 Phase10–15는 저장계획/SHA/소유권/비용 검사 후 재질문 없이 실행·보존 복구. 이후 새 작업에 자동 승계하지 않음.
- D-045: 관련 코드·검증 기록 한국어 커밋/푸시. 비밀·state·원시 로그 제외.
- D-036/D-037: 실패 전체destroy 금지. Phase08/09·다른run 보존.
- D-043/D-044: Task 하위별 콘솔 확인법과 실제/수동 경계 제공.

## Waiting on the user

- 없음. D047 범위 내 실행은 추가승인 대기가 아니다.
- Q014 legacy 자동destroy·Q019 catalog·Q012/Q020 PSA는 별도범위로 유지.

## Next first action

`cd /home/grapefruit/gcp-lab-harness && python3 tests/test-phases-10-15.py && terraform -chdir=phases/11/terraform test && ./phases/11/execute.sh replan --run p11-260826-2224`로 그룹 필터 수정과 기존10개 보존 계획을 검증한 뒤 새SHA로 apply/verify한다.

## Tried

- P11 resource.metadata.user_labels.run → 실제API400; metadata.user_labels.run으로 수정, 기존10개 보존.
- P11 dashboard GET v3 → 잘못된경로; v1로분기수정·회귀추가.
- P10 AVRO logical type옵션 생략 → INTEGER; 옵션true재적재로TIMESTAMP/8query 실기통과.
- 일반phase-gate는 숫자아닌docs/phases/phase-NN-*.md 경로를 받는다.
