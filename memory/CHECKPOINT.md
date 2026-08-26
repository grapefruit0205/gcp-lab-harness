# Checkpoint — Phase10–15 게시·Cloud 실행 준비 — 2026-08-26 21:05

## The story so far

D-044의 로컬 구현·검사를 완료했다. Phase01–15의90개 Task를221개 상세 확인 항목으로 나눴고 Task 안의 원문 하위 제목167개를 모두 연결했다. Phase10–15의 보존형 실행·동일 state replan·정확한 SHA 승인과 기능 오류를 보완했다.40개 회귀·13개 안내·TF mock6개/fmt/validate·전체 offline suite·6개 Phase gate·Phase09 기존70개 검사가 통과했다. 새 독자2차 리허설도34문서107링크·차단0이었다.

사용자가 D-045로 commit/push와 실제 apply·오류 수정을 요청했다. 현재 변경40개 회귀/13개 안내 검사를 재확인했고 원격과 HEAD5aa5749는 분기0이다. 계정·allowlist·billing preflight를 통과했다. commit/push와 Phase10 새 계획을 준비 중이며 아직 새 Cloud 변경은 없다. 원문·Phase08/09·승인 공통4개 lib는 그대로다. Phase08 bucket, Phase09 p09-260826-eb03 PSA/VPC3개 및 이전 run 잔여도 보존했다. 실제 Cloud 성공과 원문 전체 수동 단계 완료는 미검증/일부 미구현이며 docs/audits/phase-10-15-repair.md에 구분했다.

## Decided

- D-045: 해당 변경 stage·commit·push 후 Phase10부터 실제 실행/오류 보완. exact plan 승인과 실패 보존은 유지.
- D-044: Task 하위 상세 안내와 Phase10–15 구현·오류 보완.
- D-036/D-037: 실패 시 리소스/state/계획/로그 보존 후 진단·새 plan 승인·재apply. 자동 전체 삭제 금지.
- D-043: 완료 보고에 Task별 콘솔 경로·값·판정·한계/증거를 항상 안내.
- 기존 run의 계정/config/project는 고정하고 원래 작성자 계정을 clone 사용자의 기본값으로 만들지 않는다.

## Waiting on the user

- 새 Cloud 실행에는 별도 저장 계획의 정확한 SHA 승인이 필요하며 현재 새 계획은 없다. commit/push는 D-045에 따라 진행 중.
- Q-014:01–08 옛 자동 삭제 경로 미이관; Q-021:10–15 실기·원문 차이 추적.
- Q-019 catalog 항목 확인, Q-012/Q-020 PSA producer 잔여는 여전히 별도다. 자동 처리하지 않는다.

## Next first action

`git -C /home/grapefruit/gcp-lab-harness diff --cached --stat`로 게시 범위를 검사하고 D-045의 한국어 commit·push를 완료한다.

## Tried

- P10 bq dry-run 텍스트 파싱·page 크기를 총행수로 판단하던 경로는 jobs API/totalRows로 교체했다.
- P11 시계열 존재만 확인하던 거짓 성공은 정확한 대상과 최신 true 값 검사로 교체했다.
- P12 실패 전체 destroy·재시도4터널 강제 대기·선택 정리를 passed로 처리하던 경로는 단계 재개/manual-boundary로 교체했다.
- P13 builder 외부 삭제는 다음 repair의 의존성을 깨므로 stopped 보존. 원문 reset/삭제는 아직 미구현이며 disk 비용이 남는다.
- P14 잘못된 zone inventory·CLI 오류를0개로 취급하던 경로는 aggregated/fail-closed 조회로 교체했다.
- 원문 하위 제목 최초177 집계는 Task 밖 제목까지 포함했다. 실제 대상167·상세221로 독립 재집계했다.
- Phase09 PSA Error9는 producer 사용 중이므로 강제 peering 삭제/state 제거/무작정 재시도하지 않는다.
