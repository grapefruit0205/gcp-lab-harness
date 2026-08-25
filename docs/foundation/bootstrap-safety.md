# Foundation A — Ubuntu·계정·인증·비용 안전장치

이 문서는 실행 Phase 01–15에 앞서 한 번 구현하는 공통 기반이다. 실행 Phase 수에는 포함하지 않는다.

## 목표

- Command Code `cmd`, VS Code/Extension, gcloud, Terraform, Git 원격 인증 상태 확인 (`gh`는 선택 도구)
- 실습 전용 GCP project allowlist와 billing·quota preflight
- 사용자 ADC에서 최소 권한 service account를 가장하는 runner identity
- 별도 read-only MCP verifier identity와 Monitoring/Logging remote MCP 연결
- 장기 key, state, raw log, 실제 account 식별자의 Git 유입 차단

## 필수 gate

- `cmd status`가 성공하고 `cmd` 버전이 toolchain lock 범위에 포함
- `cmd` 호출에 `--model`과 `--effort`가 없음
- project가 allowlist와 exact match, production 표식 없음, billing 연결 확인
- `gcloud`, Terraform provider, Monitoring/Logging MCP canary read 성공
- D-012에 따라 budget은 필수 조건으로 사용하지 않고 별도 resource 상한·timeout·cleanup 적용
- negative fixture에서 잘못된 project·billing·region·승인이 모두 거부

## 결과

Foundation이 통과하기 전 `run-all`은 Phase 01 apply를 거부한다. 실제 값은 Git에서 제외된 0600 `config/harness.env`에만 둔다.

## 설치·인증 순서

```bash
make install-toolchain
make gcp-auth
./scripts/configure-gcp-project.sh <PROJECT_ID>
make gcp-preflight
make terraform-gcp-check
```

`gcp-auth`는 `gcloud auth login --update-adc`를 사용해 gcloud 사용자 인증과 Terraform용 ADC를 한 번에 만든다. 장기 서비스 계정 key는 만들지 않는다. `terraform-gcp-check`는 공식 `hashicorp/google` provider로 허용 프로젝트를 읽는 refresh-only plan이며 Cloud resource를 생성하지 않는다.
