# Phase 07–15 구현 누락 감사와 반영 결과

- 기준: 보존 원본의 모든 Task, Phase 문서의 검증 게이트, 비용·보안 가드레일
- 판정일: 2026-08-25
- 판정 범위: 로컬 구현·정적/offline 검증. 실제 Google Cloud apply와 Extension 승인은 별도다.

## 공통 보완

| 누락 | 반영 |
|---|---|
| Phase 디렉터리·verifier가 없어도 gate 통과 | `execute.sh`, 실행 가능한 `verify.sh`, Terraform, 원본 Task 계약이 모두 있어야 통과 |
| 문서 Task와 evidence의 대응을 사람이 확인 | `phase-contract.py`가 원본과 Phase 문서의 Task 개수·순서·제목을 대조 |
| Terraform 밖 변경이 plan 승인과 분리 | `action-plan.json`을 binary plan과 함께 `plan-bundle.json` hash로 결합 |
| 민감값이 `terraform show -json`에 남을 수 있음 | 민감 mask를 적용해 plan JSON을 정제하고 apply 뒤 binary plan을 삭제 |
| 임의 상태 전이 가능 | planned·applied·verified·destroyed artifact 상태가 맞아야 전이 허용 |
| plan 단계의 작업을 완료로 기록 | manifest는 실제 verifier evidence 전까지 `pending` 유지 |
| apply 후 작업·verify 실패 시 destroy 진입 불가 | `applied`, `verified`, `cleanup_required` 소유 manifest에서 destroy를 허용하고 post-apply 실패를 `cleanup_required`로 기록 |

## Phase별 반영

| Phase | 원본에서 반드시 남겨야 할 동작 | 구현 위치와 실제 판정 |
|---:|---|---|
| 07 IAM | 두 사용자 역할, Viewer 회수, Storage 범위, service account `actAs`, VM 권한 | 2026-08-26 개정: 실제 A/B와 workload SA 하나, **B가** VM 생성, Creator 쓰기 성공/읽기 거부, 4개 임시 역할 회수. [Notion 최신 대조표](phase-07-notion-coverage.md) 참조 |
| 08 Storage | private/public ACL, CSEK, key rotation, lifecycle, versioning, recursive sync | 조건부 공개 ACL 즉시 회수, runtime CSEK 2개, 구키 expected failure, 31일 lifecycle, generation hash 복구, 중첩 object set 검증 |
| 09 Cloud SQL | WordPress, Auth Proxy 기본 public 경로, private IP 직접 경로 | MySQL 8 public+private address, pinned WordPress/proxy/wp-cli, 두 VM의 같은 SQL marker read/write와 제한 CIDR HTTP probe |
| 10 BigQuery | 원본 AVRO fixture와 415,602행, SQL 8개 | generation·CRC32C 고정, exact row count, 8개 SQL dry-run과 1 GiB 상한, 결과 hash 요약 |
| 11 Monitoring | VM 3개, dashboard, 두 조건 AND alert, group, uptime, alert disable | 현재 run VM 3개의 CPU time series, group member 3개, exact uptime check time series, enabled true→false API 전이, Monitoring·Logging MCP preflight |
| 12 HA VPN | gateway 2, router 2, 양방향 tunnel 4, interface/peer 4, global route, failover | runtime PSK, BGP UP·learned route, 양방향·교차 region private ping, 원본 tunnel0 삭제 뒤 surviving path ping |
| 13 ALB | custom image, regional MIG 2, IPv4+IPv6, backend logging, load·autoscale | serial-ready builder→실제 TERMINATED 상태의 disk image, 두 regional MIG min 1/max 2, dual-stack forwarding, 현재 backend 실제 log·marker·scale-out/in |
| 14 ILB | subnet 2, template 2, zonal MIG 2, utility VM, direct backend와 VIP | 외부 IP 없는 두 backend, direct IP HTTP 2개, healthy backend 2개, 내부 VIP의 marker 2개 분산, INTERNAL scheme readback |
| 15 Terraform | auto-mode VPC, 재사용 module, VM 2개, state/API, ping | local module 2회 사용, state address 4개, Cloud inventory 대조, cross-region private ping, 두 번째 plan exit code 0 |

## 로컬 검증 결과

- Phase 07–15 `terraform fmt -check`: 통과
- Google provider 7.45.0 `terraform init -backend=false`와 `terraform validate`: 통과
- Phase 07–15 원본 Task 계약: 통과
- Phase 07–15 offline verifier: 통과
- 민감 plan JSON 정제 fixture: 통과
- provider lockfile: Phase 07–15 모두 존재

## 남은 실행 증거

이 문서의 `반영`은 코드가 존재하고 정적 계약을 통과했다는 뜻이다. 실제 완료는 각 Phase마다 승인된 saved plan apply, machine evidence, VS Code Extension의 read-only 검토, 사용자 승인, destroy와 잔여 리소스 0까지 끝나야 한다. Cloud 실행 없이 tunnel 수렴, autoscaling, uptime metric, SQL/BigQuery 데이터 경로가 성공했다고 주장하지 않는다.
