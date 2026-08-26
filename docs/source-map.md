# 실습 15개 자동화 매핑

원본은 `references/google-cloud-labs-ko/labs/`에 그대로 보존한다. 아래 표는 각 실습의 교육 목표를 CLI 하네스 계약으로 옮기는 설계이며, 원문을 축약하거나 대체하는 문서가 아니다.

| Lab | Phase | 자동화 경로 | 핵심 CLI 검증 | 명시적 경계 |
|---|---:|---|---|---|
| 01 Console and Cloud Shell | 01 | 로컬 Bash·`gcloud` 구성, 버킷과 파일 동작 | config, bucket describe, object hash, shell 지속성 | 콘솔 메뉴 탐색과 Cloud Shell UI 자체는 자동 완료로 주장하지 않음 |
| 02 Infrastructure Preview | 02 | 지원 상품의 Marketplace Terraform 모듈 또는 생성 snippet | VM describe, SSH `systemctl`, Jenkins HTTP 상태 | 상품이 CLI 배포 미지원이면 blocked; 대체 VM을 같은 결과로 표시하지 않음 |
| 03 VPC Networking | 03 | VPC·subnet·route·firewall·VM adapter | API describe, 내부/외부 ping, expected failure | 기본 네트워크 삭제는 전용 프로젝트에서만 허용 |
| 04 Private Google Access and NAT | 04 | Private Google Access, Router, NAT, 외부 IP 없는 VM | Google API 접근, 외부 egress, NAT 로그/상태 | NAT 비용과 전파 대기 timeout 적용 |
| 05 Creating Virtual Machines | 05 | Linux·Windows·custom machine VM | describe, serial output, SSH/guest 상태 | RDP GUI는 제외; Windows 비밀번호는 출력·Git 저장 금지 |
| 06 Working with VMs | 06 | disk attach/format/mount, 앱 설치, firewall | mount·fstab, systemd/process, TCP 연결 | 공개 포트 source range 최소화, 종료 후 disk까지 정리 |
| 07 Exploring IAM | 07 | 실제 사용자 A/B OAuth, workload SA 하나, project 역할 전이 | B의 VM 생성·최종 RUNNING, guest Viewer read/write 및 Creator write/read 거부, exact rollback | Notion 최신 본문 기준; 콘솔/인증된 브라우저 다운로드는 API 등가, 최종 삭제 별도 |
| 08 Cloud Storage | 08 | object, ACL/IAM, CSEK, lifecycle, versioning, sync | metadata JSON, hash, generation, 복호화 성공/실패 | CSEK는 임시 파일/프로세스에만 존재 |
| 09 Cloud SQL | 09 | SQL instance, private IP, proxy, WordPress VM | SQL query, proxy health, HTTP, private 경로 | DB 비밀번호는 ignored runtime secret로 생성·전달·삭제; 비용 높은 인스턴스 제한 |
| 10 Billing data with BigQuery | 10 | `bq load`와 versioned SQL fixture/query | row count, schema, query golden result | 실제 Billing export 선택 시 권한과 비동기 데이터 지연을 별도 처리 |
| 11 Resource Monitoring | 11 | VM 3개, dashboard, alert policy, group, uptime check API | CPU·uptime time series, group membership, alert 상태 전이 | 외부 알림 발송은 별도 opt-in; MCP는 Extension read-only 교차 검증 |
| 12 HA VPN | 12 | 양쪽 VPC, HA VPN, routers, tunnels, BGP | tunnel 상태, BGP peer, learned route, private ping | PSK 비밀 처리, VPN 비용, 라우팅 수렴 timeout |
| 13 Application Load Balancer | 13 | custom image, regional MIG 2개, dual-stack ALB, autoscaler | image provenance, backend marker, bounded load, scale-out/in | global IPv4·IPv6/forwarding rule 잔여 여부 확인 |
| 14 Internal Network Load Balancer | 14 | VPC, NAT, template·MIG 각 2개, regional internal forwarding | utility VM의 direct backend와 VIP curl, marker 분산 | 검증 클라이언트도 같은 run 소유 리소스로 정리 |
| 15 Terraform Deployment | 15 | 모듈 조합과 전체 orchestration | fmt, validate, saved plan, outputs, idempotent plan, destroy | state와 plan 원문은 Git 제외; remote state 접근 분리 |

## 전체 커버리지 규칙

각 Lab 구현 시 원본의 모든 `Task` 제목을 scenario manifest의 `source_tasks`에 나열하고, `automated`, `cli-equivalent`, `manual-boundary`, `blocked`, `conditional`, `automated-required` 중 하나로 분류한다. 분류가 없거나 원본과 개수·순서·제목이 다른 Task가 하나라도 있으면 Phase gate는 실패한다.
