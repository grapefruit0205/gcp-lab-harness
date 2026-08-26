# Phase 15 — Terraform 인프라 배포 자동화

- 원본: `references/google-cloud-labs-ko/labs/15.Automating the Deployment of Infrastructure Using Terraform_KR.md`
- 비용 위험: 중간
- 주요 서비스: Terraform, VPC, firewall, Compute Engine

## 목적

Terraform을 초기화하고 `mynetwork` VPC, firewall, VM을 선언형으로 배포해 plan/apply 결과, 실제 Cloud 상태, 멱등성, destroy를 검증한다.

## 범위와 원본 매핑

| 원본 Task | 분류 | 자동화·증거 |
|---|---|---|
| Task 1. Terraform 및 Cloud Shell 설정하기 | cli-equivalent | 로컬 Ubuntu의 Terraform version/provider init·lockfile 검증 |
| Task 2. mynetwork와 그 리소스 생성하기 | automated | VPC·firewall·두 VM module/config, saved plan apply |
| Task 3. 배포 확인하기 | cli-equivalent | Terraform output/state address와 gcloud network/VM read-only 대조 |
| Task 4. Review | cli-equivalent | fmt·validate·plan·apply·idempotency·destroy evidence 검토 |

## Task별 콘솔 확인

[공통 확인법](../console-checks.md)을 먼저 읽고 자신의 프로젝트·해당 run만 선택한다. 아래는 **확인 기준**이지 이번 실행의 성공 기록이 아니다. 원본 Task 이름은 위 매핑과 대응한다.

| Task | 콘솔 경로·대상 | 통과 기준 | 한계·보조 확인 |
|---|---|---|---|
| 1 | 콘솔 상단 Cloud Shell; 로컬 Terraform version/init 검사 기록 | 자신의 프로젝트와 Terraform/provider 초기화 증거 일치 | 자동화는 로컬 Ubuntu 동등 경로. 콘솔에 Terraform 로컬 state가 자동 표시되지 않음 |
| 2 | VPC 네트워크 → run mynetwork 계열 VPC·방화벽; Compute Engine → VM2 | VPC/방화벽/VM 사양과 참조가 승인 plan과 일치 | 이름만 비교하지 않고 프로젝트·zone·NIC도 확인 |
| 3 | 각 Cloud 리소스 상세와 로컬 Terraform output/state address 대조 | 계획 주소와 실제 리소스가 일대일 대응 | state 원문/비밀을 콘솔 메모나 Git에 붙여넣지 않음 |
| 4 | Cloud 리소스 + fmt/validate/plan/apply/재plan/destroy evidence | 멱등성 no-op과 실제 배포·명시적 삭제 후 잔여0을 구분 | 콘솔에는 멱등성 PASS 버튼이 없음. 저장된 검사 결과가 필요 |

메뉴 확인 근거(2026-08-26): [VM 상세 확인](https://docs.cloud.google.com/compute/docs/instances/view-vm-details), [VPC 네트워크](https://docs.cloud.google.com/vpc/docs/vpc). 화면 언어/버전에 따라 상단 검색으로 같은 서비스에 접근한다. 실제 UI 클릭 전 과정 검증은 별도다.

## 구현 작업

1. Terraform/version/provider checksum, ADC, project allowlist, quota를 preflight한다.
2. provider lockfile과 module source를 고정하고 backend·state 위치를 Git 밖에 둔다.
3. `terraform fmt -check`, `init`, `validate`, saved plan 생성과 hash 승인을 순서대로 수행한다.
4. 정확한 saved plan만 apply하고 output을 gcloud/API 실제 상태와 비교한다.
5. apply 후 새 plan이 변경 0인지 확인하고 승인 후 destroy plan을 별도로 검토·실행한다.

## 실행 계약

Command Code `cmd`는 현재 고정 모델을 상속하고 모델·effort 인수를 받지 않는다. `terraform apply`에 directory를 재계산하게 하지 않고 승인된 binary plan 경로만 넘긴다. state lock과 run ID가 불일치하면 중단한다.

## 검증 게이트

- fmt·validate·provider lock 검사가 통과한다.
- apply된 resource address와 Cloud API inventory가 일치한다.
- 두 번째 plan이 `0 to add, 0 to change, 0 to destroy`다.
- Extension은 Terraform configuration·plan summary·gcloud 상태·secret/state 유입을 검토한다.
- 사용자가 명시 승인해야 별도 destroy plan과 cleanup을 실행한다.

## 안전·비용 가드레일

- Terraform state, binary plan, crash log, credentials를 Git에 넣지 않는다.
- provider/module version과 source를 고정하며 임의 원격 module을 사용하지 않는다.
- destroy target은 현재 run state와 manifest의 교집합이어야 한다.
- shared remote state나 기존 workspace를 선택하면 즉시 중단한다.

## 완료 조건

- Task 1–4 coverage와 fmt·validate·saved plan·apply·API 대조·idempotency 증거가 있다.
- Extension 검토·사용자 승인이 완료됐다.
- destroy 후 Terraform state와 Cloud inventory 모두 run 소유 리소스 0을 보고한다.

## Command Code·Extension handoff 지시

Command Code는 Terraform 명령과 결과 요약을 남기되 state 원문을 반환하지 않는다. Extension은 binary plan을 apply하지 않고 configuration, 정제 plan JSON, Cloud read-only 상태를 검토하며 사용자만 승인 결정을 내린다.

## 현재 adapter

`phases/15/terraform`은 auto-mode `mynetwork`, 단일 lab firewall, local reusable instance module을 사용한 서로 다른 region의 VM 2개로 구성된다. verifier는 provider lock·fmt·validate, state address 정확히 4개, Cloud API inventory, VM 간 private ping, apply 뒤 두 번째 plan의 detailed exit code 0을 확인한다.

## Git 종료 조건

`Phase 15: Terraform 인프라 배포 자동화 및 검증 완료` 커밋을 push하고 remote SHA를 확인한다. 전체 release tag는 별도 사용자 승인 없이는 만들지 않는다.
