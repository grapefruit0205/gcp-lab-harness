# Phase 03 — VPC Networking

- 원본: `references/google-cloud-labs-ko/labs/03.VPC Networking_KR.md`
- 비용 위험: 중간
- 주요 서비스: VPC, subnet, route, firewall, Compute Engine

## 목적

기본·auto mode·custom mode VPC의 차이, 지역별 subnet과 route, firewall, VM 간 내·외부 연결성을 CLI 상태와 실제 packet path로 검증한다.

## 범위와 원본 매핑

| 원본 Task | 분류 | 자동화·증거 |
|---|---|---|
| Task 1. 기본(default) 네트워크 살펴보기 | conditional | 전용 프로젝트의 default VPC describe·삭제·예상 VM 생성 실패 |
| Task 2. auto mode 네트워크 생성하기 | automated | auto VPC, firewall, 미국·유럽 VM, 연결성; custom 전환은 현재 미구현 |
| Task 3. custom mode 네트워크 생성하기 | automated | managementnet·privatenet, subnet·firewall·VM 생성 |
| Task 4. 네트워크 간 연결성 살펴보기 | automated | 외부 IP 성공 matrix, 라우팅 없는 내부 IP expected failure |
| Task 5. Review | cli-equivalent | topology와 connectivity matrix 검토 |

## Task별 콘솔 확인

[하위 항목별 상세 확인](../console/phase-03.md): 원문 하위 제목/번호 절차마다 클릭 경로·값·판정·한계를 확인합니다.

[공통 확인법](../console-checks.md)을 먼저 읽고 자신의 프로젝트·해당 run만 선택한다. 아래는 **확인 기준**이지 이번 실행의 성공 기록이 아니다. 원본 Task 이름은 위 매핑과 대응한다.

| Task | 콘솔 경로·대상 | 통과 기준 | 한계·보조 확인 |
|---|---|---|---|
| 1 | VPC 네트워크 → VPC 네트워크 → default; 해당 실행의 조건부 Task 결과 | 전용 프로젝트 승인 여부와 default 작업/예상 실패 결과가 기록됨 | 콘솔에서 임의로 default를 삭제하지 않음. skip/blocked를 성공으로 바꾸지 않음 |
| 2 | VPC 네트워크 → 해당 auto 생성 네트워크 → 서브넷 | 미국·유럽 VM/서브넷이 계획과 같고 현재 모드는 auto | 원문의 auto→custom 전환은 미구현. custom 완료로 표시하지 않음 |
| 3 | VPC 네트워크 → managementnet·privatenet 계열 run 네트워크 | 서브넷 리전/CIDR·방화벽 대상·VM NIC가 각각의 계획과 일치 | 이름만 같은 다른 run을 고르지 않음 |
| 4 | Compute Engine → 각 VM의 네트워크 인터페이스; VPC → 경로 | 외부/내부 주소 및 네트워크 간 경로가 설계와 일치 | 실제 외부 성공/격리된 내부 실패는 출발 VM별 connectivity matrix 필요 |
| 5 | VPC·방화벽·경로·VM 목록 | 각 VM의 소속 네트워크와 성공/실패 연결 행렬을 대조 | 리소스 존재만으로 packet 경로 성공을 선언하지 않음 |

메뉴 확인 근거(2026-08-26): [VPC 네트워크와 경로](https://docs.cloud.google.com/vpc/docs/vpc). 화면 언어/버전에 따라 상단 검색으로 같은 서비스에 접근한다. 실제 UI 클릭 전 과정 검증은 별도다.

## 구현 작업

1. 프로젝트가 전용·비운영인지 확인하고 기존 default VPC 소유 경계를 기록한다.
2. VPC, subnet, route, firewall, VM 변경을 plan하고 CIDR 중복을 검사한다.
3. auto mode VPC와 두 custom VPC를 구성한다. 원문의 auto→custom 전환과 private 유럽 subnet은 현재 구현되지 않았다. 상세 안내에 차이를 표시한다.
4. 각 VM에서 출발지·목적지·주소 종류별 ping/SSH matrix를 수집한다.
5. 예상 실패는 오류 코드와 route 부재를 함께 증명한다.

## 실행 계약

Command Code `cmd`는 저장된 plan과 run manifest를 사용하며 현재 고정 모델을 상속한다. default VPC 삭제는 전용 프로젝트 확인이 없으면 거부한다. machine verification이 끝나면 리소스를 유지한 채 Extension 검증을 기다린다.

## 검증 게이트

- auto mode subnet과 route가 Google Cloud가 보고한 기대 지역 집합과 일치한다.
- custom VPC의 CIDR·firewall target·VM NIC가 plan과 일치한다.
- 연결성 matrix의 성공·실패가 VPC 격리와 route 설계에 부합한다.
- Extension은 `gcloud ... describe/list`와 diff를 read-only로 재검증한다.
- 사용자의 명시 승인 전에는 destroy·commit·push를 하지 않는다.

## 안전·비용 가드레일

- 기존 네트워크는 run 소유가 아니면 삭제하지 않는다.
- SSH/ICMP source range와 target tag를 최소화한다.
- VM 수·리전·machine type을 allowlist로 제한한다.
- 정리 순서는 VM, firewall, subnet, VPC이며 각 단계 inventory를 남긴다.

## 완료 조건

- Task 1–5가 모두 분류되고 topology·연결성 evidence가 있다.
- expected success와 expected failure가 모두 기계 판독으로 통과한다.
- 승인 후 cleanup inventory의 run 소유 리소스 수가 0이다.

## Command Code·Extension handoff 지시

Command Code는 연결 명령의 종료 코드만 보지 말고 source/destination matrix를 남긴다. Extension은 네트워크 구성과 실제 path evidence를 독립 조회하고 사용자에게 잔여 위험을 보고한다.

## Git 종료 조건

`Phase 03: VPC 네트워킹 자동화 및 검증 완료` 커밋을 push하고 remote SHA를 확인한 뒤 Phase 04로 이동한다.
