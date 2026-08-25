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
| Task 2. auto mode 네트워크 생성하기 | automated | auto VPC, firewall, 미국·유럽 VM, 연결성, custom mode 변환 |
| Task 3. custom mode 네트워크 생성하기 | automated | managementnet·privatenet, subnet·firewall·VM 생성 |
| Task 4. 네트워크 간 연결성 살펴보기 | automated | 외부 IP 성공 matrix, 라우팅 없는 내부 IP expected failure |
| Task 5. Review | cli-equivalent | topology와 connectivity matrix 검토 |

## 구현 작업

1. 프로젝트가 전용·비운영인지 확인하고 기존 default VPC 소유 경계를 기록한다.
2. VPC, subnet, route, firewall, VM 변경을 plan하고 CIDR 중복을 검사한다.
3. auto mode와 custom mode 변환, 두 custom VPC 구성을 적용한다.
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
