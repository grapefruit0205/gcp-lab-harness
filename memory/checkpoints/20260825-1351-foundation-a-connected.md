# Checkpoint — Foundation A 계정·Terraform 연결 완료 — 2026-08-25 13:42

## The story so far

15개 Lab 설계와 Foundation B controller가 있는 private 저장소에 Foundation A를 추가했다. 공식 archive SHA를 검증해 사용자 영역에 gcloud 581.0.0과 Terraform 1.15.8을 설치했고, 사용자 Google 로그인과 ADC를 만들었다. 접근 가능한 ACTIVE 프로젝트 하나를 전용 configuration과 exact allowlist로 구성해 billing 연결 preflight를 통과했으며, `hashicorp/google` 7.45.0이 ADC로 해당 프로젝트를 읽는 refresh-only plan을 성공했다. 실제 Cloud resource create/update/delete는 아직 하지 않았다.

## Decided

- D-012: 별도 예산 한도 없이 GCP 계정 연동과 실제 Cloud apply를 진행하되 allowlist·plan 승인·수량·timeout·cleanup 보호를 유지한다.

## Waiting on the user

- A-003: 유일하게 조회된 ACTIVE 프로젝트 `kdt5-05`를 실제 실습 apply 대상으로 사용해도 되는지 첫 apply 전에 확인해야 한다.
- Q-003: 저장소 라이선스가 필요하다.
- Q-005: Command Code 고정 모델 실행 규칙을 영구 ballast pin으로 남길지 확인이 필요하다.
- A-002: 공식 Monitoring·Logging remote MCP를 read-only verifier로 가정한다.

## Next first action

`kdt5-05`가 실습 대상이라는 사용자 확인을 받은 뒤, 서비스 계정 1개 canary의 저장된 Terraform plan·예상 영향·cleanup 경로를 만들고 apply 직전 다시 승인받는다.

## Tried

- 첫 account-check에 `google_project.lifecycle_state`를 가정했지만 provider 7.45.0에 없는 속성이어서 validate가 실패했다. ACTIVE 검사는 gcloud preflight에만 두고 Terraform data 조회로 좁혀 성공했다.
- Terraform refresh-only plan은 성공했지만 Cloud resource apply 권한과 cleanup은 아직 검증하지 않았다.
