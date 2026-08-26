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

## Phase10–15·상세 콘솔 안내 골격 v2 — 2026-08-26

목표(D-044): 원문 하위 항목까지 따라갈 수 있는 콘솔 확인법과 Phase10–15의 보존형 실행·정확한 검증을 구현한다. v1은 초기 구현 기록으로 유지하며 이 재감사는 그 위의 수정이다.

완료 기준: 원문 세부 coverage, Bash·Terraform 정적 검사, 실패/거짓 성공 회귀 테스트, Phase gate, 상세 안내 출력과 새 독자 로컬 리허설 통과. 실제 Cloud 실행·브라우저 확인·새 게시와 구분한다.

| 분기 | 필요한 것 | 보유 자산 | 간극 → 첫 동작 |
|---|---|---|---|
| 실행 | 실패 후 state 보존·재계획 | Phase09 recovery·D036/37 | 다른 Phase의 auto-destroy 경로 대조 |
| 기능 | BQ/Monitoring/VPN/ALB/ILB/Terraform | 원문10–15·기존 adapter·coverage audit | 원문별 실제 검사와 오류 판정 대조 |
| 안내 | 각 Task 하위 항목의 클릭 순서·값 | 15개 문서·90 Task 표·console-checks.py | 원문 하위 제목·단계를 누락 없이 연결 |
| 증거 | offline·정적·새 독자 실행 | 기존 suites·provider lock·rehearsal | 회귀 fixture와 검증 결과 기록 |

지형 질문: API 수렴·pagination·권한 오류가 성공으로 오인되는가? 파괴적 장애 실험이 반드시 복구되는가? 재실행이 기존 state를 잃는가? 콘솔에서 확인할 수 없는 동작을 명확히 분리했는가? Cloud 실측은 이번 로컬 완료의 범위 밖이다.

원자 leaf / source / 상태:

1. 원문10–15와 각 verifier의 검증 조건 대조 — `references/google-cloud-labs-ko/labs/10*`~`15*`, `docs/audits/phase-10-15-repair.md` — observed。수동 경계·미구현 차이는 감사에 명시했다.
2. Phase10–15 실패가 자동 destroy를 호출하지 않음 — `lib/harness/safe-adapter.sh`, 실제 Bash apply/replan 실패 mock — verified-offline。legacy cleanup=true여도 삭제 호출0·state/plan/로그 보존을 검사했다.
3. 같은 run/state 재계획이 삭제·교체를 거부하고 새 승인에 결합됨 — safe adapter/advanced.py의 bundle·binding·계정/config/state guard — verified-offline。stale SHA/config 변경은 Terraform 호출 전 거부한다.
4. 각 Phase 기능 오류가 회귀 fixture에서 재현·차단됨 — `tests/test-phases-10-15.py`40개·각 Terraform mock1개(합6개), fmt/init/validate/Bash·Phase10–15 gate — verified-offline。실제 Cloud E2E는 미검증이다.
5. 90 Task의 모든 원문 하위 제목이 상세 확인 절차에 연결됨 — `scripts/console-checks.py`·13개 검사·독립 집계 — verified-offline。원문 Task 안의167개 제목/상세221항목이다. 최초177은 Task 밖 제목 포함 집계여서 정정했다.
6. 안내를 처음 보는 독자가 로컬 경로·명령을 수행할 수 있음 — `docs/audits/phase-10-15-repair.md` 리허설 기록 — observed。두 번째 독자의 로컬 명령·34문서/107개 링크 검사에서 차단되는 막힘0. 실제 UI 클릭·Cloud 실행은 제외했다.

Single next leaf: 사용자가 새 실행을 요청하면 `docs/phase-10-15-execution.md`의 본인 계정/프로젝트·clean tree 준비부터 확인하고 Phase10의 새 저장 계획을 만들기. 현재 미커밋 작업을 자동 삭제/게시하지 않는다.

Sub-foundations exposed: source/work/input/state/account/hash — atomic, mock 검사; HTTP API 상태·pagination·실패 판정 — atomic, fixture 검사; 단계형 VPN/부하 프로세스 — atomic, 상태·경계 mock 검사; Cloud IAM/quota/수렴/데이터 경로 — atomic but untested, 다음 승인된 실제 실습에서 검사; 원문 builder reset/삭제·전체 golden 정답 등 — 미구현 차이를 감사에 명시. 추가로 숨겨 둔 선행 지식 분기는 없다.

완료 근거: `artifacts/phase10-15-{local-tests,full-offline,gates}.log` 모두exit0, Phase09 기존70개 회귀exit0, 원문/Phase08/09 및 승인된 공통4개 lib diff0. `git diff --check` 통과. 이번 v2 로컬 완료는 Cloud apply·게시 완료가 아니다.

## Phase10–15 게시·Cloud 실기 골격 v3 — 2026-08-26

목표(D-045): 상세 안내·보완 코드를 커밋·푸시하고 Phase10부터 실제 apply/검증에서 발견되는 문제를 리소스 보존 방식으로 해결한다.
완료 기준: 원격 SHA 일치, 각 Phase의 새 저장 계획 승인, 실제 apply·Task별 검증 증거, 오류 시 진단/수정/새 plan 승인/재검증과 콘솔 확인 안내. 삭제는 이번 완료 기준이나 자동 후속 동작이 아니다.

| 분기 | 필요한 것 | 보유 근거 | 간극 → 첫 동작 |
|---|---|---|---|
| 게시 | 검증된 diff·비밀 제외·원격 일치 | v2 검사, GitHub 게시 knowledge | staged 경로/비밀 검사 후 한국어 commit·일반 push |
| 실행 준비 | 현재 계정·allowlist·API·정확한 plan | D017·safe adapter·config | 읽기 preflight와 Phase10 새 run plan |
| 실기·복구 | 실제 서비스 결과·로그·동일 state | Phase별 verifier·D036/37 | 승인된 apply 뒤 verify; 실패면 진단하여 최소 수정 |
| 완료 보고 | Task 하위 콘솔 확인·실기/수동 구분 | docs/console·PRODUCT-TRUTH | 실행한 Task별 상태와 증거 기록 |

지형 질문: offline 통과와 실제 API 권한/데이터 오류의 차이는 무엇인가? 각 계획이 기존 리소스에 영향을 주는가? 비용·quota·소스 변경으로 승인이 stale해지지 않는가? — 계획/실측으로 확인하며 추정 성공을 쓰지 않는다.

원자 leaf:
1. 현재 diff/비밀/검사 → commit·원격 SHA 확인 — source: Git·prepublish tests/gates·원격 ls-remote — observed。b67ce8c91542a9738870af80a19db1f8073392fc의82개 파일 게시·원격 일치·FF pull 통과.
2. Phase10 계정/project/API와 saved plan 대상·비용·SHA 확인 — source: preflight·safe adapter·BigQuery 공식 가격 — observed。run p10-260826-2106: dataset1create·삭제/교체0, bundle da21cf4a35d39146664507e7b2545b07945f3389fb0a04a8d818a844c4efd5d9. 무결성/소유권/schema 재검사 PASS. 실제 Cloud 변경 없음; 비용은 PRODUCT-TRUTH의 조건부 추정.
3. 정확한 plan 승인 — source: D017 및 사용자 응답 — named-unfilled.
4. 각 Phase10–15 실제 apply와 기능 검증 — source: run state/manifest·Task evidence — named-unfilled.
5. 실패 원인 분리·최소 수정·같은 state replan·새 승인·재검증 — source: private attempt logs/diagnosis·회귀 검사 — 오류 발생 시 분리.
6. Task별 콘솔 안내와 종료 상태 보고 — source: docs/console/phase-NN.md·실제 evidence — named-unfilled.

Single next leaf: Q-022의 Phase10 exact bundle 승인 후 저장 계획 apply·실제 검증; 오류 시 같은 run을 보존하여 진단한다. 승인 전에는 Cloud 변경하지 않는다.
Sub-foundations exposed: Git 인증/원격 비교 — atomic; Cloud 실행자/allowlist/API — atomic; 비용/정확한 계획 승인 — atomic; Phase별 실기 — not atomic →10 BQ/11 Monitoring/12 VPN/13 ALB/14 ILB/15 멱등성으로 분리.
