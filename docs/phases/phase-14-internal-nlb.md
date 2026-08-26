# Phase 14 — Internal Network Load Balancer

[Phase10–15 보존형 실행·복구 안내](../phase-10-15-execution.md) · [현재 구현/오류 수정/남은 한계](../audits/phase-10-15-repair.md). 이 문서의 완료 조건은 실제 실행 후 판정할 기준이며 이번 로컬 수정의 Cloud 성공 기록이 아니다.

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

## Task별 콘솔 확인

[하위 항목별 상세 확인](../console/phase-14.md): 원문 하위 제목/번호 절차마다 클릭 경로·값·판정·한계를 확인합니다.

[공통 확인법](../console-checks.md)을 먼저 읽고 자신의 프로젝트·해당 run만 선택한다. 아래는 **확인 기준**이지 이번 실행의 성공 기록이 아니다. 원본 Task 이름은 위 매핑과 대응한다.

| Task | 콘솔 경로·대상 | 통과 기준 | 한계·보조 확인 |
|---|---|---|---|
| 1 | VPC 네트워크 → 전용 VPC → 서브넷·방화벽 | 두 subnet과 SSH/health/internal 트래픽 규칙이 계획과 일치 | CIDR/target 범위를 보며 외부 전체 허용으로 확장하지 않음 |
| 2 | Cloud NAT → run gateway; Cloud Router | backend egress용 subnet/리전 연결 일치 | NAT 존재만으로 패키지 다운로드 성공은 입증 불가 |
| 3 | Compute Engine → 템플릿·MIG·utility VM | startup 구성·MIG VM·utility VM이 기대 네트워크에서 정상 | guest 웹서버 상태와 backend health evidence 추가 |
| 4 | 네트워크 서비스 → 부하 분산 → 내부 passthrough Network LB | 내부 VIP·region·포트·backend service·health check 일치 | 외부 Application LB와 다른 종류. 외부 브라우저 접속 불가가 곧 장애는 아님 |
| 5 | utility VM → SSH 및 내부 VIP 통신 evidence | utility VM에서 internal VIP 응답·backend 식별/분산 성공 | 일반 인터넷 브라우저가 아닌 내부 경로에서 확인. 현재 설정만으로 과거 분산 증명 불가 |

메뉴 확인 근거(2026-08-26): [상태 확인 구성](https://docs.cloud.google.com/load-balancing/docs/health-checks), [VM 상세 확인](https://docs.cloud.google.com/compute/docs/instances/view-vm-details). 화면 언어/버전에 따라 상단 검색으로 같은 서비스에 접근한다. 실제 UI 클릭 전 과정 검증은 별도다.

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
- MIG 크기·VM 유형과 각 검사 polling 시간을 제한한다. NAT 자동 만료는 없으므로 명시적 종료 전 비용이 남는다.
- utility VM도 run 소유 리소스로 포함해 forwarding→backend→MIG→network 순서로 정리한다.

## 완료 조건

- Task 1–5 coverage와 internal-only connectivity·health·distribution 증거가 있다.
- Extension 검토·사용자 승인이 완료됐다.
- cleanup 후 forwarding rule, backend, MIG, utility VM, NAT, VPC 잔여 수가 0이다.

## Command Code·Extension handoff 지시

Command Code는 utility VM 내부에서 실제 data path를 검증하고 API 존재만으로 성공을 선언하지 않는다. Extension은 internal-only 경계를 확인하고 승인 전 Git 또는 cleanup을 수행하지 않는다.

## 현재 adapter

`phases/14/terraform`은 subnet 2개, 축소된 firewall 4개, regional template 2개, 서로 다른 zone의 MIG 2개, utility VM과 `10.10.30.5` internal forwarding을 만든다. verifier는 utility VM에서 각 backend IP를 먼저 직접 호출하고, 이어 VIP60회 요청 모두 성공·두 hostname marker·실제 client IP10.10.20.50을 확인하며 external instance IP가0인지 검사한다. MIG는 NAT 생성에 의존하고 startup의 apt 재시도는 유한하다. 삭제 후 inventory는 한 zone이 아닌 전체 zone을 조회하며 조회 실패를 부재로 처리하지 않는다.

## Git 종료 조건

`Phase 14: Internal Network Load Balancer 자동화 및 검증 완료` 커밋·push를 확인한 뒤 Phase 15로 이동한다.
