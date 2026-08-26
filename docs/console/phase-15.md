# Phase 15 — Task 하위 항목별 콘솔 확인

[공통 준비](../console-checks.md) · [Phase 요약](../phases/phase-15-terraform.md)

본인 프로젝트·RUN_ID 를 선택합니다. 확인 방법이지 실제 성공 기록이 아닙니다. 증거는 `artifacts/runs/<RUN_ID>/phase-15/evidence/phase-15-machine.json`입니다. Terraform state·plan 원문은비밀을포함할수있어공유하지 않습니다. 확인용 apply/destroy 는실행하지않습니다.

## Task 1. Terraform 및 Cloud Shell 설정하기

### Terraform 설치 확인하기

1. 로컬/본인 CloudShell 의 `terraform version`을읽고저장소의 Terraform1.15.x/provider7.45.x lock 과대조합니다.
2. Cloud 콘솔에는로컬 Terraform 설치화면이없습니다. CloudShell 에서설치명령을다시실행하지않습니다.

### Terraform 초기화하기

1. 로컬테스트로그의 init·fmt·validate 성공과 `.terraform.lock.hcl` 존재를 확인합니다.
2. provider 설치/모듈초기화는로컬증거이며 VM 목록만으로입증되지 않습니다. 이작업은 Cloud 리소스생성과별개입니다.

## Task 2. mynetwork와 그 리소스 생성하기

### mynetwork 구성하기

1. **VPC networks → mynetwork-run → Subnets**에서 Automatic 모드·리전별자동 subnet 을 읽습니다.
2. 원문 HCL 의 auto_create_subnetworks=true 와대조하고 Custom 으로편집하지않습니다.

### 방화벽 규칙 구성하기

1. **VPC firewall → mynetwork-allow-http-ssh-rdp-icmp-run**에서 network mynetwork·TCP22/80/3389·ICMP·RFC1918/IAP 소스를 읽습니다.
2. 원문 0/0 대신내부/IAP 제한입니다. 포트가설정됐다고서버프로세스가그포트에서실행중인것은아닙니다.

### VM 인스턴스 구성하기

1. **VM → mynet-vm-1/2-run → Details/NIC**에서 e2-micro·Debian12·서로 다른 region zone·같은 mynetwork·외부 IP 없음을 확인합니다.
2. 로컬 HCL 의두 `module`이같은 `./modules/instance`를참조하는지도읽습니다. 콘솔에는 Terraformmodule 이별도리소스로표시되지 않습니다.

### mynetwork와 그 리소스 생성하기

1. 위 network/firewall/VM2 의존재를저장 apply 로그와대조합니다.
2. 관리주소 4 개(network/firewall/module VM2)와 data.google_compute_image 는구분합니다. state list 에 data 까지 5 행인것은추가 Cloud 리소스가아닙니다.

## Task 3. 배포 확인하기

### Cloud console에서 네트워크 확인하기

1. **VPC → mynetwork-run**, **Firewall**에서두 VM 의 NIC 와 network·규칙참조를 대조합니다.
2. 자동 subnet 은 network 종속동작이며별도관리주소수가늘었다고단정하지않습니다. 다른 run 을섞지않습니다.

### Cloud console에서 VM 인스턴스 확인하기

1. **VM instances**에서두 VM RUNNING·각 zone·privateIP 를 확인합니다.
2. 정제 evidence 의 VM1→VM2 privateping 성공을 대조합니다. 콘솔목록만으로 ping 을입증하지않으며같은 region 두 zone 을 cross-region 이라고쓰지않습니다.

## Task 4. Review

### 구성·실제통신·멱등성·종료

1. Task1–3 의 Terraform 구조·실제 4 개관리리소스·privateping 을대조하고 evidence 의 idempotency_changes=0 을 읽습니다.
2. 두 번째 plan detailed-exitcode0 은로컬증거이며콘솔화면만으로입증할 수 없습니다. destroy 완료는별도 승인 후 network/VM/disk/firewall 부재와 inventory 성공으로확인합니다.

## 출처·검증 범위

2026-08-26 원문 15·코드 대조(observed), 실제 UI/Cloud 미검증. [VM 상세 확인](https://docs.cloud.google.com/compute/docs/instances/view-vm-details), [Terraform data source](https://developer.hashicorp.com/terraform/language/data-sources).
