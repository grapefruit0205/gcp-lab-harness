# Google Cloud 한국어 실습 가이드 (01–15)

> Google Cloud Console, 네트워크, VM, IAM, Storage, SQL, Monitoring, VPN, Load Balancing, Terraform을 순서대로 실습하는 공유용 Markdown 패키지입니다.

## 사용 방법

1. ZIP 파일을 원하는 위치에 압축 해제합니다.
2. `README.md` 또는 `labs/01.Working with the Google Cloud Console and Cloud Shell_KR.md`를 엽니다.
3. VS Code, Obsidian, Typora, GitHub 등 일반 Markdown 뷰어에서 사용할 수 있습니다.
4. 이미지가 보이도록 `labs/`와 `images/` 폴더의 상대 위치를 유지하세요.

> **⚠️ 주의:** Google Cloud Console 화면과 메뉴는 변경될 수 있습니다. 개인 프로젝트에서 실습할 때는 비용이 발생할 수 있으므로 리소스 정리 단계를 확인하세요.

## 실습 로드맵

| 번호 | 실습 주제 | 핵심 서비스 | 문서 |
|---:|---|---|---|
| 01 | Console·Cloud Shell | Cloud Console, Cloud Shell, Cloud Storage | [열기](labs/01.Working%20with%20the%20Google%20Cloud%20Console%20and%20Cloud%20Shell_KR.md) |
| 02 | Infrastructure Preview | Marketplace, Jenkins, Compute Engine | [열기](labs/02.Infrastructure%20Preview_KR.md) |
| 03 | VPC Networking | VPC, Subnet, Firewall, Compute Engine | [열기](labs/03.VPC%20Networking_KR.md) |
| 04 | Private Access·NAT | Private Google Access, Cloud NAT, IAP | [열기](labs/04.Implement%20Private%20Google%20Access%20and%20Cloud%20NAT_KR.md) |
| 05 | Virtual Machine 생성 | Compute Engine | [열기](labs/05.Creating%20Virtual%20Machines_KR.md) |
| 06 | Virtual Machine 운영 | Compute Engine, Persistent Disk, Cloud Storage | [열기](labs/06.Working%20with%20Virtual%20Machines_KR.md) |
| 07 | IAM | IAM, Service Account | [열기](labs/07.Exploring%20IAM_KR.md) |
| 08 | Cloud Storage | ACL, 암호화 키, 버전 관리, 동기화 | [열기](labs/08.Cloud%20Storage_KR.md) |
| 09 | Cloud SQL | Cloud SQL, Auth Proxy, Private IP | [열기](labs/09.Implementing%20Cloud%20SQL_KR.md) |
| 10 | BigQuery Billing | BigQuery, Cloud Billing 데이터 | [열기](labs/10.Examining%20Billing%20data%20with%20BigQuery_KR.md) |
| 11 | Resource Monitoring | Cloud Monitoring, Alert, Uptime Check | [열기](labs/11.Resource%20Monitoring_KR.md) |
| 12 | HA VPN | HA VPN, Cloud Router, BGP, VPC | [열기](labs/12.Configuring%20Google%20Cloud%20HA%20VPN_KR.md) |
| 13 | Application Load Balancer | HTTP Load Balancing, MIG, Autoscaling | [열기](labs/13.Configure%20an%20Application%20Load%20Balancer%20(HTTP)%20with%20Autoscaling_KR.md) |
| 14 | Internal Network Load Balancer | Internal NLB, MIG, Health Check | [열기](labs/14.Configure%20an%20Internal%20Network%20Load%20Balancer_KR.md) |
| 15 | Terraform 자동화 | Terraform, VPC, Compute Engine | [열기](labs/15.Automating%20the%20Deployment%20of%20Infrastructure%20Using%20Terraform_KR.md) |

## 폴더 구조

```text
google-cloud-labs-ko/
├── README.md
├── labs/       # 실습 Markdown 15개
└── images/     # 문서에서 참조하는 이미지
```
