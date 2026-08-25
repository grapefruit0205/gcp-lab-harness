# Phase 12 — Google Cloud HA VPN

- 원본: `references/google-cloud-labs-ko/labs/12.Configuring Google Cloud HA VPN_KR.md`
- 비용 위험: 높음
- 주요 서비스: VPC, HA VPN, Cloud Router, BGP, Compute Engine

## 목적

Google Cloud 측 전역 VPC와 시뮬레이션 온프레미스 VPC 사이에 이중 HA VPN tunnel과 BGP peer를 구성하고 route 수렴·private connectivity·global routing을 검증한다.

## 범위와 원본 매핑

| 원본 Task | 분류 | 자동화·증거 |
|---|---|---|
| Task 1. 전역(Global) VPC 환경 설정하기 | automated | VPC·regional subnet·VM·firewall topology |
| Task 2. 시뮬레이션된 온프레미스 환경 설정하기 | automated | peer VPC·VPN endpoint·test VM 구성 |
| Task 3. HA VPN 게이트웨이 설정하기 | automated | HA VPN gateway와 양쪽 Cloud Router |
| Task 4. VPN 터널 2개 생성하기 | automated | 두 interface/tunnel, 암호화 상태 |
| Task 5. 각 터널에 대해 BGP 피어링 생성하기 | automated | peer ASN·link-local range·session 상태 |
| Task 6. 라우터 구성 검증하기 | automated | router status, advertised/learned routes, remote firewall |
| Task 7. HA VPN 터널 구성 검증 및 테스트하기 | automated | tunnel/BGP health, private ping, global routing matrix |
| Task 8. (선택 사항) 실습 환경 정리하기 | automated-required | tunnel→peer→router→gateway→network 전체 cleanup |
| Task 9. Review | cli-equivalent | topology·redundancy·routing·connectivity evidence 검토 |

## 구현 작업

1. HA VPN·Router quota, region, CIDR, ASN, link-local range 충돌을 preflight한다.
2. 양쪽 topology와 두 tunnel/peer를 saved plan에 고정한다.
3. PSK를 runtime secret로 생성해 manifest에는 secret reference만 기록한다.
4. tunnel과 BGP가 모두 up 될 때까지 제한 시간 polling하고 learned route를 검증한다.
5. tunnel별·region별 private connectivity와 한 경로 장애 시 복구 동작을 측정한다.

## 실행 계약

Command Code `cmd`는 모델·effort 선택 없이 높은 비용 plan 승인을 확인한 뒤 실행한다. routing 수렴은 고정 sleep이 아닌 상태 polling을 사용한다. machine verification 후 Extension 검토 동안 최대 보존 시간을 강제한다.

## 검증 게이트

- 두 tunnel과 각 BGP session 상태가 established다.
- advertised/learned prefix가 plan과 일치하고 비의도 route가 없다.
- 양방향 private ping과 global routing matrix가 기대대로다.
- Extension은 VPN/Router/route/VM을 read-only 조회하고 PSK 노출을 검사한다.
- 사용자가 승인해야 원본 선택 cleanup을 필수 자동 cleanup으로 실행한다.

## 안전·비용 가드레일

- CIDR·ASN·BGP link-local allowlist와 tunnel 수 상한을 적용한다.
- VPN PSK를 command line, event log, Git 파일에 출력하지 않는다.
- production route와 기존 Router를 건드리지 않는 전용 VPC만 사용한다.
- cleanup 실패 시 남은 tunnel·peer·gateway를 정확한 이름 hash로 보고하고 다음 Phase를 차단한다.

## 완료 조건

- Task 1–9 coverage와 이중화·route·private connectivity 증거가 있다.
- Extension 검토·사용자 승인이 유효하다.
- cleanup 후 VPN tunnel, BGP peer, Router, gateway, VM, VPC 잔여 수가 0이다.

## Command Code·Extension handoff 지시

Command Code는 한 tunnel만 up인 상태를 전체 성공으로 보고하지 않는다. Extension은 두 경로와 route set을 독립 확인하고 수렴 중·실패·미실행을 구분해 사용자에게 보고한다.

## Git 종료 조건

`Phase 12: HA VPN 이중화 자동화 및 검증 완료` 커밋·push가 확인되어야 Phase 13으로 전이한다.
