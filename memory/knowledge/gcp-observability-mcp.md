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
