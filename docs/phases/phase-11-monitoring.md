# Phase 11 — Resource Monitoring

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

## 구현 작업

1. Monitoring/Logging API, metric availability, uptime 대상, notification channel 정책을 preflight한다.
2. dashboard·policy·group·uptime 구성 JSON과 fixture VM을 plan에 기록한다.
3. metric이 생성될 traffic을 발생시키고 time series를 timeout polling한다.
4. alert policy 구조와 활성·비활성 상태 전이를 API로 확인한다.
5. notification 발송은 별도 opt-in 없이는 하지 않고 정책 구조만 검증한다.

## 실행 계약

Command Code `cmd`는 현재 계정에 고정된 모델로 gcloud/API adapter를 실행하고 별도 모델 인수를 사용하지 않는다. MCP는 실행 채널로 사용하지 않는다. machine verification 뒤 Extension이 공식 Monitoring·Logging MCP와 API로 읽기 전용 독립 검증을 수행한다.

## 검증 게이트

- dashboard widgets와 metric filters가 versioned definition과 일치한다.
- alert 두 조건, combiner, threshold, duration, enabled 상태가 정확하다.
- group membership과 uptime check 결과가 fixture resource에 연결된다.
- Extension은 공식 Monitoring/Logging MCP와 API 결과를 교차 확인한다.
- 사용자가 보고를 확인해 명시 승인해야 cleanup을 시작한다.

## 안전·비용 가드레일

- 실제 notification channel과 on-call 전송은 명시 opt-in 없이는 연결하지 않는다.
- verifier MCP identity는 read-only와 MCP tool 사용 권한만 갖는다.
- logs·metrics의 project/resource 식별자는 정제 evidence에서 hash 처리한다.
- fixture VM, uptime check, group, policy, dashboard를 소유권 역순으로 삭제한다.

## 완료 조건

- Task 1–7 coverage와 dashboard·alert·group·uptime 증거가 있다.
- API와 MCP 결과가 일치하고 Extension 검토·사용자 승인이 완료됐다.
- cleanup 후 Phase 11 소유 observability·compute 리소스가 0이다.

## Command Code·Extension handoff 지시

Command Code는 MCP를 통해 Cloud 변경을 만들지 않고 실행 evidence까지만 남긴다. Extension은 공식 MCP 결과가 API와 다르면 API/CLI를 기준으로 차이를 보고하며, 사용자의 승인을 추론하지 않는다.

## Git 종료 조건

`Phase 11: Cloud Monitoring 자동화 및 검증 완료` 커밋을 push하고 remote SHA 확인 뒤 Phase 12를 시작한다.
