# Phase 12 — Google Cloud HA VPN

[Phase10–15 보존형 실행·복구 안내](../phase-10-15-execution.md) · [현재 구현/오류 수정/남은 한계](../audits/phase-10-15-repair.md). 이 문서의 완료 조건은 실제 실행 후 판정할 기준이며 이번 로컬 수정의 Cloud 성공 기록이 아니다.

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
| Task 8. (선택 사항) 실습 환경 정리하기 | manual-boundary | 명시적 저장 destroy 계획 승인 후 정리; verify만으로 완료 처리하지 않음 |
| Task 9. Review | cli-equivalent | topology·redundancy·routing·connectivity evidence 검토 |

## Task별 콘솔 확인

[하위 항목별 상세 확인](../console/phase-12.md): 원문 하위 제목/번호 절차마다 클릭 경로·값·판정·한계를 확인합니다.

[공통 확인법](../console-checks.md)을 먼저 읽고 자신의 프로젝트·해당 run만 선택한다. 아래는 **확인 기준**이지 이번 실행의 성공 기록이 아니다. 원본 Task 이름은 위 매핑과 대응한다.

| Task | 콘솔 경로·대상 | 통과 기준 | 한계·보조 확인 |
|---|---|---|---|
| 1 | VPC 네트워크 → Google Cloud 측 전용 VPC → 서브넷 | 계획의 리전/CIDR·VM·방화벽·global 동적 라우팅 모드 일치 | CIDR 겹침과 다른 run 네트워크 선택에 주의 |
| 2 | VPC 네트워크 → 온프레미스 시뮬레이션 VPC | 별도 VPC/서브넷/테스트 VM과 VPN endpoint 구성 일치 | 실제 외부 회사망이 아니라 GCP 내 시뮬레이션 |
| 3 | 콘솔 검색 VPN → Cloud VPN 게이트웨이; Cloud Router | 양쪽 HA gateway의 interface와 router가 계획과 일치 | gateway 존재만으로 tunnel 연결 성공은 아님 |
| 4 | VPN → Cloud VPN 터널 → 해당 run의 양쪽 터널 | 양쪽 경로 tunnel 상태 Established와 예상 peer/interface | 한 경로만 정상인데 이중화 전체 완료로 표시하지 않음 |
| 5 | Cloud Router → 각 router → BGP 세션 | 각 터널의 peer ASN·link-local IP·세션 UP 일치 | BGP UP만으로 실제 응용 통신 성공은 아님 |
| 6 | Cloud Router → router 상세/경로; VPC → 방화벽 | 광고·학습된 원격 subnet prefix와 방화벽이 일치 | 리전/라우팅 모드와 예상 경로를 saved plan과 대조 |
| 7 | VPN tunnel 상태 + Cloud Router 경로 + 테스트 VM | 초기4터널/BGP 정상 → 단일 터널 장애 후 경로1·private ping 유지 | 콘솔 경로만으로 ping 성공은 입증 불가. 저장 통신 evidence 필요 |
| 8 | 명시적 destroy 후 VPN·Cloud Router·VPC·VM 목록 | 현재 run tunnel/peer/router/gateway/network/VM 잔여0 | 검증 직후에는 유지 가능. 다른 Phase 리소스/공통 API를 삭제하지 않음 |
| 9 | Task1–8 화면·evidence | 구성/이중 경로/실제 통신과 최종 정리 상태를 구분 | 정리 미실행은 미실행으로 표시하고 전체 완료를 과장하지 않음 |

메뉴 확인 근거(2026-08-26): [Cloud Router 상세·BGP·경로 확인](https://docs.cloud.google.com/network-connectivity/docs/router/how-to/viewing-router-details). 화면 언어/버전에 따라 상단 검색으로 같은 서비스에 접근한다. 실제 UI 클릭 전 과정 검증은 별도다.

## 구현 작업

1. HA VPN·Router quota, region, CIDR, ASN, link-local range 충돌을 preflight한다.
2. 양쪽 topology와 두 tunnel/peer를 saved plan에 고정한다.
3. PSK를 runtime secret로 생성해 manifest에는 secret reference만 기록한다.
4. tunnel과 BGP가 모두 up 될 때까지 제한 시간 polling하고 learned route를 검증한다.
5. tunnel별·region별 private connectivity와 한 경로 장애 시 복구 동작을 측정한다.

## 실행 계약

Command Code `cmd`는 모델·effort 선택 없이 높은 비용 plan 승인을 확인한 뒤 실행한다. routing 수렴은 고정 sleep이 아닌 상태 polling을 사용한다. machine verification 뒤에도 리소스를 보존한다. 자동 만료/비용 종료 스케줄러는 없으므로 비용을 확인하고 별도 destroy 계획을 승인해야 한다.

## 검증 게이트

- baseline에서 양쪽 tunnel4개·BGP4개가 정상이며 장애 후에는 살아 있는 경로1 쌍이 정상이다.
- router bestRoutes에 필요한 원격 prefix가 포함되어 있다. 모든 비의도 route 부재까지 검사하는 것은 아니다.
- 양방향 private ping과 global routing matrix가 기대대로다.
- Extension은 VPN/Router/route/VM을 read-only 조회하고 PSK 노출을 검사한다.
- 선택 Task8은 manual-boundary/destroy_pending이다. 별도 saved destroy plan 승인 전에는 삭제하지 않는다.

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

## 현재 adapter

`phases/12/terraform`은 gateway 2개, Router 2개, 양방향 tunnel 4개, interface·BGP peer 각 4개와 VM 3개를 소유한다. verifier는 baseline의 tunnel 4개·peer 4개가 모두 정상이고 양방향·교차 region ping이 성공한 뒤 원본 절차대로 `vpc-demo-tunnel0` 한쪽을 삭제하고 surviving tunnel1 경로를 다시 확인한다. Extension에는 baseline evidence와 현재 degraded topology를 함께 전달한다.

## Git 종료 조건

`Phase 12: HA VPN 이중화 자동화 및 검증 완료` 커밋·push가 확인되어야 Phase 13으로 전이한다.
