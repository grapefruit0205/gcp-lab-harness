# Phase 13 — 자동 확장 Application Load Balancer

- 원본: `references/google-cloud-labs-ko/labs/13.Configure an Application Load Balancer (HTTP) with Autoscaling_KR.md`
- 비용 위험: 높음
- 주요 서비스: Compute Engine image/template/MIG, Cloud NAT, global Application Load Balancer, autoscaling

## 목적

web server custom image와 managed instance group을 만들고 external Application Load Balancer와 autoscaler를 연결해 backend health, routing, 부하에 따른 확장을 검증한다.

## 범위와 원본 매핑

| 원본 Task | 분류 | 자동화·증거 |
|---|---|---|
| Task 1. 상태 확인 방화벽 규칙 구성하기 | automated | 공식 health-check source와 target tag 규칙 |
| Task 2. Cloud Router를 사용하여 NAT 구성하기 | automated | Router/NAT와 backend egress 상태 |
| Task 3. 웹 서버용 커스텀 이미지 생성하기 | automated | builder VM customization·service enable·image provenance |
| Task 4. 인스턴스 템플릿 구성 및 인스턴스 그룹 생성하기 | automated | immutable template, MIG, health, autoscaling policy |
| Task 5. Application Load Balancer(HTTP) 구성하기 | automated | health check, backend service, URL map, proxy, forwarding rule |
| Task 6. Application Load Balancer(HTTP) 부하 테스트하기 | automated | 반복 HTTP, backend identity distribution, scale-out/in observation |
| Task 7. Review | cli-equivalent | image→MIG→LB→autoscale evidence 검토 |

## 구현 작업

1. global/regional quota, health check ranges, machine/image와 부하 도구를 preflight한다.
2. 모든 image·template·MIG·LB·NAT·IP 변경과 autoscaling 상한을 plan한다.
3. custom image를 checksum이 고정된 provisioning으로 만들고 builder를 제거한다.
4. MIG가 healthy해진 뒤 LB frontend를 구성하고 HTTP content/backend marker를 확인한다.
5. 제한된 부하를 발생시켜 autoscaling evidence를 수집하고 부하 프로세스를 반드시 종료한다.

## 실행 계약

Command Code `cmd`는 현재 고정 모델을 상속하고 저장된 고비용 plan 승인 뒤에만 apply한다. backend health와 scale은 timeout polling한다. machine verification 뒤 Extension 검토까지 리소스를 유지하되 자동 만료를 둔다.

## 검증 게이트

- custom image provenance와 boot-time Apache readiness가 확인된다.
- MIG target size·health·autoscaling policy가 plan과 일치한다.
- LB frontend가 정상 응답하고 여러 backend marker가 관찰된다.
- 부하 구간의 instance 수가 상한 안에서 증가하고 회복 정책이 동작한다.
- Extension은 Compute/LB/Monitoring 상태를 read-only API·MCP로 확인하고 사용자가 승인한다.

## 안전·비용 가드레일

- autoscaling 최대 instance 수, 부하 duration·QPS, VM/disk 크기를 제한한다.
- health check 외 public management ingress를 열지 않는다.
- 부하 프로세스에 timeout과 종료 trap을 두고 무제한 트래픽을 금지한다.
- global IP, forwarding rule, proxy, URL map, backend, MIG, image, NAT를 역의존 순서로 정리한다.

## 완료 조건

- Task 1–7 coverage와 image·health·routing·autoscale 증거가 있다.
- Extension 검토와 사용자 승인이 완료됐다.
- cleanup 후 global/regional LB·MIG·image·NAT·address 잔여 수가 0이다.

## Command Code·Extension handoff 지시

Command Code는 HTTP 200 하나만으로 성공을 선언하지 않고 backend health·분산·scale을 각각 증명한다. Extension은 Monitoring metric과 API 상태를 교차 확인하고 비용 잔여 위험을 사용자에게 보고한다.

## 현재 adapter

`phases/13/terraform`은 immutable Debian base image를 plan에 고정하고 serial readiness 뒤 builder를 중지해 Apache custom image를 만든다. 두 regional MIG, min 1/max 2 autoscaler, logging-enabled backend, IPv4·IPv6 forwarding을 구성한다. verifier는 builder 삭제·image provenance, healthy backend, 여러 backend marker, bounded load의 scale-out과 scale-in을 각각 확인한다.

## Git 종료 조건

`Phase 13: Application Load Balancer와 자동 확장 자동화 및 검증 완료` 커밋·push 뒤 Phase 14를 시작한다.
