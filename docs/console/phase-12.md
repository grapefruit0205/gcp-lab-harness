# Phase 12 — Task 하위 항목별 콘솔 확인

[공통 준비](../console-checks.md) · [Phase 요약](../phases/phase-12-ha-vpn.md)

본인 프로젝트·RUN_ID 를 선택합니다. 확인 방법이지 실행 성공 기록은 아닙니다. **생성/삭제/편집 저장은 누르지 않습니다.** 증거는 `artifacts/runs/<RUN_ID>/phase-12/evidence/`의 `vpn-progress.json`, `phase-12-machine.json`입니다. 정상 검증 후에도 장애 실험으로 터널 하나가 삭제된 degraded 상태가 남습니다. baseline 과 현재 상태를 구분합니다.

## Task 1. 전역(Global) VPC 환경 설정하기

### VPC·두 리전 서브넷

1. **VPC networks → vpc-demo-<RUN_ID> → Subnets**를 엽니다.
2. Custom, primary10.1.1.0/24·secondary10.2.1.0/24, 서로 다른 리전, 최종 GLOBAL 을 확인합니다.
3. 실제 리전은 본인 saved input 을 기준으로 읽습니다.

### VM2·방화벽

1. **VM instances → vpc-demo-instance1/2 → NIC**, 이어 VPC firewall 의 p12-vpc-iap/from-onprem 을 엽니다.
2. 두 privateVM·해당 subnet, IAP TCP22, 원격 192.168.1.0/24 ICMP 허용을 확인합니다.
3. VM RUNNING 은 VPN 통신 성공과 다릅니다. 원문의 전체 SSH 공개 대신 IAP 로 제한했습니다.

## Task 2. 시뮬레이션된 온프레미스 환경 설정하기

### 별도 VPC·서브넷

1. **VPC → on-prem-<RUN_ID> → subnet1**을 엽니다.
2. 별도 Custom VPC,192.168.1.0/24, primaryregion, REGIONAL 인지 확인합니다.
3. 실제 회사망이 아니라 GCP 내 시뮬레이션입니다.

### 온프레미스 VM·접근 경계

1. **VM → on-prem-instance1 → NIC**, 방화벽 p12-onprem-iap/from-vpc 를 봅니다.
2. 외부 IP 없음, IAP22,10.1.1.0/24·10.2.1.0/24 ICMP 허용인지 읽습니다.
3. 현재 코드는 primary VM 과 같은 zone 입니다. 원문의 다른 zone 배치와 차이를 남깁니다.

## Task 3. HA VPN 게이트웨이 설정하기

### 양쪽 HA gateway

1. 상단 검색 **VPN → Cloud VPN gateways**에서 vpc-demo-vpn-gw1/on-prem-vpn-gw1 을 엽니다.
2. 각 VPC·동일 region·interface0/1 의 두공인주소를 확인합니다.
3. gateway 존재만으로 터널 연결 성공은 아닙니다. PSK 를 출력·공유하지 않습니다.

### Cloud Router 생성하기

1. 상단 검색 **Cloud Router → vpc-demo-router1/on-prem-router1**을 엽니다.
2. VPC 측 ASN65001, onprem 측 65002, 해당 network/region 을 대조합니다.
3. 이름 끝 run 으로 다른 실습 router 와 구분합니다.

## Task 4. VPN 터널 2개 생성하기

### interface0의 양쪽 터널

1. **VPN → Cloud VPN tunnels → vpc-demo-tunnel0/on-prem-tunnel0**를 찾습니다.
2. baseline 은 interface0·IKEv2·상대 gateway·ESTABLISHED 입니다.
3. 검증 후 vpc-demo-tunnel0 은 의도적으로 삭제됩니다. 현재 부재를 baseline 실패로 읽지 않습니다.

### interface1의 양쪽 터널

1. 같은목록에서 vpc-demo-tunnel1/on-prem-tunnel1 을 엽니다.
2. interface1·IKEv2·ESTABLISHED 와 서로의 peer 를 확인합니다.
3. 경로 1 만 정상인데 4 터널 전체 정상이라고 표시하지 않습니다.

## Task 5. 각 터널에 대해 BGP 피어링 생성하기

### VPC측 interface·peer2개

1. **Cloud Router → vpc-demo-router1 → BGP sessions**에서 tunnel0/1 을 각각 엽니다.
2. local169.254.0.1/169.254.1.1, peer169.254.0.2/169.254.1.2, /30, peerASN65002, 연결된 VPN 을 확인합니다.
3. 장애 후 경로 0 DOWN 과 초기 UP 증거를 구분합니다.

### 온프레미스측 interface·peer2개

1. on-prem-router1 의 BGP sessions 를 같은 방식으로 엽니다.
2. local169.254.0.2/169.254.1.2, peer169.254.0.1/169.254.1.1, peerASN65001 을 확인합니다.
3. UP 만으로 실제 private ping 성공은 아닙니다.

## Task 6. 라우터 구성 검증하기

### 원격 VPC에서 오는 트래픽을 허용하도록 방화벽 규칙 구성하기

1. **VPC firewall → p12-vpc-from-onprem / p12-onprem-from-vpc**를 엽니다.
2. 소스 192.168.1.0/24 ↔ 10.1.1.0/24·10.2.1.0/24, 해당 network, ICMP 허용을 대조합니다.
3. 확인을 위해 규칙을 추가하지 않습니다.

### 터널 상태 검증하기

1. VPN 터널 상태와 각 **Cloud Router → Learned routes**를 엽니다.
2. baseline4 터널 ESTABLISHED/BGP4 UP, VPC 측 학습 192.168.1.0/24, onprem 측 10.1.1.0/24·10.2.1.0/24 를 대조합니다.
3. 경로 수만 있는 것은 예상 prefix 검증이 아닙니다. 최종 fault 상태와 초기 baseline 은 별개입니다.

### VPN을 통한 프라이빗 연결 검증하기

1. VM3 개 NIC 의 privateIP 와 정제 통신 증거를 읽습니다.
2. onprem→primary/secondary 및 primary→onprem 성공을 확인합니다.
3. 콘솔 경로 목록만으로 ping 성공은 입증되지 않습니다. 지금 통신 실험을 반복할 필요는 없습니다.

### VPN을 사용한 전역 라우팅(Global routing)

1. **VPC → vpc-demo → Dynamic routing mode**와 vpn-progress 의 regional_to_global 을 봅니다.
2. REGIONAL 일 때 교차리전 미응답 → GLOBAL 전환 후 성공, 현재 GLOBAL 을 대조합니다.
3. 현재 GLOBAL 만으로 과거 전이는 입증되지 않습니다. 편집 저장하지 않습니다.

## Task 7. HA VPN 터널 구성 검증 및 테스트하기

### 삭제 대상과 재개 단계

1. vpn-progress 의 stage/deleted_tunnel 과 현재 VPN 목록을 대조합니다.
2. stage=verified, 삭제대상=currentrun vpc-demo-tunnel0 하나, 경로 1 양쪽 ESTABLISHED 인지 확인합니다.
3. fault-requested 라면 중단된 단계입니다. 확인 작업에서 delete 를 다시 누르지 않습니다.

### 살아 있는 경로의 통신

1. Cloud Router 경로 1 세션과 두 리전 privateping 증거를 봅니다.
2. 장애 후에도 primary/secondary 연결이 유지됐는지 확인합니다.
3. 복원은 새 replan/승인 apply 로 진행합니다. degraded 를 정상 4 터널 상태로 설명하지 않습니다.

## Task 8. (선택 사항) 실습 환경 정리하기

아래 8 항목은 **명시적 destroy 완료 후** 읽기 확인합니다. verify 시에는 manual-boundary/destroy_pending 이며 삭제 완료가 아닙니다. 조회오류/빈필터는 삭제 증거가 아닙니다.

### VPN 터널 삭제하기

1. **VPN → 터널**에서 run 을 검색합니다.
2. 양쪽터널 0/1 부재와 성공 inventory 를 대조합니다. 삭제 버튼은 누르지 않습니다.

### BGP 피어링 제거하기

1. 해당 Cloud Router 의 BGP 목록 또는 router 목록을 봅니다.
2. 소유 peer 부재 또는 router 전체 삭제를 확인합니다. 다른 run 은 대상이 아닙니다.

### Cloud Router 삭제하기

1. **Cloud Router**에서두이름을 검색합니다.
2. router2 개와종속 interface 부재를 확인합니다. 조회실패면 판정 보류입니다.

### VPN 게이트웨이 삭제하기

1. **VPN → gateways**에서 run 두이름을 검색합니다.
2. gateway2 개부재를 확인합니다. 터널부재만으로 gateway 삭제까지 입증하지 않습니다.

### 인스턴스 삭제하기

1. **VM instances**, **Disks**에서 run 을 검색합니다.
2. VM3 개와 bootdisk 부재를 확인합니다. 다른 Phase 는 보존합니다.

### 방화벽 규칙 삭제하기

1. **VPC firewall rules**에서 run 을 검색합니다.
2. p12 IAP·ICMP4 개부재를 확인합니다. 공통방화벽은 삭제대상이 아닙니다.

### 서브넷 삭제하기

1. **VPC subnets**에서 run 을검색하고리전필터를 확인합니다.
2. VPC2 개 subnet/onprem1 개부재를 확인합니다.

### VPC 삭제하기

1. **VPC networks**에서 vpc-demo/on-prem 두이름을 검색합니다.
2. 두 VPC 부재와 manifest cleanup.completed 를 대조합니다. 공통 API 활성유지와 run 리소스잔여를 구분합니다.

## Task 9. Review

### 토폴로지·전이·장애·정리

1. Task1–8 을 baseline → GLOBAL 전이 → fault 후 → 최종 destroy 시간순으로 읽습니다.
2. 각시점의성공/미수행/현재잔여를 따로기록합니다.
3. destroy 승인전에는 자동검증 성공과 실습종료 완료를 같게 쓰지 않습니다.

## 출처·검증 범위

2026-08-26 원문 12·코드 대조(observed), 실제 UI/Cloud 수렴 미검증. [Cloud Router 상세·경로 확인](https://docs.cloud.google.com/network-connectivity/docs/router/how-to/viewing-router-details).
