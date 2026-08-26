# Checkpoint — Task 하위 안내·Phase10–15 로컬 검증 마무리 — 2026-08-26 20:50

## The story so far

D-044 요청에 따라 Phase01–15의90개 Task·177개 원문 하위 제목을 상세 콘솔 확인서로 확장했다. Phase10–15 전용 safe adapter는 실패 시 리소스/state/로그를 보존하고 같은 run의 replan·정확한 SHA 승인·재apply를 지원한다. BigQuery jobs, Monitoring 실제 결과, VPN 재시도, ALB/ILB health와 부하, Terraform state 검사를 보완했다. 현재33개 회귀 테스트와6개 Terraform mock plan·validate·offline 검사가 통과했다. 기존 요약 문서 정합성·전체 suite·두 번째 문서 리허설·최종 기록은 진행 중이다.

이번 변경은 로컬 미커밋 상태다. Cloud apply/destroy·Git commit/push는 하지 않았다. 시작 HEAD/origin main은5aa5749였다. Phase09 승인 소스와 공통 기존4개 lib는 보존했다. Phase09 p09-260826-eb03의 PSA/VPC3개 잔여·Phase08 bucket·이전 run은 건드리지 않았다.

## Decided

- D-044: 원문 Task 하위 항목 상세 안내와 Phase10–15 구현/오류 보완. 새 Cloud 변경 승인은 별도다。
- D-036/D-037: 실패 시 전체 삭제 금지, 동일 state 진단·복구.10–15는 새 보존 adapter 사용.
- D-043: Phase 완료 보고마다 콘솔 경로·판정·한계/증거를 함께 안내한다.

## Waiting on the user

- 새 Cloud 실행은 프로젝트·run·저장 plan의 정확한 SHA에 대한 명시 승인이 필요하다. 현재는 로컬 작업 중.
- Q-019 catalog 항목 확인은 아직 없고 Q-020 PSA producer 잔여 정리는 별도다. 지금 자동 처리하지 않는다.

## Next first action

`cat /home/grapefruit/gcp-lab-harness/docs/phases/phase-13-external-alb.md`를 읽고 builder 삭제·자동 만료의 오래된 설명을 실제 보존 구현과 맞춘다.

## Tried

- P10 bq dry-run stdout을 JSON으로 해석하는 경로는 신뢰할 수 없어 구조화 jobs API로 교체했다.
- P11 timeSeries 존재만으로 uptime 성공 처리하는 오류는 각 VM의 최신 true 값 검사로 교체했다.
- P12 실패 자동 destroy와 재시도 시4개 tunnel 강제 대기는 제거하고 단계/실제 tunnel ID를 보존한다.
- P13 builder 외부 삭제는 다음 repair 의존성을 깨므로 stopped 상태로 유지한다. 원문의 reset/삭제 실험은 아직 자동 구현과 다르다.
- P14 한 zone만 inventory 조회하거나 gcloud 실패를0개로 취급하는 경로는 aggregated 조회·fail-closed로 교체했다.
- P09 PSA 삭제 Error9는 producer 지연이므로 강제 peering 삭제/state 제거/무작정 재시도하지 않는다.
