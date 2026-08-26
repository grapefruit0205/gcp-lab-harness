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

## Phase11 그룹 필터 실제 오류와 보존 복구 — observed, 2026-08-26

- n=1 초기 실기: `resource.metadata.user_labels.run`은 groups.create에서HTTP400(`metadata type user_labels is not recognized`)이었다. VM3 등 기존10개 생성은 성공해그대로보존했다.
- 반박 대조: user_labels 자체가 불가능한 것이 아니라 잘못 붙인 `resource.` 접두어 문제였다. [공식 필터 문서](https://docs.cloud.google.com/monitoring/api/v3/filters)의 Defining group membership/Filtering with groups와 [그룹 API](https://docs.cloud.google.com/monitoring/api/ref_v3/rest/v3/projects.groups)를 대조해 `metadata.user_labels.run`으로 수정했다. 두 문서는 같은 공급자 근거이며 독립성 한계를 고려해 일반 confirmed 주장이 아닌 실제 관측으로 기록한다.
- 같은run replan은10no-op/2create/삭제교체0, bundle `fecc81639ab7b0344faf1ba0f8efc2a78968c610117d992c1dd447e6e8051507`. 수정 apply exit0을관측했다. 실제group/uptime 메트릭 검증은진행중으로별도판정한다.
- 로컬: Python45개(그룹 invalid접두어 및 Phase12 zone회귀 포함), Phase11 TF mock/gate 통과. 사후실기 근거는run `p11-260826-2224`의개별attempt로그/manifest다. dashboard v1과timeSeries기존metadata필터는그대로구분한다.
- 후속 observed: 설정4개 GET과멤버3개조회는성공했지만CPU timeSeries만HTTP400이었다. 응답은metadata필터가aligned metrics에서만허용된다는내용이었다. CPU조회에60초/ALIGN_MEAN을추가하고bool uptime에는평균을적용하지않는46번째회귀를통과했다. [timeSeries.list aggregation 계약](https://docs.cloud.google.com/monitoring/api/ref_v3/rest/v3/projects.timeSeries/list)과대조했다. 실패시어느조회인지표시하며구성/CPU/uptime/수렴상태를private evidence에남기도록보완했다.
