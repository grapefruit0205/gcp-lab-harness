# Google Cloud 계정과 Monitoring·Logging MCP 연동

## 위치

MCP는 Google Cloud 리소스를 생성하는 실행 엔진이 아니다. 실행의 기준은 Terraform·`gcloud`·`bq`이며, 공식 Cloud Monitoring/Logging MCP는 VS Code Codex Extension이 실행 결과를 독립적으로 읽는 검증 채널이다.

| 채널 | 목적 | 기본 권한 |
|---|---|---|
| Ubuntu runner ADC | plan/apply/destroy | Phase별 최소 실행 권한 |
| Terraform ADC | 선언형 리소스 수명주기 | runner와 같은 가장 identity |
| Extension MCP identity | metric·dashboard·alert·log 조회 | read-only + MCP tool call |

## 공식 remote MCP endpoint

- Cloud Monitoring: `https://monitoring.googleapis.com/mcp`
- Cloud Logging: `https://logging.googleapis.com/mcp`

Codex CLI와 VS Code Codex Extension은 같은 Codex configuration layer를 사용하므로 Foundation에서 한 번 등록하고 Extension의 `/mcp`로 연결 상태를 확인한다.

```bash
codex mcp add gcp-monitoring --url https://monitoring.googleapis.com/mcp
codex mcp add gcp-logging --url https://logging.googleapis.com/mcp
codex mcp list --json
```

위 명령은 endpoint만 예시한다. 실제 인증 방식과 OAuth client 값은 Foundation에서 선택하며 자격 증명을 저장소 명령행이나 `config.toml` 평문에 넣지 않는다.

## 계정 준비

1. 실습 전용 GCP project와 billing을 확정한다.
2. Cloud Monitoring API와 Cloud Logging API를 enable한다.
3. Ubuntu runner는 사용자 ADC에서 전용 service account를 가장한다.
4. MCP verifier에는 별도 agent/service identity를 사용한다.
5. MCP 호출을 위한 `roles/mcp.toolUser`와 실제 조회에 필요한 최소 Monitoring/Logging 권한을 부여한다.
6. OAuth scope는 가능한 경우 `monitoring.read`, `logging.read`만 허용한다.
7. Extension `/mcp`에서 두 server가 connected인지, canary 조회가 허용 project만 보는지 확인한다.

Google 가이드는 전체 MCP 기능 사용을 위한 Monitoring Admin·Logging Admin 역할을 제시하지만, 이 하네스의 verifier는 write 도구를 사용하지 않는다. Foundation preflight는 viewer/custom role과 read scope로 canary 조회를 먼저 시도하며, 작동하지 않는다는 이유만으로 broad admin을 자동 부여하지 않는다.

## 인증 선택

우선순위는 다음과 같다.

1. Codex가 지원하는 OAuth flow와 별도 verifier identity
2. 자동 갱신 가능한 ADC/서비스 계정 가장 기반 local bridge
3. 짧은 수명의 bearer token 환경 변수(개발 시 임시)

장기 서비스 계정 key와 API key는 사용하지 않는다. bearer token은 만료되며 raw token을 `.env`, Git, review prompt에 넣지 않는다.

## Extension 검증 항목

Monitoring MCP:

- Phase label/run ID가 있는 time series 존재
- dashboard·alert policy readback
- uptime/incident 상태와 검증 시간 창

Logging MCP:

- run ID·resource label로 제한한 log query
- ERROR 이상 entry와 예상 NAT/guest/application log 존재
- destroy 이후 새 로그 발생이 멈췄는지 확인

MCP 결과는 두 번째 관측 경로다. 동일 항목을 runner의 API/CLI evidence와 비교하고 불일치하면 승인하지 않는다.

## 현재 상태

- 로컬 Codex는 remote MCP URL 등록 기능을 지원한다.
- 현재 Codex 구성에는 Google Cloud MCP server가 등록되어 있지 않다.
- GCP project·identity·권한이 확정되지 않아 연결이나 로그인은 아직 수행하지 않았다.
