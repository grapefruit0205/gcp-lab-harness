# 실행 Phase 01–15

원본 Lab 하나가 실행 Phase 하나다. Foundation은 별도 문서이며 `run-all`은 아래 15개 Phase만 순차 진행한다.

| Phase | 원본 Lab | 비용 위험 | 핵심 승인 증거 |
|---:|---|---|---|
| [01](phase-01-console-cloud-shell.md) | Console and Cloud Shell | 낮음 | bucket·object·shell fixture |
| [02](phase-02-infrastructure-preview.md) | Infrastructure Preview | 중간 | Marketplace provenance·Jenkins 상태 |
| [03](phase-03-vpc-networking.md) | VPC Networking | 중간 | topology·연결 matrix |
| [04](phase-04-private-access-nat.md) | Private Google Access and NAT | 중간 | API/NAT egress·NAT log |
| [05](phase-05-creating-vms.md) | Creating Virtual Machines | 중간 | Linux·Windows·custom VM readiness |
| [06](phase-06-working-vms.md) | Working with Virtual Machines | 중간 | disk·app·backup·maintenance |
| [07](phase-07-iam.md) | Exploring IAM | 중간 | allow/deny·role rollback |
| [08](phase-08-cloud-storage.md) | Cloud Storage | 중간 | ACL·CSEK·lifecycle·version·sync |
| [09](phase-09-cloud-sql.md) | Implementing Cloud SQL | 높음 | SQL·proxy·WordPress·private path |
| [10](phase-10-bigquery-billing.md) | Billing data with BigQuery | 중간 | load·schema·golden query |
| [11](phase-11-monitoring.md) | Resource Monitoring | 낮음–중간 | MCP/API dashboard·alert·uptime |
| [12](phase-12-ha-vpn.md) | HA VPN | 높음 | tunnels·BGP·routes·private ping |
| [13](phase-13-external-alb.md) | Application Load Balancer | 높음 | backend health·routing·autoscale |
| [14](phase-14-internal-nlb.md) | Internal Network Load Balancer | 높음 | internal client·backend distribution |
| [15](phase-15-terraform.md) | Terraform Deployment | 중간 | saved plan·apply·idempotency·destroy |

각 Phase는 `git pull --ff-only` → `cmd` 실행 → machine verification → VS Code Codex Extension 검증 → 사용자 승인 → cleanup → 한국어 commit → push 순으로 닫힌다. `PUSHED`가 아니거나 다음 pull이 실패하면 다음 Phase는 시작하지 않는다.
