# Foundation A — Ubuntu·계정·인증·비용 안전장치

이 문서는 실행 Phase 01–15에 앞서 한 번 구현하는 공통 기반이다. 실행 Phase 수에는 포함하지 않는다.

## 목표

- Command Code `cmd`, VS Code/Extension, gcloud, Terraform, Git, GitHub CLI의 설치·인증 상태 확인
- 실습 전용 GCP project allowlist와 billing·budget·quota preflight
- 사용자 ADC에서 최소 권한 service account를 가장하는 runner identity
- 별도 read-only MCP verifier identity와 Monitoring/Logging remote MCP 연결
- 장기 key, state, raw log, 실제 account 식별자의 Git 유입 차단

## 필수 gate

- `cmd status`가 성공하고 `cmd` 버전이 toolchain lock 범위에 포함
- `cmd` 호출에 `--model`과 `--effort`가 없음
- project가 allowlist와 exact match, production 표식 없음, billing 연결 확인
- `gcloud`, Terraform provider, Monitoring/Logging MCP canary read 성공
- budget은 alert일 뿐 cap이 아님을 출력하고 별도 resource 상한 적용
- negative fixture에서 잘못된 project·billing·region·승인이 모두 거부

## 결과

Foundation이 통과하기 전 `run-all`은 Phase 01 apply를 거부한다. 실제 값은 Git에서 제외된 `config/harness.env`에만 둔다.
