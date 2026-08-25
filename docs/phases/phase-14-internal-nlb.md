# Phase 14 — Internal Network Load Balancer

- 원본: `references/google-cloud-labs-ko/labs/14.Configure an Internal Network Load Balancer_KR.md`
- 비용 위험: 높음
- 주요 서비스: VPC, Cloud NAT, MIG, regional internal passthrough Network Load Balancer

## 목적

전용 VPC·subnet·firewall·NAT·MIG를 구성하고 internal Network Load Balancer를 통해 내부 utility VM에서 backend 분산과 health를 검증한다.

## 범위와 원본 매핑

| 원본 Task | 분류 | 자동화·증거 |
|---|---|---|
| Task 1. my-internal-app VPC 네트워크 및 방화벽 규칙 구성하기 | automated | 두 subnet과 SSH/health/internal traffic 규칙 |
| Task 2. Cloud Router를 사용하여 NAT 구성하기 | automated | Router/NAT와 backend package egress |
| Task 3. 인스턴스 템플릿 구성 및 인스턴스 그룹 생성하기 | automated | startup script, template, MIG, backend health, utility VM |
| Task 4. Internal Network Load Balancer 구성하기 | automated | regional health check·backend service·internal forwarding rule |
| Task 5. Internal Network Load Balancer 테스트하기 | automated | utility VM의 internal VIP 반복 curl과 backend distribution |

## 구현 작업

1. region, subnet CIDR, internal IP, quota와 firewall source를 preflight한다.
2. network부터 internal forwarding rule까지 dependency plan을 저장한다.
3. immutable startup script와 template로 MIG를 만들고 health를 polling한다.
4. internal VIP를 예약·연결하고 utility VM에서만 접근을 시험한다.
5. 반복 요청의 backend marker와 connection 결과를 구조화한다.

## 실행 계약

Command Code `cmd`는 별도 모델 설정 없이 saved plan을 실행한다. external client에서의 실패와 internal client에서의 성공을 명확히 구분한다. machine verification 뒤 utility VM과 backend를 Extension 검증용으로 유지한다.

## 검증 게이트

- subnet·firewall·NAT·MIG·backend·forwarding rule이 동일 region과 plan에 맞는다.
- backend health가 정상이고 internal VIP가 utility VM에서 응답한다.
- 반복 요청에서 기대하는 backend 분산 또는 session 특성이 관찰된다.
- 외부 접근 경로가 생성되지 않았음을 확인한다.
- Extension은 read-only API와 내부 client evidence를 검토하고 사용자가 승인한다.

## 안전·비용 가드레일

- internal VIP와 CIDR은 충돌 검사 후 run 전용 범위를 쓴다.
- management ingress와 health source를 최소화하고 external forwarding rule을 금지한다.
- MIG 크기·VM 유형·NAT 실행 시간에 상한을 둔다.
- utility VM도 run 소유 리소스로 포함해 forwarding→backend→MIG→network 순서로 정리한다.

## 완료 조건

- Task 1–5 coverage와 internal-only connectivity·health·distribution 증거가 있다.
- Extension 검토·사용자 승인이 완료됐다.
- cleanup 후 forwarding rule, backend, MIG, utility VM, NAT, VPC 잔여 수가 0이다.

## Command Code·Extension handoff 지시

Command Code는 utility VM 내부에서 실제 data path를 검증하고 API 존재만으로 성공을 선언하지 않는다. Extension은 internal-only 경계를 확인하고 승인 전 Git 또는 cleanup을 수행하지 않는다.

## 현재 adapter

`phases/14/terraform`은 subnet 2개, 축소된 firewall 4개, regional template 2개, 서로 다른 zone의 MIG 2개, utility VM과 `10.10.30.5` internal forwarding을 만든다. verifier는 utility VM에서 각 backend IP를 먼저 직접 호출하고, 이어 VIP 60회 요청에서 두 hostname marker가 모두 나오는지 확인하며 external instance IP가 0인지 검사한다.

## Git 종료 조건

`Phase 14: Internal Network Load Balancer 자동화 및 검증 완료` 커밋·push를 확인한 뒤 Phase 15로 이동한다.
