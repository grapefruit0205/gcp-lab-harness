# GCP Terraform Foundation

## Terraform은 ADC로 Google Cloud를 관리할 수 있음 — confirmed (self-gated) 2026-08-25

- Claim: 로컬 개발 환경에서 Terraform의 공식 `hashicorp/google` provider는 Google Cloud CLI가 만든 Application Default Credentials를 사용해 GCP 리소스를 조회·관리할 수 있다.
- Refutation: provider만 설치하면 자동으로 인증된다고 가정하지 않고, Google Cloud의 Terraform 인증 문서와 provider registry를 대조했다. 초기 account-check에서 존재하지 않는 `lifecycle_state` 속성 가정이 실제 provider validation에 의해 반박되어 제거됐다.
- Primary sources: Google Cloud `Authentication for Terraform` (`https://docs.cloud.google.com/docs/terraform/authentication`), HashiCorp Terraform Registry의 공식 Google provider (`https://registry.terraform.io/providers/hashicorp/google/latest`).
- Sample: 독립된 공식 문서 2개. 로컬 구현 확인은 아래 n=1 관찰로 분리한다.
- Limits: 실제 리소스 생성 가능 범위는 로그인 principal의 IAM 권한, 활성 API, 조직 정책, 쿼터와 서비스별 provider 지원에 따라 달라진다.
- Sub-foundations exposed: 인증 — atomic; provider schema — atomic; IAM·API·quota — not atomic → Phase별 preflight로 분리.

## 현재 계정의 Terraform project read 연결 — observed 2026-08-25

- Claim: 이 워크스테이션에서 gcloud 581.0.0과 Terraform 1.15.8을 설치하고, 사용자 로그인+ADC로 `hashicorp/google` 7.45.0의 `google_project` data source를 읽었다.
- Sources: `config/toolchain.lock.env`, `foundation/terraform/account-check/.terraform.lock.hcl`, `scripts/verify-terraform-gcp.sh` 실행 결과.
- Sample: n=1, 프로젝트 `kdt5-05`, refresh-only plan 1회 성공.
- Limits: Cloud resource create/update/delete는 아직 실행하지 않았다. 다른 프로젝트와 IAM 역할에서는 결과가 다를 수 있다.
- Sub-foundations exposed: 실제 apply 권한 — atomic but untested; resource cleanup — atomic but untested.
