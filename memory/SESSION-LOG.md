# SESSION LOG — append, dated

One short section per working session: what was worked on, what was decided (with D-### links), what's pending. When context resets, this file is the recovery path — write it for the next session's reader.

---

## 2026-08-25

- Project initialized with the ballast memory structure (D-001)
- D-002~D-004에 따라 15개 실습 자동화, Ubuntu/VS Code Codex 역할 분리, Phase별 한국어 Git 이력을 설계했다.
- 로컬 CLI를 확인했다: Codex·Git·jq·Bash는 설치, gcloud·Terraform·GitHub CLI는 미설치 상태다.
- 공식 Codex·Google Cloud·GitHub 문서로 실행 계약, 인증, Terraform, Marketplace, Billing, push 가드레일을 확인했다.
- 12개 Phase 구조, 아키텍처, handoff prompt와 공통 보호 스크립트를 작성 중이다.
- D-005: 검증 환경을 VS Code 통합 터미널 CLI가 아니라 VS Code Codex Extension으로 정정했다. CLI review는 보조 gate로 내렸다.
- D-006: 실습용 Google Cloud 계정·프로젝트 연동을 설계 범위에 포함했다.
- D-007: 검증은 VS Code Codex Extension에서만 수행하도록 재확정하고 별도 CLI reviewer 경로를 제거했다.
- D-008: 단일 run-all이 Lab 01–15를 순차 실행하고 각 단계에서 Extension 사용자 승인 후 cleanup·commit·push·다음 단계로 진행하도록 확정했다.
- 공식 Google Cloud Monitoring/Logging remote MCP endpoint와 Codex의 remote MCP 지원을 확인하고 read-only verifier 설계를 추가했다.
- 로컬 `code` CLI 1.134.0을 확인해 Extension handoff에서 workspace와 review prompt를 열도록 반영했다.
- D-009: 실행 도구를 Codex CLI/`code`가 아니라 Command Code CLI `cmd` 1.32.2로 정정했다. `cmd status`에서 사용자 계정 인증을 확인했고 모델 override를 금지했다.
- 원본 Lab 01–15를 실행 Phase 01–15와 1:1로 정리하고 원본의 모든 Task를 각 Phase coverage 표에 매핑했다.
- `bin/gcp-lab-harness`와 `scripts/run-all.sh`의 안전한 단일 진입점, Command Code handoff, Extension 승인 gate, cleanup·한국어 commit·push 상태 계약을 문서화했다.
- 정리된 원본 Markdown·이미지 28개를 `references/google-cloud-labs-ko/`에 보존했다.
- 최소 검사에서 Phase 15개·연속 번호·필수 heading·모델 override 부재·JSON·Bash·whitespace와 `run-all --dry-run`을 확인했다.
- 실제 GCP adapter, account 통합 실행, GitHub remote/push는 수행하지 않았다.
- D-010: GitHub 저장소 생성과 Phase 시작 전 pull 동기화를 추가했다. 안전한 구현은 clean working tree에서 `git pull --ff-only`만 허용한다.
- 사용자 소유 기존 로컬 저장소 세 곳에서 동일한 Git 작성자 설정을 확인해 이 저장소의 local author 설정 근거로 사용한다.
- 설계 전체를 로컬 `main`의 한국어 root commit `설계: Google Cloud 15단계 자동화 하네스 구성`으로 기록했다.
- D-011: `grapefruit0205/gcp-lab-harness` private GitHub 저장소를 빈 상태로 생성하고 로컬 `origin`을 연결했다.
- 기존 Mywiki key와 충돌하지 않는 repo 전용 ed25519 deploy key와 SSH host alias를 로컬에 준비했다. write 권한 등록은 사용자 action-time 승인 대기다.
- 사용자 승인과 GitHub 이메일 sudo 인증 후 repo 전용 deploy key를 Read/write로 등록했다.
- 로컬 `main` 두 커밋을 `origin/main`에 최초 push하고 local/remote SHA 일치 및 실제 `git pull --ff-only` 성공을 확인했다.
- Foundation B 상태·승인 컨트롤러를 구현했다. 15개 Phase cursor, 허용 상태 전이, atomic JSON, Extension 승인 hash 결합, 반려와 resume next-action을 포함한다.
- 로컬 offline fixture에서 금지 전이와 stale approval이 거부되고 승인·반려·재개가 동작하는 것을 관찰했다. 설계 검사와 15단계 dry-run도 다시 통과했다.
- 실제 Cloud adapter, foreground `run-all` 자동 연결, GCP 계정 통합은 계속 미구현이며 Cloud 명령은 실행하지 않았다.
- D-012에 따라 예산 한도를 필수 gate에서 제거하고 프로젝트 allowlist·plan 승인·수량·timeout·cleanup 보호를 유지했다.
- 공식 archive와 SHA lock으로 사용자 영역에 gcloud 581.0.0과 Terraform 1.15.8을 설치하고, Google 사용자 로그인과 Terraform ADC를 연동했다.
- 유일하게 조회된 ACTIVE 프로젝트를 로컬 exact allowlist로 구성하고 billing preflight를 통과했다. 실제 apply 대상으로 사용하는 해석은 A-003으로 등록했다.
- `hashicorp/google` 7.45.0으로 실제 프로젝트 data source를 읽는 refresh-only plan을 통과했다. 첫 schema 가정 실패를 수정했으며 Cloud resource apply는 아직 하지 않았다.
- D-013에 따라 `kdt5-05`용 단일 custom-mode VPC canary adapter를 만들고 `canary001` 저장 plan을 생성했다. 결과는 create 1·change 0·destroy 0이며 실제 apply는 승인 전이라 실행하지 않았다.
- D-014에 따라 공개 clone 후 도구 설치·GCP 인증·preflight·Terraform 연결을 실행하는 bootstrap 스크립트와 README 명령을 추가했다.
- D-015에 따라 GitHub 저장소를 public으로 전환했고 코드와 커밋 이력을 누구나 열람·clone할 수 있는 상태를 확인했다.
- D-016에 따라 `$HOME` clone용 root bootstrap, 사용자 PATH 명령, PowerShell→WSL wrapper와 Command Code 대화형 start를 추가했다. machine verification 뒤 Extension review로 넘기고 승인·반려 후 같은 Command Code session을 재개하는 handoff를 CLI에 연결했다.
- D-017에 따라 Extension 분리 검증을 유지하면서 같은 Command Code 고정 모델이 구현·자기 검증을 수행하는 선택 경로를 추가했다. Phase session은 repo `.sh` 실행을 자동 승인하지만 plan SHA와 최종 사용자 승인은 유지한다.
- D-018에 따라 README를 Windows 우선 순서로 재구성했다. public GitHub 주소+복사 프롬프트, Desktop 단일 GUI 모델, PowerShell clone, VS Code Claude/Codex, 기존 Command Code 경로 순으로 배치했다.
- README 무맥락 실행 점검에서 clone 후 GUI 폴더 재선택, 고유 RUN_ID 초기화, Git 설치 후 PowerShell 재시작 안내 누락을 발견해 보완했다. 실제 Windows 런타임 검증은 수행하지 않았다.
- 후속 무맥락 점검에서 VS Code `code` 명령 설치 순서를 보완했고, 3차 정적 점검에서 섹션 순서·코드 펜스·필수 파일·GitHub 주소·whitespace를 통과했다.
- Phase 04 (Private Google Access 및 Cloud NAT) adapter를 구현했다: `phases/04/terraform/main.tf`, `phases/04/execute.sh`, `phases/04/verify.sh`, `tests/test-phase-04.sh`. VPC·서브넷(PGA)·Firewall(IAP)·외부 IP 없는 VM·Cloud Router·Cloud NAT·Logging Terraform 구성, plan/apply/verify/destroy 생명주기 및 offline/schema 검증을 통과했다.
- Phase 02 (Infrastructure Preview) adapter를 구현했다: `phases/02/terraform/main.tf`, `phases/02/execute.sh`, `phases/02/verify.sh`, `tests/test-phase-02.sh`. Marketplace Click-to-Deploy 이미지(`click-to-deploy-images`) 가용성을 사전 검사하고, Jenkins VM, 방화벽, VPC/서브넷 생명주기 및 offline/schema 검증을 통과했다.
- Phase 05 (Creating Virtual Machines) adapter를 구현하고 Google Cloud `kdt5-05`에 실제 배포 및 검증, destroy를 완료했다: `phases/05/terraform/main.tf`, `phases/05/execute.sh`, `phases/05/verify.sh`, `tests/test-phase-05.sh`. `utility-vm` (e2-medium, 외부 IP 없음), `windows-vm` (e2-standard-2, 64GB SSD, Windows Server 2022 Core), `custom-vm` (e2-custom-2-4096)의 3개 VM을 생성하고 기계 검증(`verify.sh`)을 통과한 뒤 destroy를 거쳐 활성 잔여 리소스 0개를 확인했다.
- Phase 06 (Working with Virtual Machines) 초기 adapter를 Google Cloud canary에 배포했다. 공개 IP는 기록하지 않으며 리소스는 Extension 검토를 위해 유지했다. 이후 독립 감사에서 당시 `verify.sh`가 guest mount·애플리케이션·backup·maintenance를 확인하지 않아 완료 판정은 무효화되었다.
- Phase 01–06 재감사에서 canonical coverage map을 작성하고, Phase 01·03 adapter를 추가했으며 Phase 02·04·05·06을 Terraform·guest automation·실제 상태 검증 계층으로 보완했다. 개정 adapter는 offline 계약을 통과했지만 Cloud apply는 실행하지 않았으므로 `verified`로 주장하지 않는다.
- 사용자 요청에 따라 Phase 06 리소스(`mc-server`, `minecraft-disk`, 방화벽 규칙, 백업 버킷, 네트워크)를 `phases/06/execute.sh destroy --run runphase006`로 삭제하고 GCP 프로젝트(`kdt5-05`)에서 잔여 리소스 0개를 확인했다.
- Phase 07–15의 Terraform·action plan·실제 상태 verifier를 구현하고 원본 Task 계약, provider 7.45.0 schema, 전체 offline suite를 통과했다. 실제 Cloud apply는 실행하지 않았다.
- 공통 `plan-bundle.json`, 민감 plan 정제, artifact 기반 상태 전이, 소유권 기반 destroy와 Phase 누락 gate를 추가했다.
- D-019에 따라 Windows 경로를 WSL wrapper에서 PowerShell→Git for Windows Bash 방식으로 교체하고 portable lock과 `python3` shim을 연결했다. Windows 실기동은 아직 미검증이다.
- Command Code의 무확인 실행 권한을 Phase execute script와 로컬 검증 스크립트로 제한하고 직접 `gcloud`·`terraform`·`rm` 허용을 제거했다.
- `run-all --run <id>`를 단일 Command Code supervisor에 연결하고 Phase 01–15 offline 검사를 선행하도록 했다. Cloud E2E, Extension 승인, 이번 diff의 commit/push는 남아 있다.
- 최종 안전 감사에서 post-apply/verify 실패 뒤 destroy 진입, 실패 시 자동 cleanup, Phase별 Cloud 잔여 inventory를 보강했다. Phase 08 공개 ACL은 어떤 중간 실패에서도 EXIT trap으로 회수하고, Phase 11 metric·uptime과 Phase 13 LB log는 현재 run의 exact resource만 증거로 인정하도록 수정했다.

## 2026-08-26 — Phase 06 Minecraft 공개 접속 설정

- D-020: 사용자 요청에 따라 TCP 25565만 전체 IPv4에 공개할 수 있도록 Terraform CIDR 검증과 실행·검증 코드를 변경했다. 다른 Phase의 제한, SSH IAP-only, 비공개 bucket은 유지한다.
- observed: API·시리얼 로그 및 두 차례 Minecraft status 요청에서 기존 서버가 Java 1.20.4로 응답했다. 외부 조회 사이트 timeout은 특정 source IP만 허용된 firewall와 일치하며, 게임 클라이언트 로그인은 별도로 검증하지 않았다.
- observed: 정책 단위 테스트 12개, Terraform mock test 4개, Phase 06 test/gate, Phase 01–06 offline suite와 개별 Bash syntax 검사가 통과했다. provider 7.45.0의 신규 생성 plan도 공개 port-only 정책을 통과했으며 해당 테스트 plan은 apply하지 않았다.
- 기존 run의 입력·state·manifest·evidence를 ignored updates 폴더에 보존하고 source CIDR만 변경하는 saved plan을 생성했다. observed: 추가 0·변경 1·삭제 0, 변경은 기존 Minecraft firewall의 source_ranges뿐이다. plan SHA prefix `642c5674a85a`를 사용자에게 보고했고 exact-plan 승인을 요청했다.
- 현재 단계에서는 실제 Cloud 방화벽을 변경하지 않았다. 승인 후 saved plan apply, 직접 protocol 응답·외부 조회·SSH 제한·Terraform no-drift 확인이 남아 있다. VM/디스크 재생성·서버 재시작·destroy는 범위에 없다.

## 2026-08-26 — 승인된 Phase 06 공개 접속 plan 적용

- 사용자가 exact saved-plan SHA 적용 질문에 “ㄱㄱ”로 승인했다. hash와 project allowlist·기존 run·source-only 변경 범위를 재검사하고, 승인 근거를 ignored update artifact에 기록했다.
- observed: 승인 SHA prefix `642c5674a85a`의 saved plan apply가 성공했다. 추가 0·변경 1·삭제 0이며 Minecraft firewall source_ranges만 변경했다. 기존 서버 자동 destroy 경로와 전체 cloud verifier의 stop/start는 실행하지 않았다.
- observed: 실제 API에서 TCP 25565 source `0.0.0.0/0`, SSH TCP 22 source `35.235.240.0/20`을 확인했다. VM ID·disk/address 리소스 ID와 마지막 VM 시작 시각이 유지됐다. 직접 Minecraft status는 Java 1.20.4/protocol 765를 응답했다.
- observed: run work와 현재 Terraform module을 동기화한 뒤 `plan -detailed-exitcode`가 0으로 종료해 추가 변경 없음을 확인했다. Phase 06 test/gate, Python 정책 테스트 12개와 Terraform mock test 4개, 개별 Bash syntax 검사를 통과했다.
- 외부 상태 서비스는 첫 조회에 변경 전의 실패 캐시를 반환했다. cachetime·cacheexpire를 확인했고 만료 후 재조회 중이다. 실제 플레이어 로그인과 전체 Phase E2E를 이번 네트워크 변경 검증에 포함했다고 주장하지 않는다.
- observed: 캐시 만료 후 외부 상태 API의 새 검사에서 online=true, ping=true, cachehit=false, Minecraft 1.20.4/protocol 765를 확인했다. 직접 요청과 독립적인 외부 요청 모두 성공했다. runtime manifest의 source hash·Task 4 증거 및 결과 JSON을 갱신했고 schema 검증도 통과했다. 기존 guest 증거는 보존하고 새 증거의 범위를 network-only로 명시했다.

## 2026-08-26 — Phase 07 구현 보완·저장 plan, apply 승인 대기

- 사용자 요청: “phase 7도 구현해줘 terraform apply 까지”. clean main에서 fast-forward pull을 완료하고 원본 Lab 07·Phase 계약·기존 구현을 대조했다. 단일 모델로 작업했으며 Phase 07 commit·push는 수행하지 않았다.
- observed: 기존 골격의 PGA 부재, Storage-only scope로 인한 IAM 거부 오판 가능성, 전파 대기·구체적 permission 검사·actAs 조합 검증·baseline 복구 누락을 코드에서 찾았다. Google 공식 PGA·IAM 전파·Compute SA/scope·testIamPermissions 문서와 대조했다. 외부 사실을 이번 n=1 환경의 실제 통합 성공으로 승격하지 않았다.
- 구현: private API 접근·cloud-platform scope·run ID 무절단, exact 12-resource plan guard, source/inputs/action/bundle SHA 결합, HTTP403+permission 검사와 인증·scope·API 오류 구분, metadata identity guest probe, exact unconditional tuple rollback, SA unique ID·VM/disk label 소유권과 list 실패를 보존하는 cleanup을 반영했다.
- 공통 adapter의 evidence jq context 결함을 수정하고 Phase 07에 선택형 before-apply callback을 연결했다. 다른 Phase의 별도 동작·기존 Minecraft 리소스는 변경하지 않았다.
- observed: Python 회귀 테스트 23개, Terraform mock 5개, 개별 Bash 문법, Python compile, Terraform fmt/validate, Phase 07 원본 Task 8개/gate, Phase 07–15 offline suite, diff whitespace 검사를 통과했다. Terraform provider 7.45.0의 실제 saved plan도 exact topology/IAM/network guard를 통과했다.
- observed: GCP allowlist/billing/auth 기본 preflight, enabled APIs, SA 생성·member-domain 정책 조회, Resource Manager REST HTTP200이 성공했다. 새 SA의 token 발급·IAM 수렴·guest 실행은 아직 미검증이다.
- 최종 승인 후보: run `p07-260826-72bd`, bundle SHA `cbadfcca92660a44a40653665e8ad1bc35cb61895b5699eb1467b0908ddd095e`, Terraform 생성 12·변경 0·삭제 0. code/input/action/bundle hash 일치도 재검사했다. D-017에 따라 정확한 bundle 승인 전에는 apply하지 않았다.
- 중간 후보 c4b7은 sensitive fixture 정제 이슈로 guard가 실패했고 f8e2는 후속 코드 보완으로 stale이므로 적용하지 않는다. runtime plan/state/raw log는 ignored artifacts에만 두었다.
- observed: 기존 Phase 06 VM은 재조회에서도 RUNNING, ID `1561572583393196710`, IP `136.115.246.36`, lastStartTimestamp `2026-08-25T18:58:44.598-07:00`가 유지됐다.
- 남은 작업: 사용자 bundle 승인 뒤 saved plan apply, `verify.sh --applied` read-only 검사, 승인된 IAM 실습 verify와 증거 판정. 임시 IAM grant는 검증 종료 시 회수하며 최종 VM/bucket/SA destroy·commit·push는 별도 승인 범위다.

## 2026-08-26 — D-021 승인된 Phase 07 apply와 Cloud 검증

- 사용자 “ㅇㅇ” 응답은 직전 exact bundle SHA의 apply·IAM 실습 검증 질문에 대한 승인으로 D-021에 기록했다. 승인 기록을 ignored run artifact에 저장하고 bundle/Terraform/source/inputs/active runner/planned 상태를 재검사했다.
- observed: `p07-260826-72bd` saved plan apply가 12 added·0 changed·0 destroyed로 완료됐다. apply 로그와 승인 plan backup을 보존했다.
- observed: `verify.sh --applied`가 실제 private PGA subnet·IAP-only SSH·private bucket/fixture·3개 test SA/runner binding을 통과했다. Terraform 재plan exit 0/no changes였다.
- `execute.sh verify`를 45분 전체 제한으로 시작했다. 이 시점에는 IAM 전이·guest 검증을 완료했다고 주장하지 않는다. 종료 시 임시 IAM rollback과 성공/실패 manifest·잔여 리소스를 별도로 확인한다.
- observed: 실제 actor2 token의 첫 project baseline 조회가 HTTP403 `SERVICE_DISABLED`로 실패했다. 오류 metadata의 service는 `cloudresourcemanager.googleapis.com`, consumer는 실제 `kdt5-05` project number와 일치했다. 사용자 OAuth의 같은 endpoint HTTP200이 SA consumer의 API 활성화까지 증명하지는 않았다. 오류 원문은 ignored `baseline-project-error.json`에 보존했다.
- observed: 실패 trap이 임시 project Viewer를 회수하고 Terraform 12개를 모두 destroy했다. 후속 잔여 검사의 `gcloud compute subnetworks list` 구문 오류 때문에 자동 상태는 cleanup_required가 되었으나, 올바른 `gcloud compute networks subnets list`로 재검사하여 활성 잔여 0을 확인했다. 빈 Terraform state, 삭제 bucket의 직접 HTTP404, project IAM binding baseline hash 일치도 확인한 뒤 manifest를 destroyed/completed/remaining=0으로 갱신하고 schema 검증했다.
- 구현 보완: Terraform에 Resource Manager API 활성화 1개를 추가하고 SA가 API에 의존하도록 했다. API는 cleanup 때 비활성화하지 않는다. SA token의 API 준비만 최대 600초 기다리는 read-only probe와 별도 IAM permission 검사를 유지한다. subnet CLI 경로와 해당 회귀 테스트를 보완했다.
- observed: 수정 후 Python 회귀 26개·Terraform mock 6개·개별 Bash 문법·fmt/validate·Phase gate·07–15 offline suite·diff check가 통과했다. 현재 runner의 API enable/IAP tunnel/OS Login/actAs project permission check도 missing=[]였으며, Phase 06 VM의 RUNNING·ID/IP/시작 시각이 유지됐다.
- 새 승인 후보는 `p07-260826-e6a1`, bundle SHA `78871cff6b5edfe12fb965d5f8c032595a52d4bc1c933318adc32fe366c70837`다. Terraform 13 create·0 update·0 delete, API는 정확히 Resource Manager 하나이며 disable_on_destroy=false다. source/inputs/action/bundle/Terraform hash를 재대조했다. D-021의 old SHA 승인을 확대하지 않고 새 승인을 기다린다. 새 run은 아직 apply하지 않았다.

## 2026-08-26 — D-022 수정 Phase 07 재apply와 IAM 검증

- 사용자 “ㄱㄱ” 응답으로 수정 bundle의 apply·IAM 실습을 승인받아 D-022에 기록했다. SHA·source·inputs·runner·planned 상태를 재확인하고 승인 기록과 원본 plan backup을 ignored artifact에 보존했다.
- observed: 새 run `p07-260826-e6a1` Terraform apply가 13 added·0 changed·0 destroyed로 완료됐다. Resource Manager API 활성화를 포함한다. read-only applied 검사는 API/private PGA subnet/IAP-only SSH/private fixture/3개 SA·runner binding을 통과했다. Terraform 재plan exit 0/no changes도 확인했다.
- observed: Phase 06 VM의 ID `1561572583393196710`, lastStartTimestamp `2026-08-25T18:58:44.598-07:00`, RUNNING이 유지됐다. Phase 06 관련 변경은 실행하지 않았다.
- 실제 IAM 전이 검증을 45분 전체 제한으로 시작했다. 아직 IAM/guest 완료를 선언하지 않으며 종료 후 임시 권한 복구·no-drift·Minecraft 연속성을 추가 확인한다. 성공 시 최종 destroy·commit·push는 수행하지 않는다.
- observed: API-ready, Viewer baseline/revoke, Storage-only, actAs-only 거부까지 통과했다. Compute-only VM insert가 HTTP 2xx를 반환하자 verifier가 생성 성공으로 오판했지만, 보존한 최종 zonal operation은 `DONE`, HTTP error 400, `SERVICE_ACCOUNT_ACCESS_DENIED`였고 VM inventory는 비어 있었다. 실제 IAM 경계는 기대대로 동작했다.
- observed: failure trap이 임시 IAM을 회수하고 Terraform 13개를 destroy했다. corrected 잔여 검사가 0을 확인해 manifest는 destroyed/completed다. Resource Manager API는 계획대로 활성 상태를 유지했고 project IAM binding hash·빈 Terraform state·Phase 06 VM ID/IP/start/RUNNING을 재확인했다.
- 구현 보완: create-vm HTTP 2xx 후 정확한 actor/zone/target/insert operation의 `DONE`을 기다리고, terminal error·VM 부재·actAs testIamPermissions를 함께 판정한다. allow 단계의 같은 terminal IAM 전파 오류는 VM 부재일 때만 제한적으로 재시도한다. 합성 adversarial 테스트와 캡처 operation offline replay를 포함해 Python 36개, Terraform mock 6개, Bash/fmt/validate/Phase gate/07–15 offline suite를 통과했다. 실제 수정 후 Cloud E2E는 아직 미검증이다.
- 비동기 작업의 접수/완료 구분과 해당 atomic IAM 요구사항은 실제 operation 및 Google 공식 문서를 대조해 `memory/knowledge/gcp-compute-operation-iam.md`에 기록했다. 전체 실습 성공으로 확대하지 않는다.
- observed: 수정 코드의 새 plan `p07-260826-a9d2`를 생성했다. 13 create·0 update·0 delete이며 bundle SHA `85a107f4f0bd2bbf4ab084d3babb563cc74d15dafb1b2aacdb8c8b1f70e89653`, Terraform SHA `b76666b526326c5869cc4fb46532b63a60d439c42250bbccc46bfc77cfa46369`, action SHA `044ea7fbc0303f2b8a431a8d3980d48675ea77e3962e50fa5e13dfaababdbdc7`다. pinned source/inputs/runner/manifest도 재대조했다. D-022를 재사용하지 않고 새 승인을 요청하며, 새 run은 아직 apply하지 않았다. commit·push는 수행하지 않았다.

## 2026-08-26 — D-023 비동기 판정 수정 plan 실행

- D-023: 직전 exact bundle 승인 질문에 사용자 “ㅇㅇ”가 응답했다. 새 승인 기록·원본 plan backup을 ignored run에 저장하고 code/input/action/bundle/Terraform hash·active runner·planned 상태를 재대조했다.
- observed: `p07-260826-a9d2` apply가 13 added·0 changed·0 destroyed로 완료됐다. Phase 06 VM의 ID `1561572583393196710`, IP `136.115.246.36`, lastStartTimestamp `2026-08-25T18:58:44.598-07:00`, RUNNING을 확인했다.
- read-only applied/no-drift 확인 후 동일 승인 run의 실제 IAM verify를 진행한다. 이 시점에 전체 실습 성공이나 guest 검증 완료를 주장하지 않는다.
- observed: read-only applied/no-drift(exit 0)가 통과했고 실제 verify를 시작했다. Viewer/Storage/actAs-only 및 수정된 Compute-only 비동기 거부 검사, 두 권한을 갖춘 actor의 VM 생성까지 통과했다. guest 검증은 진행 중이다.
- 사용자 질문 “야 근데 phase 7은 계정 두개로 하는 실습 아니야?”에 원문 Task 1을 재확인했다. 원문은 Username 1/2의 실제 사용자 로그인 두 개이며, 현재는 활성 사용자 하나와 가장용 SA 두 개·workload SA 하나의 대체 검증이다. 두 경로를 동등한 원문 완료로 주장하지 않고 차이를 명시했다. 진행 중 승인된 자동 검증은 임시 권한 회수까지 마무리하되 실제 두 번째 사용자 방식으로 전환할지는 Q-007로 남긴다. 다른 사용자 로그인·권한 변경은 아직 승인받거나 실행하지 않았다.
- D-024: 사용자가 원문 방식으로 구현 수정과 계정 2 이메일을 지정했다. 개인 계정 값은 ignored `config/phase-07-users.json`(600)에만 기록했다. gcloud 로그인 목록에는 계정 1만 있다. 원문을 보존하고 실제 User1/User2 OAuth 인증과 project-level 역할 흐름으로 변경한다. 가상 altostrat.com의 실제 domain grant는 하지 않는다.
- observed: a9d2의 guest 전체 matrix/Creator 업로드는 통과했지만 마지막 actor2 Storage 회수 확인에서 구체 permission을 입증하지 못해 실패했다. 자동 cleanup으로 VM/bootdisk와 Terraform 13개를 삭제했고 잔여 0·project IAM hash 복구·빈 state·Minecraft before/after 동일을 확인했다. 실행 중 프로세스는 없다. 전체 실습 성공으로 기록하지 않는다.

## 2026-08-26 — 실제 사용자 두 계정 구현·로컬 검증 완료, 수동 실습 설명

- observed: User1/User2 OAuth를 별도로 확인하는 auth helper, 실제 사용자 IAM 전이, workload SA 하나의 Terraform 9개 구성, project-level Storage 범위 고지, 원복과 실패 cleanup을 구현했다. 개인 이메일은 ignored 설정(600)에만 보존한다.
- observed: Python 47 tests, Terraform mock 8 tests, validate/fmt, 개별 Bash syntax, Phase gate, Phase 07–15 offline suite와 diff check가 통과했다. 증거는 ignored artifacts/phase-07-two-users-{unit,mock,final-gate,final-suite}.log다. references/Phase 06 소스 변경은 없다.
- observed: 실제 User1 OAuth·프로젝트 관리 권한은 통과했다. User2는 미인증이며 plan 명령이 인증 경계에서 종료해 run/plan을 생성하지 않았다(artifacts/phase-07-two-users-preflight-check.log). 새 Cloud apply/E2E·commit·push는 수행하지 않았다.
- observed: ballast:rehearsal에 따른 독립 같은 모델의 문서 점검 1회는 문서만 읽고 offline 검사(당시 44 tests)와 auth --check를 실행했다. User2 로그인 수동 경계와 후속 plan SHA 흐름에 막히는 설명은 발견하지 않았다. 실제 로그인·Cloud E2E를 점검한 것은 아니며 최종 root 회귀는 이후 47 tests로 증가했다.
- 사용자는 Qwiklabs가 문서에서 맡는 역할과 수동 실습 방법을 질문했다. 원문 Task 1/2와 공식 Exploring IAM, Start a lab, Lab provisioning 안내를 확인했다. 실습 플랫폼의 임시 사용자·프로젝트·초기 권한·접속 패널·종료 정리와 개인 프로젝트의 직접 준비를 구분해 설명한다. 이 질문으로 Cloud 권한 변경을 수행하지 않는다.

## 2026-08-26 — 사용자별 계정 등록·로그인 자동화(D-025)

- D-025: 수동 실습 초기 상태만 만드는 제안은 채택되지 않았다. 사용하는 사람마다 자신의 두 계정을 추가할 수 있는 자동화가 요청됐다.
- implemented: `accounts setup/check` CLI와 `auth.sh --setup/--ensure`, 이메일 입력·기존 값 유지/교체·소문자 정규화·원자적 600 로컬 저장, 필요한 계정의 Google 로그인과 로그인 후 identity 재검사를 연결했다. plan의 TTY 준비 흐름과 비대화형 안내 중단을 연결하고 saved apply/verify/destroy 계정은 고정했다. 사용자에게 직접 JSON/IAM 사전 편집을 요구하지 않는다.
- observed: Python 73 tests, Terraform mock 8 tests, validate/fmt, Bash syntax, Phase gate, Phase 07–15 suite, offline controller와 diff check PASS. 실 CLI의 격리 설정 등록·계정 교체·입력 실패와 Linux PTY Enter 기본값 경로를 포함한다. OAuth 성공/취소/잘못된 identity는 mock 검증이며 실제 User2 로그인 완료를 뜻하지 않는다. 로그는 ignored `artifacts/phase-07-account-setup-{unit,mock,gate,suite,controller}.log`다.
- observed: 실제 `accounts check`는 User2 미로그인으로 종료했다(`artifacts/phase-07-account-setup-auth-check.log`). 사용자 설정 Git 제외/600·공개 대상 파일의 개인 이메일 비노출·references/Phase 06 소스 변경 없음도 확인했다. Cloud 권한 변경·새 apply·commit·push는 하지 않았다.
- observed: ballast:rehearsal 1회, 같은 모델의 zero-context 실행자가 Phase 07 문서만 받고 CLI/auth help와 offline 검사(73 tests)를 실행했다. 실제 인증 수동 경계 전 차단 막힘은 없었으며 문서의 70→73 검사 수 표기 정합성만 지적해 수정/재확인했다. 실제 설정/credential 열람·로그인·Cloud 실행은 리허설 범위 밖이었다. 사용자별 준비 흐름과 수동/자동 경계를 문서와 README에 반영했다.

## 2026-08-26 — Notion 본문 재대조·공개 clone 계정 독립성(D-026/D-027)

- observed: 지정된 Notion 페이지 본문을 13:58 KST에 fetch해 전체 Task 1–8을 대조했다. 현재 본문은 개인 프로젝트의 실제 A/B 실습이며 하단 Qwiklabs 첨부와 다르다. Notion과 보존 references는 수정하지 않았다. 대조표는 `docs/audits/phase-07-notion-coverage.md`다.
- implemented: Terraform의 A actAs 사전 부여를 제거해 baseline 8개로 구성했다. Task 6에서 A가 B에게 workload-only Service Account User와 project Compute Instance Admin을 임시 부여하고 **B OAuth로 VM 생성**, B actor/DONE/RUNNING/private/workload identity를 확인한다. A의 SSH/IAM/정리는 별도다.
- implemented: Viewer 회수 후 존재하는 sample 읽기 거부, workload Creator 교체 후 쓰기 허용과 기존 sample 읽기 거부, B의 4개 임시 tuple 회수 및 A 관리자 권한 보존 검사를 추가했다. workload SA unique ID·원래 빈 정책 확인, project/workload/bucket baseline 복구를 유지한다. machine 증거에 최종 destroy 전 전체 완료 아님을 명시한다.
- confirmed D-027: 공개 clone 사용자마다 자신의 A/B 계정을 입력한다. 특정 개인 이메일/프로젝트가 로그인 기본값으로 배포되지 않는다. 최초 A 제안값은 그 환경의 활성 실제 gcloud 사용자이며 개인 설정은 ignored/mode600이다. 실제 CLI·PTY와 새 clone 사용자 기본값 회귀 검사로 확인했다.
- observed: Python 84 tests, Terraform mock 8 tests, TF fmt/validate, Bash syntax, Phase gate, Phase 01–15 offline suite, offline controller, diff check PASS. ignored 로그는 `artifacts/phase-07-notion-{unit,mock,gate,suite,controller,shared-regression}.log`다. 공개 대상 개인 이메일 비노출, 개인 설정 ignored/untracked/600, references·Phase 06 소스 변경 없음도 확인했다.
- observed: 문서 rehearsal 1회에서 새 실행자가 Phase 07 안내·CLI help/offline(84 tests)를 검사해 수동 인증 경계 전 차단 문제 없음을 보고했다. AGENTS의 index/decisions도 읽었으므로 엄밀한 문서 단독 실험으로 확대하지 않는다. 비차단 `accounts setup --help` 실패를 발견해 지원을 추가하고 실제 CLI help/84 tests/gate를 재검사했다. 실제 로그인·Cloud 실행은 리허설하지 않았다.
- observed: 실제 읽기 전용 `accounts check`는 B 미로그인으로 중단했다. 사용자에게 로컬 `accounts setup` 실행을 요청했으며 비밀번호/인증 코드를 수집하지 않는다. 새 plan/apply/E2E는 아직 수행하지 않았다. B의 project Compute 권한은 기존 VM에도, project Storage 역할은 기존 버킷에도 적용됨을 문서와 action plan에 표시했다. 기존 Minecraft에는 Cloud 변경을 하지 않았다.
- D-026의 관련 commit/push는 승인 범위다. 현재 로컬 검증 완료/최종 게시 준비 상태이며 push 완료는 실제 원격 SHA 확인 후 별도 기록한다.
- observed 후속 재확인: 실제 `accounts check`가 exit 0이며 현재 A/B 두 identity가 user-oauth/verified=true였다. 에이전트가 로그인 화면을 조작하거나 credential을 수집한 것은 아니다. 앞선 B 미인증 상태가 해소되어 새로운 고유 run `p07-260826-b53c`의 읽기 전용 preflight/저장 plan 생성을 시작했다. 아직 apply하지 않았다.
- observed: 실제 A/B 권한 baseline·API·조직 정책·이미지·이름 충돌 preflight와 Terraform 저장 plan이 통과했다. run `p07-260826-b53c`, Terraform create 8/change 0/destroy 0, bundle SHA `04f7afb8d5e1e331ae11d6da3ef0eea8936f9a77c26739c6fb97d02388d9043a`. source/inputs/action/bundle/binary SHA 일치와 manifest planned를 재검사했다. raw plan/log는 ignored artifacts에만 두었다. 새 exact SHA 승인 전 apply/VM 생성/IAM grant는 수행하지 않는다.
