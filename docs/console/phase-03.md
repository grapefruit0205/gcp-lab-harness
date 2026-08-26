# Phase 03 — Task 하위 항목별 콘솔 확인

[공통 준비](../console-checks.md) · [Phase 요약](../phases/phase-03-vpc-networking.md)

확인 안내이며 실제 Cloud 성공 기록이 아닙니다. `<RUN_ID>`·`<PROJECT_ID>`는 본인의 실행 값입니다. 읽기 전용으로 확인하며 생성·편집 저장·삭제·비밀번호 재설정은 하지 않습니다. 현재 값과 과거 검증 증거를 구분합니다. 로컬 증거는 `artifacts/runs/<RUN_ID>/phase-03/evidence/phase-03-machine.json`입니다.

원문 `03.VPC Networking_KR.md`와의 차이: 현재 `mynetwork`는 auto=true이며 conversion은 `blocked-separate-approved-plan-required`입니다. private EU subnet은 현 Terraform에 없습니다. 외부 ICMP는 승인 client에서 VM4대로 검사하므로 원문의 US VM→3VM matrix와 다릅니다. default 삭제도 수행하지 않습니다.

## Task 1. 기본(default) 네트워크 살펴보기

### 서브넷 확인하기

1. 화면 열기·값 대조: VPC 네트워크 → VPC 네트워크 → `default`가 실제 있을 때만 선택 → 서브넷 목록에서 리전·CIDR·게이트웨이 읽기.
2. 판정·한계·보조 증거: default 는 조직정책/이전작업에 따라 없을 수 있다. 생성하지 않으며 `.checks.default_vpc_describe_only=manual-boundary`.

### 라우트 확인하기

1. 화면 열기·값 대조: VPC 네트워크 → 경로 → 네트워크 default 와 해당 리전 선택 → subnet 경로 및 `0.0.0.0/0` default internet gateway 경로 확인.
2. 판정·한계·보조 증거: default 가 없으면 해당 경로 조회 대상도 없음. 전용 프로젝트에 다른 경로가 있다고 실습 실패로 단정하지 않음.

### 방화벽 규칙 확인하기

1. 화면 열기·값 대조: VPC 네트워크 → 방화벽 정책 → VPC 방화벽 규칙 → 네트워크 default 필터 → 이름·소스·대상·프로토콜 열 확인.
2. 판정·한계·보조 증거: 원문 default-allow 4 개가 개인 프로젝트에도 반드시 있는 것은 아님. 현재 정책 관찰과 원문 기대값을 구분.

### 방화벽 규칙 삭제하기

1. 화면 열기·값 대조: 같은 default 필터로 현재 규칙을 읽고 실행 evidence 의 default 작업 경계를 확인.
2. 판정·한계·보조 증거: 현 자동화는 다른 소유자의 default 규칙을 삭제하지 않는다. 원문 삭제 완료로 표시하지 않으며 확인용 삭제 금지.

### 기본(default) 네트워크 삭제하기

1. 화면 열기·값 대조: VPC 목록/경로/방화벽 목록에서 default 의 현재 존재 여부를 기록한다.
2. 판정·한계·보조 증거: 코드의 describe-only 는 삭제 실습 미수행. 부재만으로 이번 run 이 삭제했다는 증거가 아님.

### VM 인스턴스 생성 시도하기

1. 화면 열기·값 대조: 정제 evidence 에서 default/network 미존재 예상 오류를 실제 기록했는지 확인한다.
2. 판정·한계·보조 증거: 현 코드에는 생성 실패 재현이 없으므로 미수행. 콘솔 생성 버튼으로 오류를 재현하지 않는다.

## Task 2. auto mode 네트워크 생성하기

### 방화벽 규칙을 가진 auto mode VPC 네트워크 생성하기

1. 화면 열기·값 대조: VPC → `mynetwork-<RUN_ID>` → 모드 Automatic 및 리전별 자동 서브넷 확인 → 방화벽에서 `auto-iap-ssh`, `auto-client-icmp`, `auto-internal-icmp` run 규칙 확인.
2. 판정·한계·보조 증거: 원문 전체 SSH/RDP 공개 대신 SSH IAP·ICMP 승인 source 제한. `.checks.auto_vpc_regions_and_internal_connectivity`와 대조.

### us-central1 리전에 VM 인스턴스(mynet-us-vm) 생성하기

1. 화면 열기·값 대조: VM 목록 → `mynet-us-vm-<RUN_ID>` → saved primary zone/e2-micro/Debian12 → NIC network 가 mynetwork 인지 확인.
2. 판정·한계·보조 증거: 이름의 us 대신 실제 saved zone 을 기준으로 판정. 본인 설정의 primary region 을 원문 값으로 바꾸지 않음.

### europe-west1 리전에 VM 인스턴스(mynet-eu-vm) 생성하기

1. 화면 열기·값 대조: VM 목록 → `mynet-eu-vm-<RUN_ID>` → saved secondary zone/e2-micro/Debian12 → 동일 mynetwork 의 해당 리전 subnet 확인.
2. 판정·한계·보조 증거: primary/secondary 가 원문 리전과 다른 경우 승인 입력 차이를 명시.

### VM 인스턴스의 연결성 확인하기

1. 화면 열기·값 대조: 두 VM 상세 NIC 에서 내부/외부 IP 와 network 를 나란히 확인 → 정제 evidence 의 auto internal success 와 external matrix 대조.
2. 판정·한계·보조 증거: 실제 US→EU 내부 ping 은 검사하지만 외부는 승인 client→각 VM 이며 원문 US→EU 외부 ping 과 다름. 현재 NIC 화면만으로 ping 성공을 입증 못 함.

### 네트워크를 custom mode 네트워크로 변환하기

1. 화면 열기·값 대조: VPC → mynetwork → 서브넷 생성 모드 확인 → `.checks.auto_to_custom_conversion` 읽기.
2. 판정·한계·보조 증거: 현 정상 자동화 결과는 Automatic 유지 및 blocked-separate-approved-plan-required. Custom 으로 바꾸기 위해 Edit/Save 누르지 않으며 완료로 표시하지 않음.

## Task 3. custom mode 네트워크 생성하기

### managementnet 네트워크 생성하기

1. 화면 열기·값 대조: VPC → `managementnet-<RUN_ID>` → Custom → `managementsubnet-<RUN_ID>` → saved region 와 `10.130.0.0/20` 확인.
2. 판정·한계·보조 증거: 원문 UI/Equivalent Command line 클릭은 자동화와 별개.

### privatenet 네트워크 생성하기

1. 화면 열기·값 대조: VPC → `privatenet-<RUN_ID>` → Custom → `privatesubnet-<RUN_ID>` → saved primary region·`172.16.0.0/24` 확인.
2. 판정·한계·보조 증거: 원문 `privatesubnet-eu 172.20.0.0/20`은 현 코드 미구현이므로 없는 것이 자동화와 일치하되 원문 전체완료 아님.

### managementnet의 방화벽 규칙 생성하기

1. 화면 열기·값 대조: VPC 방화벽 규칙 → `management-iap-ssh-<RUN_ID>` 및 `management-client-icmp-<RUN_ID>` → network managementnet, target p03-management, TCP22/IAP 와 ICMP/승인 CIDR 확인.
2. 판정·한계·보조 증거: 원문 RDP3389·전체 source 와 다름. 허용 확대하지 않음.

### privatenet의 방화벽 규칙 생성하기

1. 화면 열기·값 대조: 방화벽 목록 → `private-iap-ssh-<RUN_ID>` 및 `private-client-icmp-<RUN_ID>` → network privatenet·target p03-private·IAP22/제한 ICMP 확인.
2. 판정·한계·보조 증거: 원문 한 규칙 대신 두 규칙, RDP 미개방. Equivalent Command line 사용 여부는 미확인.

### managementnet-us-vm 인스턴스 생성하기

1. 화면 열기·값 대조: VM → `managementnet-vm-<RUN_ID>` → e2-micro/Debian12/savedzone → NIC managementnet 및 managementsubnet 확인.
2. 판정·한계·보조 증거: 원문의 이름과 다르므로 run 이름으로 찾는다.

### privatenet-us-vm 인스턴스 생성하기

1. 화면 열기·값 대조: VM → `privatenet-vm-<RUN_ID>` → e2-micro/Debian12/savedzone → NIC privatenet/privatesubnet 확인 → 목록 열의 Zone 으로 네 VM 분포 대조.
2. 판정·한계·보조 증거: NIC 상 같은 zone 이어도 다른 VPC 다. 원문 VM 명칭 그대로 검색하면 누락될 수 있음.

## Task 4. 네트워크 간 연결성 살펴보기

### 외부 IP 주소로 ping 보내기

1. 화면 열기·값 대조: VM4 개 상세에서 external IP 가 있는지 확인 → 방화벽 client ICMP source 가 승인 CIDR 인지 대조 → `.checks.external_connectivity_matrix` 확인.
2. 판정·한계·보조 증거: 현 probe 출발지는 로컬 승인 client 이며 원문 mynet-us→EU/management/private 외부 경로를 모두 검사한 것은 아님. 공개 0/0 로 변경하지 않는다.

### 내부 IP 주소로 ping 보내기

1. 화면 열기·값 대조: mynetwork US/EU 두 VM 은 같은 VPC 인지, management/private 는 별개 VPC 인지 확인 → 경로/피어링 목록에서 두 custom 사이 연결 없음 확인.
2. 판정·한계·보조 증거: 코드 성공은 US→EU 내부, 실패는 management→private 한 경로다. 원문 US→management/private 실패와 동일 전수행렬이라 쓰지 않음. SSH 자체 실패도 구분 필요.

## Task 5. Review

### 개인 프로젝트에서 실습 리소스 정리하기

1. 화면 열기·값 대조: 명시적 destroy 후 VM4 개·위 run 방화벽·subnet2 개·VPC3 개 이름을 각 서비스 목록에서 조회하고 삭제 inventory 와 대조.
2. 판정·한계·보조 증거: 원문 삭제 명령 재실행 금지. default 및 타 run 은 별도소유다. 현재 리소스가 있으면 확인만 하고 전체 정리 완료로 쓰지 않음.

## 출처·검증 범위

원문: [보존된 실습 03](../../references/google-cloud-labs-ko/labs/03.VPC%20Networking_KR.md). 2026-08-26 에 원문 하위 제목과 현재 코드의 대조를 수행했습니다(observed). 메뉴의 공식 설명은 Phase 요약의 근거 링크를 참고합니다. 실제 콘솔 클릭·Cloud 통합 성공은 별도 검증입니다.
