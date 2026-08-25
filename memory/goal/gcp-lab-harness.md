# Goal — Google Cloud 실습 자동화 하네스

## 목적

한국어 실습 15개를 Google Cloud 실습 계정에서 CLI로 계획·실행·검증·정리할 수 있는 안전하고 반복 가능한 도구로 만든다. Ubuntu Bash의 Command Code `cmd` runner와 VS Code Codex Extension verifier를 분리하고 Phase별 한국어 Git 이력을 남긴다.

## 현재 지형

- 입력: 정리된 한국어 Markdown 실습 15개와 이미지 자산
- 실행 표면: Bash, Command Code CLI `cmd`, gcloud, Terraform, Git (`gh`는 원격 관리용 선택 도구)
- 현재 관찰: Command Code 1.32.2, gcloud 581.0.0, Terraform 1.15.8, Codex CLI 0.149.1, Git 2.43.0, jq 1.7, Bash 5.2 설치됨. gcloud 사용자 로그인·ADC·project read가 동작함
- 현재 결손: Phase 01–15 adapter의 로컬 구현·정적 검증은 완료했으나 개정 adapter의 전체 Cloud apply/verify/destroy와 Windows 실기동은 미검증; GitHub CLI는 선택 도구로 미설치
- 외부 제약: Marketplace CLI 지원은 제품별, Billing 데이터는 비동기, 예산은 사용 상한이 아님

## 전체 골격

1. Foundation A: 도구·계정·인증·비용 경계
2. Foundation B: 하네스 상태 머신·증거·handoff
3. Phase 01–15: 원본 Lab과 1:1인 Cloud adapter
4. 전체 E2E, 잔여 리소스 검사, release

## 완료 증거

- Phase 문서 15개와 모든 Lab/Task coverage manifest
- `plan -> apply -> verify -> destroy` 계약의 기계 판독 결과
- 깨끗한 전용 프로젝트에서 전체 Phase 통합 실행
- destroy 후 run 소유 잔여 리소스 0
- 비밀정보·state의 Git 유입 0
- VS Code Codex Extension 또는 선택형 단일 모델 review의 P0/P1 0과 사용자 승인
- Phase별 한국어 commit과 GitHub push

## 중단 조건

- 허용 프로젝트와 결제 연결이 확인되지 않으면 Cloud apply를 시작하지 않는다. 예산 한도는 D-012에 따라 필수가 아니다.
- 리소스 소유권을 증명할 manifest가 없으면 자동 destroy하지 않는다.
- Marketplace 상품의 공식 CLI 배포 경로가 없으면 해당 항목을 blocked로 표시한다.

## Foundation B 동원 — 2026-08-25

| 구분 | 기존 자산 | 이번 적용 |
|---|---|---|
| 상태 계약 | `docs/foundation/harness-core.md`, D-008~D-010 | 15개 Phase cursor와 허용 전이를 JSON으로 영속화 |
| 승인 계약 | Extension approval schema | plan/diff/evidence SHA-256 결합과 stale approval 차단 |
| 복구 계약 | `resume --run <id>` 설계 | 현재 Phase 상태에서 다음 동작을 결정론적으로 출력 |
| 안전 경계 | Q-002, Foundation A 중단 조건 | 당시 Cloud adapter와 실제 `run-all`을 차단하고 후속 구현에서 artifact gate로 교체 |
| 검증 | 최소 테스트 선호, offline 계약 | 단일 Bash fixture로 전이·승인·반려·resume 확인 |

Foundation B 컨트롤러 구현 뒤 Foundation A와 실제 supervisor 연결까지 완료했다. 현재 남은 작업은 새 run ID로 각 Phase의 Cloud·Extension 검증을 수행하는 것이다.

## Foundation A 동원 — 2026-08-25

| 분기 | 필요한 것 | 보유 자산 | 간극 → 첫 동작 |
|---|---|---|---|
| 도구 설치 | 재현 가능한 gcloud·Terraform | `scripts/doctor.sh`, 공식 설치 문서 | 버전·SHA lock과 사용자 영역 installer 구현 |
| 인증 | gcloud 사용자 계정과 Terraform ADC | D-006, 인증 guardrail 지식 | `gcloud auth login --update-adc` 단일 흐름 구현 |
| 프로젝트 경계 | exact allowlist와 billing 연결 | Foundation A 설계, D-012 | 로그인 후 프로젝트 탐색·선택·0600 로컬 config |
| Terraform 연결 | 공식 Google provider의 ADC 조회 | `hashicorp/google`, account-check module | refresh-only plan으로 계정 연결 검증 |
| 실제 apply | plan 승인·수량·timeout·cleanup | Foundation B 상태 controller | 실습 프로젝트 선택 후 첫 Cloud adapter에 연결 |

도구 설치, gcloud 인증, billing preflight, Terraform project read와 1-resource canary 저장 plan까지 채워졌다. public 저장소를 Linux `$HOME`에 clone해 Bash bootstrap 후 Command Code 대화형 구현, Extension review, 승인 후 같은 session의 next handoff로 이어지는 진입점을 연결했다. 같은 고정 모델의 구현·자기 검증 선택 경로와 Phase `execute.sh`·`verify.sh` scoped allowlist도 준비됐다. Windows PowerShell은 WSL 없이 Git for Windows Bash 호환층으로 같은 하네스를 호출한다. 현재 단일 next leaf는 새 run ID의 Phase 01 plan과 사용자 승인 hash에 묶인 Cloud 실행이다.

## Phase 01–06 재감사 — 2026-08-25

Phase 문서와 당시 adapter를 다시 대조해 Phase 01·03 부재와 Phase 02·04·05·06의 실제 동작 검증 간극을 찾았다. 현재는 모두 로컬 구현과 offline 계약에 반영했으며 canonical coverage map은 `docs/audits/phase-01-06-coverage.md`다.

| 계층 | 책임 | 완료 증거 |
|---|---|---|
| Terraform | GCP 리소스, IAM, firewall, metadata, 저장 plan | action/type/count allowlist와 plan hash |
| guest automation | disk, package, service, traffic, backup, lifecycle | 제한 시간 안의 구조화 guest evidence |
| verifier | 실제 Cloud·guest 상태와 expected failure | 모든 필수 evidence가 있을 때만 verified |
| Extension gate | diff·plan·evidence 독립 검토 | 사용자 결정과 세 hash가 결합된 승인 파일 |

Phase 01–06 공통 plan guard, Phase 01·03 adapter, Phase 02·04·05·06 실제 동작 verifier를 반영하고 offline 계약을 통과했다. Cloud canary 재실행은 별도 사용자 승인 게이트를 유지한다.

## Phase 07–15 구현 골격 v1 — 2026-08-25

Goal: Phase 07–15를 원본 실습의 세부 동작까지 자동화 가능한 Terraform·Bash/API adapter로 구현한다.

Definition of done: 각 Phase에 선언형 리소스, 승인된 imperative action plan, 실제 데이터 경로 verifier, 소유권 기반 destroy, 원본 Task coverage 계약과 offline 검증이 있으며 공통 gate가 누락된 구현을 거부한다. Cloud apply·Extension 승인·commit·push는 별도 사용자 실행 단계로 남긴다.

| 분기 | 필요한 것 | 보유 자산 | 간극 → 첫 동작 | 상태 |
|---|---|---|---|---|
| 공통 안전계층 | adapter 존재·coverage·plan/evidence 결합 | `lib/harness/terraform.sh`, `phase-gate.sh`, schema | missing verifier PASS와 임의 상태 전이를 차단 | verified-offline |
| Phase 07–09 | IAM·Storage·SQL 리소스와 권한/비밀/guest 검증 | Phase 문서, 원본 07–09, Phase 01–06 adapter 패턴 | Terraform과 action plan 책임 분리 | implemented-cloud-pending |
| Phase 10–12 | BigQuery·Monitoring·HA VPN과 query/metric/failover | Phase 문서, 원본 10–12, MCP 설계 | exact query/cardinality와 timeout verifier 구현 | implemented-cloud-pending |
| Phase 13–15 | ALB·ILB·Terraform lab과 traffic/idempotency | Phase 문서, 원본 13–15 | dual-stack·2-MIG·ping 세부 조건 구현 | implemented-cloud-pending |
| 독립 검증 | offline 계약, secret/public exposure scan | 기존 tests, Extension handoff | Phase 07–15 최소 test suite 추가 | verified-offline |

### Atomic leaves

1. 공통 gate가 `execute.sh`, `verify.sh`, Terraform, source-task contract 부재를 거부한다 — source: `scripts/phase-gate.sh`, `docs/source-map.md` — verified-offline.
2. 상태의 planned/applied/machine_verified/destroyed 전이는 해당 artifact 상태를 요구한다 — source: `bin/gcp-lab-harness`, `lib/harness/state.sh` — verified-offline.
3. Phase 07–15 각각의 Terraform과 verifier가 원본의 세부 완료 조건을 명시한다 — source: `references/google-cloud-labs-ko/labs/07*`~`15*`, `docs/phases/` — implemented-cloud-pending.
4. Phase 11의 Extension 검증 전에 Monitoring·Logging MCP 연결을 준비·확인할 수 있다 — source: `docs/mcp-integration.md`, `scripts/setup-gcp-mcp.sh` — implemented-login-pending.
5. offline suite가 Phase 07–15 전체를 실행하고 비밀·state·public 전체 ingress를 거부한다 — source: `tests/offline-phases-07-15.sh` — verified-offline.

Single next leaf: VS Code Extension에서 현재 diff를 독립 검토한 뒤 새 run ID의 Phase 01 saved plan부터 Cloud canary를 재개한다.

Known gaps: Google Cloud 통합 실행은 비용·승인 경계 때문에 이번 로컬 구현의 완료 증거가 아니다. Google provider 7.45.0 schema 검증은 통과했지만 실제 API 수렴, Windows PowerShell 실기동, MCP OAuth는 아직 검증하지 않았다.

Sub-foundations exposed: 선언형 리소스 — atomic; imperative action 승인 — not atomic → action-plan hash와 exact target으로 분리; 비밀 수명주기 — not atomic → Git 제외·0600 runtime·redaction·cleanup으로 분리; 실제 데이터 경로 — not atomic → Phase별 verifier로 분리.
