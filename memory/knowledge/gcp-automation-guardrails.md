# Google Cloud 자동화 가드레일

Checked: 2026-08-25

## Confirmed

- 로컬 개발은 사용자 자격 증명 또는 서비스 계정 가장을 사용할 수 있고, 장기 서비스 계정 키보다 단기 가장이 위험을 줄인다.
- Terraform 변경은 plan을 먼저 만들고 저장한 뒤 apply해야 하며, state에는 민감한 값이 포함될 수 있어 Git에 저장하면 안 된다.
- 실제 인프라 테스트는 비용과 시간이 들므로 정적 검사를 먼저 실행하고 격리 환경과 확실한 cleanup을 사용한다.
- Cloud Marketplace VM은 일부 상품만 Terraform 기반 CLI 배포를 지원하므로 상품별 지원 확인이 필요하다.
- Cloud Billing export는 필요한 Billing/BigQuery 권한과 지원 dataset 위치가 필요하며 데이터 도착이 지연될 수 있다.
- Cloud Billing budget은 지출을 자동으로 막지 않으며 Pub/Sub 기반 프로그램 알림도 지연·중복·순서 변경 가능성이 있다.

## Evidence

- https://docs.cloud.google.com/docs/authentication
- https://docs.cloud.google.com/iam/docs/service-account-impersonation
- https://docs.cloud.google.com/docs/terraform/best-practices/operations
- https://docs.cloud.google.com/docs/terraform/best-practices/security
- https://docs.cloud.google.com/docs/terraform/best-practices/testing
- https://docs.cloud.google.com/marketplace/docs/deploy-through-CLI
- https://docs.cloud.google.com/billing/docs/how-to/export-data-bigquery
- https://docs.cloud.google.com/billing/docs/how-to/budgets
- https://docs.cloud.google.com/billing/docs/how-to/budgets-programmatic-notifications

## Limits

조직 정책, 상품 entitlement, 쿼터, 지역 지원 여부는 대상 계정에서 Phase별 preflight로 다시 확인해야 한다. 현재 계정 통합 검증은 실행하지 않았다.
