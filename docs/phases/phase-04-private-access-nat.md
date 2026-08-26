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
| Task 2. Private Google Access 활성화하기 | automated | PGA off control/on enabled 두 VM의 동시 대조 |
| Task 3. Cloud NAT 게이트웨이 구성하기 | automated | Router/NAT 구성과 example.com HTTPS egress 성공 |
| Task 4. Cloud NAT Logging 구성 및 로그 확인하기 | automated | logging enable, traffic 발생, 구조화 NAT log 조회 |
| Task 5. Review | cli-equivalent | private API path·NAT path·log correlation 검토 |

## Task별 콘솔 확인

[하위 항목별 상세 확인](../console/phase-04.md): 원문 하위 제목/번호 절차마다 클릭 경로·값·판정·한계를 확인합니다.

[공통 확인법](../console-checks.md)을 먼저 읽고 자신의 프로젝트·해당 run만 선택한다. 아래는 **확인 기준**이지 이번 실행의 성공 기록이 아니다. 원본 Task 이름은 위 매핑과 대응한다.

| Task | 콘솔 경로·대상 | 통과 기준 | 한계·보조 확인 |
|---|---|---|---|
| 1 | Compute Engine → VM 인스턴스 → private VM | 외부 IP 없음, 올바른 subnet과 RUNNING 상태 | IAP SSH readiness는 guest evidence로 추가 확인 |
| 2 | VPC 네트워크 → 네트워크 → 해당 서브넷 상세 | Private Google Access가 사용 설정됨 | 활성화 전 실패·활성화 후 객체 읽기 성공은 저장 evidence. 현재 설정만으로 과거 전이는 입증 불가 |
| 3 | 콘솔 검색 Cloud NAT → 해당 gateway; Cloud Router → 연결 router | 리전·VPC·서브넷 범위와 NAT 설정이 승인 계획과 일치 | 현재 자동 검사는 패키지 업데이트가 아닌 HTTPS egress evidence |
| 4 | Logging → 로그 탐색기 → resource.type="nat_gateway" | 실행 시간 범위·gateway/VM에 해당하는 NAT 연결 로그 확인 | 로그 전파 지연/권한/필터를 점검. 로그 부재를 트래픽 부재로 단정하지 않음 |
| 5 | VM·서브넷·NAT·로그 탐색기 | 외부 IP 없는 VM의 Google API 경로와 일반 인터넷 NAT 경로를 구분 | 두 VM 동시 대조와 gateway/시간 기반 로그 증거. 단일 VM 전후 전이 아님 |

메뉴 확인 근거(2026-08-26): [Private Google Access 설정 위치](https://docs.cloud.google.com/vpc/docs/configure-private-google-access), [NAT 로그와 상태 확인](https://docs.cloud.google.com/nat/docs/monitoring). 화면 언어/버전에 따라 상단 검색으로 같은 서비스에 접근한다. 실제 UI 클릭 전 과정 검증은 별도다.

## 구현 작업

1. 필요한 API, IAP SSH 권한, subnet PGA 상태와 NAT quota를 점검한다.
2. VM에 외부 IP가 없음을 plan과 post-apply describe에서 확인한다.
3. PGA off control/on enabled 두 VM의 Cloud Storage 접근을 비교한다. 단일 VM의 전후 전이 실험과는 다르다.
4. NAT 제외 control/포함 enabled의 HTTPS egress를 비교한다. apt-get update 완료를 검증하지 않는다.
5. 생성 시 활성화한 NAT logging에서 gateway와 실행 시간에 해당하는 로그를 제한 시간 polling으로 찾는다. 단일 패킷의 고유 marker 검증은 아니다.

## 실행 계약

`cmd`는 모델·effort override 없이 Phase adapter를 실행한다. Google API 경로와 일반 인터넷 경로를 분리해 측정하며 log 전파 지연은 timeout 안에서 polling한다. machine verification 이후 `waiting_extension_review`로 중지한다.

## 검증 게이트

- VM access config에 외부 IPv4가 없다.
- PGA off control의 expected failure와 on enabled의 객체 접근 성공을 구분한다.
- NAT 포함 enabled에서 일반 HTTPS egress가 성공하고 NAT 상태가 정상이다.
- Cloud Logging에 해당 gateway·실행 시간대의 NAT log가 있다.
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
