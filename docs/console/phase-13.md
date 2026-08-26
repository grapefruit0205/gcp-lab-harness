# Phase 13 — Task 하위 항목별 콘솔 확인

[공통 준비](../console-checks.md) · [Phase 요약](../phases/phase-13-external-alb.md)

본인 프로젝트·RUN_ID 와실행 시간을 선택합니다. 확인 안내이지 실제 성공 기록이 아닙니다. 생성/수정/삭제/부하를 실행하지 않습니다. 로컬 `artifacts/runs/<RUN_ID>/phase-13/evidence/`의 image-provenance/backend-health/phase-13-machine 을 사용합니다.

## Task 1. 상태 확인 방화벽 규칙 구성하기

### 상태 확인 규칙 생성하기

1. **VPC firewall → p13-health-<RUN_ID>**에서 INGRESS/TCP80, source130.211.0.0/22·35.191.0.0/16, target p13-web-run 을 확인합니다.
2. SSH IAP 규칙과 구분합니다. 확인 목적으로 source0/0 를추가하지 않습니다.

## Task 2. Cloud Router를 사용하여 NAT 구성하기

### Cloud Router 인스턴스 생성하기

1. **Cloud NAT → p13-nat → p13-router**에서 network p13, primaryregion, AUTO_ONLY, 해당 region 의모든 subnet egress 를 확인합니다.
2. secondaryregion 전체 NAT 도있다고가정하지 않습니다. 현재 customimage 는 secondary 에서패키지재설치없이부팅합니다.

## Task 3. 웹 서버용 커스텀 이미지 생성하기

### VM 생성하기

1. **VM instances → p13-builder-run → Details/NIC/bootdisk**에서 e2-micro·Debian12 기반·privateIP·현재 TERMINATED 를 확인합니다.
2. 이미지 제작 후 중지 보존이 정상입니다. 원문처럼 VM 을다시만들지 않습니다.

### VM 커스터마이징하기

1. **VM → Serial console output**의 HARNESS_IMAGE_READY 시각과 image-provenance.json 의 Apache packageversion·baseimage hash 를 대조합니다.
2. marker 만으로원문의수동편집이력까지입증하지않으며로그 전체를공유하지 않습니다.

### Apache 서비스가 부팅 시 자동으로 시작되도록 설정하기

1. customimage 로만든 MIG VM 의 startup 상태와 저장 HTTP 응답을대조하여 Apache 활성과본문을 확인합니다.
2. 원문의 reset 후재확인은현재 자동화 미수행입니다. 확인하려고 reset/재부팅하지않습니다.

### 커스텀 이미지 생성을 위해 디스크 준비하기

1. **builder → bootdisk 링크**와 provenance 의 builder_stopped_before_image 를읽어중지후같은 disk 에서이미지를만들었는지봅니다.
2. 보존 복구를 위해 builder 를삭제하지 않습니다. 원문의삭제·disk 보존과차이가있으며 disk 과금은지속됩니다.

### 커스텀 이미지 생성하기

1. **Compute Engine → Images → p13-webserver-run → Details**에서 READY·sourceDisk·provenance 를 확인합니다.
2. image 존재만으로 template 사용까지입증되지않으므로다음 Task 의참조를 대조합니다.

## Task 4. 인스턴스 템플릿 구성 및 인스턴스 그룹 생성하기

### 인스턴스 템플릿 구성하기

1. **Instance templates → p13-web-run-… → Details**에서 sourceimage p13-webserver·e2-micro·HTTPtag·privateNIC·startup 을 읽습니다.
2. 이름의랜덤접미사는정상입니다. run 문자열로 찾고 새 template 을만들지 않습니다.

### 관리형 인스턴스 그룹용 상태 확인 생성하기

1. 상단검색 **Health checks → p13-mig-health-run**에서 HTTP80·10 초간격·5 초 timeout·healthy2/unhealthy3 를 봅니다.
2. LB 용 p13-lb-health 와 구분합니다. health 설정 존재는 실제 HEALTHY 상태와 별개입니다.

### 관리형 인스턴스 그룹 생성하기

1. **Instance groups → us-1-mig/notus-1-mig → Autoscaling**에서서로 다른 region·min1/max2·LButilization80%·template·autohealing 을 확인합니다.
2. 원문규모를비용상한 1–2 로축소했습니다. targetSize 는 autoscaler 가관리하므로수동 resize 하지않습니다.

### 백엔드 확인하기

1. **Load balancing → p13-http-backend → Backend health**에서예상 MIG 두 개 각각 최소 1 개 HEALTHY 인지 backend-health.json 과대조합니다.
2. 총 HEALTHY2 여도한 리전에만 2 개이면통과아닙니다.

## Task 5. Application Load Balancer(HTTP) 구성하기

### 구성 시작하기

1. **Network services → Load balancing**에서 p13 run 의 LB 를열어 External Application LB/EXTERNAL_MANAGED·HTTPproxy/urlmap 연결을 읽습니다.
2. Create load balancer 를누르지 않습니다.

### 프런트엔드 구성하기

1. **LB → Frontends**에서 p13-http-ipv4/ipv6 의주소·TCP80·같은 proxy target 을 확인합니다.
2. 로컬 IPv6route 가없으면실제 IPv6HTTP 는 unavailable 이며 API 구성검증만수행합니다. route 가있는데 HTTP 실패하면오류입니다.

### 백엔드 구성하기

1. **LB → Backends → p13-http-backend**에서두 MIG·양쪽 RATE/max_rate_per_instance50·http namedport·logging enable/sample1.0 을 읽습니다.
2. 원문의두 번째 UTILIZATION 방식과달리양쪽 RATE 를 사용합니다. 학습목표의차이를 기록합니다.

### HTTP 로드밸런서 검토 및 생성하기

1. **LB → routing/defaultservice**, 이어 **Logging → Logs Explorer**에서현재 backend 명·실행 시간의 http_load_balancer 로그를 읽습니다.
2. 로그생성을위한추가부하를발생시키지않습니다. rawrequest 를공유하지 않습니다.

## Task 6. Application Load Balancer(HTTP) 부하 테스트하기

### Application Load Balancer(HTTP)에 접근하기

1. LB 의현재 IPv4 `http://주소/` 또는저장응답에서 backend=hostname·HTTP 성공을확인하고 IPv6 가능환경의결과도봅니다.
2. marker2 개는두 리전트래픽분산자체를보장하지않습니다. 지역별 health 와응답관측은구분합니다.

### Application Load Balancer(HTTP) 부하 테스트하기

1. 각 **MIG → Monitoring/Autoscaling**에서검증 시각범위를선택해합계 baseline2→peak3/4→2 복귀와 evidence 를 대조합니다.
2. loadunit360 초상한·종료기록을 확인합니다. ab 를재실행하지않으며현재 2 대만으로과거 scale-out 을입증하지 않습니다.

## Task 7. Review

### 이미지→template→MIG→LB와 비용

1. Task1–6 의참조관계와 provenance/health/scale evidence 를비교합니다.
2. 두 regionhealth·dualstack 구성·logging·scale-out/in·수동경계를 따로기록합니다. 중지 builder·image·disk·LB 과금은남으며 destroy 는별도 저장 계획 승인이 필요합니다.

## 출처·검증 범위

2026-08-26 원문 13·코드 대조(observed), 실제 UI/Cloud 미검증. [상태 확인](https://docs.cloud.google.com/load-balancing/docs/health-checks), [Autoscaler 그래프 해석](https://docs.cloud.google.com/compute/docs/autoscaler/understanding-autoscaler-decisions).
