# Phase 04 — Task 하위 항목별 콘솔 확인

[공통 준비](../console-checks.md) · [Phase 요약](../phases/phase-04-private-access-nat.md)

확인 안내이며 실제 Cloud 성공 기록이 아닙니다. `<RUN_ID>`·`<PROJECT_ID>`는 본인의 실행 값입니다. 읽기 전용으로 확인하며 생성·편집 저장·삭제·비밀번호 재설정은 하지 않습니다. 현재 값과 과거 검증 증거를 구분합니다. 로컬 증거는 `artifacts/runs/<RUN_ID>/phase-04/evidence/phase-04-machine.json`입니다.

원문 `04.Implement Private Google Access and Cloud NAT_KR.md`. **동시 대조 구현**: `vm-control-<RUN_ID>`/`privatenet-control-<RUN_ID>`는 PGA off/NAT 제외, `vm-enabled-<RUN_ID>`/`privatenet-enabled-<RUN_ID>`는 PGA on/NAT 포함. 원문 한 VM 의 전후 변경 이력으로 설명하면 안 된다.

## Task 1. VM 인스턴스 생성하기

### VPC 네트워크와 방화벽 규칙 생성하기

1. 화면 열기·값 대조: VPC → `privatenet-<RUN_ID>` → Custom → subnet control `10.130.0.0/24`, enabled `10.130.1.0/24` 확인 → `privatenet-iap-ssh-<RUN_ID>`에서 TCP22/IAP `35.235.240.0/20`/tag p04-iap 확인.
2. 판정·한계·보조 증거: 원문 `10.130.0.0/20` 1 개와 달리 대조용 2 개이며 savedplan 기준.

### 공개 IP 주소가 없는 VM 인스턴스 생성하기

1. 화면 열기·값 대조: Compute → VM 목록 → control/enabled 각각 RUNNING → NIC 에서 대응 subnet 및 외부 IPv4 없음 확인.
2. 판정·한계·보조 증거: 현 머신 e2-micro, 원문 e2-medium 과 차이. `.checks.no_external_ip`만으로 실제 IAP 성공 아님.

### IAP 터널을 테스트하기 위해 vm-internal에 SSH 접속하기

1. 화면 열기·값 대조: control VM 의 기존 허용 IAP SSH 세션에서 연결대상 hostname 만 읽기 확인하고 정제 probe evidence 대조.
2. 판정·한계·보조 증거: 일반인터넷 실패는 control 측 egress evidence, NAT 이후 enabled 실패를 기대하면 안 됨. 확인용 ping/트래픽 재생성 불필요.

## Task 2. Private Google Access 활성화하기

### Cloud Storage 버킷 생성하기

1. 화면 열기·값 대조: Cloud Storage → `gcp-lab-p04-<RUN_ID>` → 구성 US/Standard, 권한 PAP enforced/균일액세스 확인.
2. 판정·한계·보조 증거: 새버킷 생성/공개권한해제 금지.

### 이미지 파일을 버킷에 복사하기

1. 화면 열기·값 대조: 버킷 → 객체 → `access.svg` → 이름/Content-Type image/svg+xml 및 미리보기 확인.
2. 판정·한계·보조 증거: 자동화는 외부 cloud-training 파일 복사 대신 자체 SVG fixture. 원문 이미지와 픽셀/바이트 동일을 기대하지 않음.

### VM 인스턴스에서 이미지에 액세스하기

1. 화면 열기·값 대조: control/enabled VM 의 NIC subnet 과 같은 workload SA 를 대조 → evidence 의 `pga_disabled_storage_expected_failure`/`pga_enabled_storage_success`를 각각 확인.
2. 판정·한계·보조 증거: Storage 콘솔에서 본인으로 이미지를 읽는 것은 VM SA 의 읽기증거가 아님. 실패오류/전송경계 대조 필요.

### Private Google Access 활성화하기

1. 화면 열기·값 대조: VPC → privatenet → 서브넷 → control 은 Private Google Access Off, enabled 는 On 인지 각각 상세에서 읽기.
2. 판정·한계·보조 증거: on/off 전후변경 실습이 아닌 두서브넷 동시대조. 편집하여 전환하지 않는다.

## Task 3. Cloud NAT 게이트웨이 구성하기

### VM 인스턴스 업데이트 시도하기

1. 화면 열기·값 대조: control subnet 이 NAT 적용목록에 없는지 확인 → evidence `nat_excluded_egress_expected_failure` 대조.
2. 판정·한계·보조 증거: 현 코드는 apt-get update 가 아니라 example.com HTTPS probe. 패키지색인 업데이트 완료라고 쓰지 않음.

### Cloud NAT 게이트웨이 구성하기

1. 화면 열기·값 대조: 상단검색 Cloud NAT → `nat-config-<RUN_ID>` → network privatenet·savedregion·router `nat-router-<RUN_ID>` 확인 → NAT mapping 에 enabled subnet 만 있는지 확인.
2. 판정·한계·보조 증거: control 이 포함되면 비교의미가 사라짐. 공인 IP 자동할당 AUTO_ONLY 이며 VMinbound 개방기능 아님.

### Cloud NAT 게이트웨이 확인하기

1. 화면 열기·값 대조: NAT 상세 상태/매핑과 enabled NIC 를 대조 → `nat_enabled_egress_success` 확인.
2. 판정·한계·보조 증거: NAT Running 만으로 앱통신/apt 성공 아님. 현 증거는 HTTPS 일반 egress.

## Task 4. Cloud NAT Logging 구성 및 로그 확인하기

### 로깅 활성화하기

1. 화면 열기·값 대조: Cloud NAT → nat-config → 상세 Logging 에서 Translation and errors/ALL 활성 확인.
2. 판정·한계·보조 증거: 원문 생성후설정전환 대신 Terraform 에서 시작부터 활성. Edit/Save 누르지 않음.

### Cloud Logging에서 NAT 로깅 확인하기

1. 화면 열기·값 대조: NAT 상세 → View in Logs Explorer → 실행 시간 범위 설정 → `resource.type="nat_gateway"` 및 해당 gateway 명필터 확인.
2. 판정·한계·보조 증거: raw 로그 공유금지. 새로그 없음은 필터/지연/권한/보존기간 문제일 수 있음.

### 로그 생성하기

1. 화면 열기·값 대조: 같은 로그 탐색기에서 이미 검증이 트래픽을 발생시킨 시각의 항목을 펼쳐 VM/게이트웨이/연결 정보를 읽는다.
2. 판정·한계·보조 증거: 확인 목적으로 apt-get update·부하를 재실행하지 않는다. 현기계증거는 고유 marker 가 아니라 gateway/time 기반이므로 완전한 단일패킷상관관계 주장금지.

### 로그 확인하기

1. 화면 열기·값 대조: 로그행 확장 → resource labels 의 gateway/region, timestamp 를 run 실행정보와 대조 → 정제 `nat_log_record_sha256`/`nat_log_correlated` 확인.
2. 판정·한계·보조 증거: 원문 ‘로그 2 개’를 고정기대값으로 쓰지 않음. 로그부재가 트래픽부재는 아니다.

## Task 5. Review

### 검토할 세부 항목

1. 두 VM 외부 IP 없음, control/enabled 별 API 읽기/일반 egress 의 서로 다른 결과, NAT mapping·로그를 각각 확인했다는 범위만 기록한다.
2. 위 화면별 확인 값과 로컬 정제 증거의 상태·실행 시각을 각각 비교합니다. 미수행·수동 경계를 통과로 바꾸지 않습니다. 삭제했다면 현재 목록 부재와 삭제 전 증거를 나눠 기록합니다.

## 출처·검증 범위

원문: [보존된 실습 04](../../references/google-cloud-labs-ko/labs/04.Implement%20Private%20Google%20Access%20and%20Cloud%20NAT_KR.md). 2026-08-26 에 원문 하위 제목과 현재 코드의 대조를 수행했습니다(observed). 메뉴의 공식 설명은 Phase 요약의 근거 링크를 참고합니다. 실제 콘솔 클릭·Cloud 통합 성공은 별도 검증입니다.
