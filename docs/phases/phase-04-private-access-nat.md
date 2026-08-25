# Phase 04 — Private Google Access 및 Cloud NAT

- 원본: `references/google-cloud-labs-ko/labs/04.Implement Private Google Access and Cloud NAT_KR.md`
- 비용 위험: 중간
- 주요 서비스: VPC, Compute Engine, Private Google Access, Cloud Router, Cloud NAT, Logging

## 목적

외부 IP가 없는 VM에서 Private Google Access로 Google API에 접근하고 Cloud NAT로 일반 인터넷 egress를 제공하며 NAT 로그까지 end-to-end로 검증한다.

## 범위와 원본 매핑

| 원본 Task | 분류 | 자동화·증거 |
|---|---|---|
| Task 1. VM 인스턴스 생성하기 | automated | VPC·firewall·외부 IP 없는 VM·IAP SSH readiness |
| Task 2. Private Google Access 활성화하기 | automated | bucket/object 접근의 활성화 전 실패·활성화 후 성공 |
| Task 3. Cloud NAT 게이트웨이 구성하기 | automated | Router/NAT 구성과 패키지 저장소 egress 성공 |
| Task 4. Cloud NAT Logging 구성 및 로그 확인하기 | automated | logging enable, traffic 발생, 구조화 NAT log 조회 |
| Task 5. Review | cli-equivalent | private API path·NAT path·log correlation 검토 |

## 구현 작업

1. 필요한 API, IAP SSH 권한, subnet PGA 상태와 NAT quota를 점검한다.
2. VM에 외부 IP가 없음을 plan과 post-apply describe에서 확인한다.
3. PGA 활성화 전후 Cloud Storage 접근을 동일 명령으로 비교한다.
4. NAT 생성 전후 일반 인터넷 egress를 비교하고 NAT IP를 증거에 hash 처리한다.
5. NAT logging을 켜고 고유 correlation marker의 로그를 제한 시간 polling으로 찾는다.

## 실행 계약

`cmd`는 모델·effort override 없이 Phase adapter를 실행한다. Google API 경로와 일반 인터넷 경로를 분리해 측정하며 log 전파 지연은 timeout 안에서 polling한다. machine verification 이후 `waiting_extension_review`로 중지한다.

## 검증 게이트

- VM access config에 외부 IPv4가 없다.
- PGA 전 expected failure와 활성화 후 객체 접근 성공이 구분된다.
- NAT 후 일반 egress가 성공하고 NAT 상태가 정상이다.
- Cloud Logging에 run marker와 일치하는 NAT log가 있다.
- Extension은 gcloud/API 및 공식 Logging MCP를 read-only로 재검증하고 사용자가 승인한다.

## 안전·비용 가드레일

- IAP ingress 범위와 최소 포트만 허용한다.
- NAT와 Router는 전용 subnet·region에만 연결한다.
- 로그에 URL query, 토큰, 원시 IP를 Git evidence로 남기지 않는다.
- VM, NAT, Router, bucket, network를 소유권 순서로 정리한다.

## 완료 조건

- Task 1–5 coverage와 PGA/NAT/log 세 경로의 증거가 있다.
- Extension 검토와 사용자 승인이 hash에 결합되어 있다.
- cleanup 후 Router/NAT/VM/bucket/network 잔여 수가 0이다.

## Command Code·Extension handoff 지시

Command Code는 로그 전파 지연을 실패와 구분하고 제한 시간 이후 명확히 `failed`로 남긴다. Extension은 실행 identity와 분리된 read-only MCP/API identity로 상태를 확인하며 승인을 추론하지 않는다.

## Git 종료 조건

`Phase 04: Private Google Access와 Cloud NAT 자동화 및 검증 완료` 커밋을 push한 뒤에만 Phase 05를 시작한다.
