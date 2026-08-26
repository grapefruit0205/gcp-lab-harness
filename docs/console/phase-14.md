# Phase 14 — Task 하위 항목별 콘솔 확인

[공통 준비](../console-checks.md) · [Phase 요약](../phases/phase-14-internal-nlb.md)

본인 프로젝트·RUN_ID 를 선택합니다. 확인 방법이지 실제 성공 기록이 아닙니다. 생성/수정/삭제/부하를 실행하지 않습니다. 증거는 `artifacts/runs/<RUN_ID>/phase-14/evidence/`입니다. 두 zone 은같은 region 이며 zone_two 는저장 tfvars/output 기준입니다.

## Task 1. my-internal-app VPC 네트워크 및 방화벽 규칙 구성하기

### 1. VPC 네트워크 및 서브넷 생성하기 (gcloud CLI)

1. **VPC → my-internal-app-run → Subnets**에서 Custom·같은 region 의 subnet-a10.10.20.0/24/subnet-b10.10.30.0/24 를 확인합니다.
2. 다른 region 으로수정하지 않습니다. 리소스이름의 run 과 CIDR 을동시에대조합니다.

### 2. 방화벽 규칙 4종 생성하기 (gcloud CLI)

1. **VPC firewall**에서 run 규칙 4 개를각각엽니다: internalICMP10.10/16, IAP22, internalHTTP80/targetbackend, health80/source130.211.0.0/22·35.191.0.0/16.
2. 원문의전체 SSH/RDP/ICMP 공개대신 IAP/내부 CIDR 로제한했습니다. 소스/대상/프로토콜을 따로읽습니다.

## Task 2. Cloud Router를 사용하여 NAT 구성하기

### Cloud Router 인스턴스 생성하기

1. **Cloud NAT → p14-nat-run → p14-router-run**에서 network my-internal-app·해당 region·AUTO_ONLY·두 subnet egress 를 확인합니다.
2. NAT 는외부에서 VIP 로들어오는기능이아닙니다. 생성 완료만으로 guest 패키지설치성공은입증되지 않습니다.

## Task 3. 인스턴스 템플릿 구성 및 인스턴스 그룹 생성하기

### 1. Cloud Shell 열기 및 시작 스크립트 준비

1. **Instance template → metadata/startup-script**에서 Apache/PHP 설치·bounded apt 재시도·clientIP/hostname 응답구성을 읽습니다.
2. 원문 CloudShell 파일을수동 작성한 것과 Terraforminline 구현을구분합니다. startup 재실행하지 않습니다.

### 2. 인스턴스 템플릿 생성하기 (gcloud CLI)

1. **Compute → Instance templates → p14-template-a/b-run-…**를열어같은 region·e2-micro·각 subnet·backendtag·외부 IP 없음을 대조합니다.
2. a/b 가같은 subnet 을잘못참조하지않는지확인합니다. 랜덤접미사는정상입니다.

### 3. 관리형 인스턴스 그룹 생성하기 (gcloud CLI)

1. **Instance groups → instance-group-1/2-run**에서각각 1 대·서로 다른동일 region zone·대응 template 를 읽습니다.
2. 구성원 VM 의 startup 완료/HTTP 준비를 evidence 와대조합니다. MIG 존재는 guest 준비 완료가 아닙니다.

### 백엔드 확인 및 utility-vm 생성하기

1. **VM → utility-vm-run → NIC**에서 private10.10.20.50/외부 IP 없음을확인하고 MIG 두 VM 의 privateIP·hostname 을 읽습니다.
2. `phase-14-machine.json`의각 backend 직접 HTTP 성공을 대조합니다. 원문응답의 Client IP 는 utility 주소이며서버자신의 IP 와다릅니다.
3. `evidence/index-repair.json`에서대상2개·configtest/localhost HTTP 성공과`persistent_drop_in=p14-php-index.conf`를읽습니다. 초기스크립트의설정과별도로이drop-in이PHP우선순위를유지합니다. 확인을위한VM교체/재부팅/설정수정은하지않습니다.

## Task 4. Internal Network Load Balancer 구성하기

### 구성 시작하기

1. **Network services → Load balancing → my-ilb-run**에서내부 passthrough Network LB·해당 region/VPC 인지확인합니다.
2. 외부 Application LB 와구분하고새 LB 생성버튼을누르지 않습니다.

### 리전 백엔드 서비스 구성하기

1. **LB → Backends → my-ilb-backend-run**에서 TCP·INTERNAL·두 instancegroup의 CONNECTION 모드와 regionalTCP80 healthcheck 를 읽습니다. `evidence/backend-configuration.json`의동일값과대조합니다. 이LB에UTILIZATION 모드를설정하지않습니다.
2. **Backend health**에서두예상 group 각각 HEALTHY 인지 backend-health.json 과대조합니다. 단발기동직후에는수렴지연이있을수있습니다.

### 프런트엔드 구성하기

1. **LB → Frontend** 및 **VPC → IP addresses → my-ilb-ip-run**에서 10.10.30.5/subnet-b/TCP80/INTERNAL/같은 backendservice 를 확인합니다.
2. allow_global_access=false 이므로같은 region 클라이언트기준입니다. 외부브라우저로 privateVIP 접속실패는그 자체로 LB 장애아닙니다.

### Internal Network Load Balancer 검토 및 생성하기

1. **LB 상세**의 frontend→backend→두 MIG→healthcheck 참조를순서대로대조합니다.
2. VM3 개의 NIC 에외부 IP 가없고 VIP 가 INTERNAL 인지확인합니다. Apply/Create 를다시누르지 않습니다.

## Task 5. Internal Network Load Balancer 테스트하기

### Internal Network Load Balancer 접근하기

1. 저장검증에서 utility VM 이 VIP 로보낸 60 개요청의성공수 60·backend marker 수 2·예상 hostname 정확일치·Client IP10.10.20.50 을 대조합니다.
2. 각 VM 의직접 HTTP 와 VIP 경유 HTTP 를 구분합니다. 중간 curl 실패를마지막 echo 성공으로덮지않도록보완됐습니다. 확인 목적으로 60 회부하를재실행하지 않습니다.

## 출처·검증 범위

2026-08-26 원문 14·코드 대조(observed). 실제 UI 클릭은 별도이며 Cloud 기계 검증 결과·한계는 [실행 근거](../../memory/PRODUCT-TRUTH.md)를 따릅니다. [상태 확인](https://docs.cloud.google.com/load-balancing/docs/health-checks). 명시적 destroy 후에는현재config의secondaryzone만검색하지말고run전체inventory를확인합니다.
