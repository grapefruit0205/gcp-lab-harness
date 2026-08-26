# Google Cloud Monitoring·Logging MCP

Checked: 2026-08-25

## Confirmed

- Google Cloud는 공식 remote MCP endpoint로 Cloud Monitoring `https://monitoring.googleapis.com/mcp`와 Cloud Logging `https://logging.googleapis.com/mcp`를 제공한다.
- 두 remote MCP는 OAuth 2.0과 IAM을 사용하며 별도 agent/workload identity와 최소 권한 사용이 권장된다.
- Monitoring MCP는 time series, alert policy, dashboard 등을 조회할 수 있고 Logging MCP는 log entry와 log asset을 다룬다.
- Codex CLI 0.149.1은 streamable HTTP MCP를 `codex mcp add --url`로 등록할 수 있다.
- Codex CLI와 VS Code Codex Extension은 동일한 configuration layer를 사용한다.

## Evidence

- https://docs.cloud.google.com/monitoring/docs/use-monitoring-mcp
- https://docs.cloud.google.com/logging/docs/use-logging-mcp
- https://docs.cloud.google.com/mcp/supported-products
- https://docs.cloud.google.com/mcp/authenticate-mcp
- Official Codex configuration manual: https://learn.chatgpt.com/docs/config-file/config-basic
- Observed locally: `codex mcp --help`, `codex mcp add --help`, `codex mcp list --json` on 2026-08-25

## Limits

- 현재 Google Cloud MCP server는 Codex configuration에 등록되어 있지 않다.
- GCP project와 verifier identity가 확정되지 않아 인증·권한·canary query는 검증하지 않았다.
- googleapis `observability-mcp` local package는 preview이며 저장소 README가 공식 지원 제품이 아님을 명시한다. 기본 설계는 Google-managed remote endpoint를 우선한다.

## Uptime checker·provider 계약 보완 — confirmed (self-gated) 2026-08-26

- 공개 uptime checker의 소스 IP는 uptime IP 목록에서 조회한다. 일반 LB health checker CIDR과 같다고 가정하지 않는다. Phase11은 provider data source로 IPv4 목록을 읽는다.
- Google provider7.45의 uptime `resource_group.resource_type`은 `INSTANCE`이며 `gce_instance` enum이 아니다. `group_id`에는 Monitoring group의 `name`을 사용하는 공식 예제가 있다.
- Refutation: VM monitored resource의 `gce_instance` 타입을 group enum에도 사용할 수 있다는 가정을 provider schema/문서가 반박했다. provider 문서와 구현을 대조했고 로컬 mock/validate를 통과했다. 실제 GCP uptime 성공은 미검증이다.
- Sources: [공개 uptime/IP 안내](https://docs.cloud.google.com/monitoring/uptime-checks/using-uptime-checks), [provider7.45 계약·예제](https://raw.githubusercontent.com/hashicorp/terraform-provider-google/v7.45.0/website/docs/r/monitoring_uptime_check_config.html.markdown), [provider 구현](https://raw.githubusercontent.com/hashicorp/terraform-provider-google/v7.45.0/google/services/monitoring/resource_monitoring_uptime_check_config.go).
- Local evidence: `phases/11/terraform/main.tf`, `tests/contract.tftest.hcl`, `monitoring.py`, `tests/test-phases-10-15.py`. 최근 boolValue가 false이거나 VM/group이 다르면 검사 실패하는 fixture가 통과했다. 한계: 메일/UI/MCP 실기와 실제 metric 수렴은 별도다.
- Sub-foundations exposed: enum·group name·checker IP 목록 계약 — atomic; 실제 VM 도달성/권한/metric 수렴 — Cloud 실행 전 미검증.
