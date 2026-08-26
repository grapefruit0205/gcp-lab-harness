# Phase 11 — Resource Monitoring

[Phase10–15 보존형 실행·복구 안내](../phase-10-15-execution.md) · [현재 구현/오류 수정/남은 한계](../audits/phase-10-15-repair.md). 이 문서의 완료 조건은 실제 실행 후 판정할 기준이며 이번 로컬 수정의 Cloud 성공 기록이 아니다.

- 원본: `references/google-cloud-labs-ko/labs/11.Resource Monitoring_KR.md`
- 비용 위험: 낮음–중간
- 주요 서비스: Cloud Monitoring, alerting, dashboards, groups, uptime checks, Cloud Logging

## 목적

모니터링 대상 VM, 커스텀 dashboard, 복수 조건 alert policy, resource group, uptime check를 API로 만들고 metric·상태를 검증한 뒤 alert를 비활성화한다.

## 범위와 원본 매핑

| 원본 Task | 분류 | 자동화·증거 |
|---|---|---|
| Task 1. Cloud Monitoring 열기 | cli-equivalent | monitored resource와 metric descriptor/time series 조회; 필요 시 fixture VM 배포 |
| Task 2. 커스텀 대시보드 | automated | versioned dashboard JSON과 chart query 검증 |
| Task 3. 알림 정책 | automated | 두 조건, combiner, notification opt-in 상태의 policy 생성 |
| Task 4. 리소스 그룹 | automated | label 규칙 기반 group과 membership 조회 |
| Task 5. 가동 시간 모니터링 | automated | uptime check config와 실제 check result/time series |
| Task 6. 알림 비활성화하기 | automated | enabled true→false 전이 확인 |
| Task 7. Review | cli-equivalent | dashboard·policy·group·uptime evidence 검토 |

## Task별 콘솔 확인

[하위 항목별 상세 확인](../console/phase-11.md): 원문 하위 제목/번호 절차마다 클릭 경로·값·판정·한계를 확인합니다.

[공통 확인법](../console-checks.md)을 먼저 읽고 자신의 프로젝트·해당 run만 선택한다. 아래는 **확인 기준**이지 이번 실행의 성공 기록이 아니다. 원본 Task 이름은 위 매핑과 대응한다.

| Task | 콘솔 경로·대상 | 통과 기준 | 한계·보조 확인 |
|---|---|---|---|
| 1 | Monitoring → Metrics Explorer → VM CPU 지표 | 올바른 metrics scope/project와 현재 run VM3개의 시계열 | 데이터가 늦으면 시간 범위를 실행 시점으로 조정. 빈 그래프를 정상으로 판정하지 않음 |
| 2 | Monitoring → 대시보드 → Phase 11 <RUN_ID> | 해당 run CPU 차트와 실제 데이터가 표시됨 | 대시보드 존재만으로 쿼리/데이터 성공은 아님 |
| 3 | Monitoring → 알림(Alerting) → 정책 → Phase 11 CPU <RUN_ID> | 조건2개·AND 결합이 승인 설정과 일치 | Task6 후에는 사용 중지 상태가 정상. 실제 알림 발송은 opt-in과 별도 |
| 4 | Monitoring → 그룹(Groups) → Phase 11 nginx <RUN_ID> | run label 필터와 구성원 VM3개 일치 | UI에서 메뉴가 없으면 콘솔 검색 또는 API evidence로 보조. 그룹은 원문 재현용 |
| 5 | Monitoring → 가동 시간 확인(Uptime checks) → 해당 run | 설정 대상/경로가 일치하고 실제 검사 결과 시계열 확인 | 구성 존재나 HTTP VM 상태만으로 uptime 성공을 단정하지 않음 |
| 6 | Monitoring → 알림 → 해당 정책 | 최종 상태 사용 중지/Disabled | true→false 전이는 정제 evidence와 대조. 확인하려고 다시 활성화하지 않음 |
| 7 | 대시보드·정책·그룹·가동 시간 화면 | Task1–6 데이터·구성·비활성화 결과를 함께 확인 | UI 확인과 MCP/기계 검증은 별도. 미수행 항목을 완료로 표시하지 않음 |

메뉴 확인 근거(2026-08-26): [대시보드 관리](https://docs.cloud.google.com/monitoring/charts/dashboards), [Monitoring 그룹](https://docs.cloud.google.com/monitoring/groups). 화면 언어/버전에 따라 상단 검색으로 같은 서비스에 접근한다. 실제 UI 클릭 전 과정 검증은 별도다.

## 구현 작업

1. Monitoring/Logging API, metric availability, uptime 대상, notification channel 정책을 preflight한다.
2. dashboard·policy·group·uptime 구성 JSON과 fixture VM을 plan에 기록한다.
3. metric이 생성될 traffic을 발생시키고 time series를 timeout polling한다.
4. alert policy 구조와 활성·비활성 상태 전이를 API로 확인한다.
5. notification 발송은 별도 opt-in 없이는 하지 않고 정책 구조만 검증한다.

## 실행 계약

Command Code `cmd`는 현재 계정에 고정된 모델로 gcloud/API adapter를 실행하고 별도 모델 인수를 사용하지 않는다. MCP는 실행 채널로 사용하지 않는다. machine verification 뒤 Extension은 API로 읽기 전용 독립 검증을 수행한다. Monitoring·Logging MCP는 연결되어 있을 때 선택적으로 보조하며 미연결을 CLI 실행 실패로 처리하지 않는다.

## 검증 게이트

- dashboard widgets와 metric filters가 versioned definition과 일치한다.
- alert 두 조건, combiner, threshold, duration, enabled 상태가 정확하다.
- group membership과 uptime check 결과가 fixture resource에 연결된다.
- Extension은 API 결과를 확인하고 연결된 경우에만 공식 Monitoring/Logging MCP와 교차 확인한다.
- 사용자가 보고를 확인해 명시 승인해야 cleanup을 시작한다.

## 안전·비용 가드레일

- 실제 notification channel과 on-call 전송은 명시 opt-in 없이는 연결하지 않는다.
- verifier MCP identity는 read-only와 MCP tool 사용 권한만 갖는다.
- logs·metrics의 project/resource 식별자는 정제 evidence에서 hash 처리한다.
- fixture VM, uptime check, group, policy, dashboard를 소유권 역순으로 삭제한다.

## 완료 조건

- Task 1–7 coverage와 dashboard·alert·group·uptime 증거가 있다.
- API 실제 결과와 Extension 검토·사용자 승인이 완료됐다. 선택형 MCP 미실행은 별도로 표시한다.
- cleanup 후 Phase 11 소유 observability·compute 리소스가 0이다.

## Command Code·Extension handoff 지시

Command Code는 MCP를 통해 Cloud 변경을 만들지 않고 실행 evidence까지만 남긴다. Extension은 공식 MCP 결과가 API와 다르면 API/CLI를 기준으로 차이를 보고하며, 사용자의 승인을 추론하지 않는다.

## 현재 adapter

`phases/11/terraform`은 nginx fixture VM 3개, CPU dashboard, 두 조건 AND alert, label group, 1분 HTTP uptime check를 만든다. verifier는 정확한 VM ID 집합의 group member·CPU와 각 VM의 최신 uptime=true를 기다린 뒤 alert를 enabled true에서 false로 전이한다. uptime 대상은 INSTANCE group이고 방화벽은 provider가 조회한 실제 checker IP /32 목록이다. 정책은 서로 다른 VM1/2의 CPU20%·60초 조건 두 개를 AND로 결합한다. 메일 수신·UI 조작·MCP는 별도 수동/선택 검증이다.

## Git 종료 조건

`Phase 11: Cloud Monitoring 자동화 및 검증 완료` 커밋을 push하고 remote SHA 확인 뒤 Phase 12를 시작한다.
