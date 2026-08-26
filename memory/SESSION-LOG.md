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
- observed 14:12 KST: 관련 구현·테스트·문서/기록 40개 파일을 한국어 commit `ad24c8d7918dca6a336d20f1b3e22543e9dd9411`로 만들었다. HTTPS push는 credential 부재로 실패했으나 기존 저장소 전용 SSH alias와 BatchMode/StrictHostKeyChecking으로 같은 원격에 일반 push했다. 무인증 HTTPS `git ls-remote`에서 main SHA 일치를 확인했다. 개인 키 내용/인증정보를 열람하거나 origin/global Git 설정을 바꾸지 않았다. 새 apply·Cloud E2E는 아직 승인 대기다.

## 2026-08-26 — 이전 실습 백업 없이 destroy(D-028)

- confirmed: 사용자가 Minecraft 서버·월드 디스크·기존 백업 버킷·고정 IP 삭제 설명 뒤 “백업 하지말고 전부 destroy 해줘.”라고 명시했다. 기존 보존 방침을 대체하고 이전 하네스 실습의 실제 리소스와 임시 IAM을 정리한다. 새 백업/스냅샷은 만들지 않는다. 프로젝트·결제·사용자 인증·공통 API와 소유권 미확인 기존 리소스는 유지한다.
- observed: 실제 inventory에서 VM 1개·disk 2개·Minecraft 전용 network/subnet/firewall 2개/address/bucket/SA가 확인됐다. Phase 5 `runphase005`의 state 5개는 Cloud에서 이미 삭제된 stale 기록이었다. 과거 Phase 4/5/6/7 및 foundation state는 비었고 최신 Phase 7은 never-applied다. 현재 User2 direct role과 하네스 project IAM 잔여도 0이다.
- observed: 저장 destroy plan은 Phase 6 10개 delete-only, SHA `b057bcce8c73cd95a4099d2dec0937d976b9663a5c6fb2af1add255f15033329`; Phase 5는 destroy 0/state refresh, SHA `6f2778a762a1f127f1308bb12a34571ac39385243f9b091a6f954dea74243da3`다. project/run/exact 10 resource address와 binary hash를 검사한 뒤 적용을 시작했다. Phase 5 적용은 0 added/changed/destroyed와 빈 state로 완료됐다. Phase 6은 Cloud 삭제 중이며 아직 완료로 주장하지 않는다.
- 경계: 기존 Minecraft backup bucket에 7일 soft-delete 정책이 확인됐다. Cloud의 기존 보존 정책을 임의 변경하지 않으며 새 백업은 만들지 않는다. Terraform 밖 `junseok-lab` bucket·기존 snapshot·수동 SA/firewall은 이번 이전 실습 대상인지 사용자에게 비차단 질문했고 확인 전에는 삭제하지 않는다. raw inventory/plan/approval/log는 ignored `artifacts/cleanup-before-phase08.PSOwfC/`에 보존한다.
- observed 완료: Phase 6 저장 삭제 plan은 0 added/0 changed/10 destroyed로 끝났으며 부팅 디스크도 VM과 함께 사라졌다. 실제 프로젝트 VM·disk·address·router는 각각 0, 하네스 network/subnet/firewall/bucket/SA 활성 잔여는 0이다. 기록된 모든 Terraform state가 비었음을 검사했다.
- observed 보존: project IAM policy, 활성 API 목록, 기존 default network/subnet, 비대상 firewall, 다른 bucket/snapshot/SA를 전후 비교해 동일함을 확인했다. User2 direct project role도 0이며 프로젝트·ADC·결제 preflight가 다시 통과했다. 소유 불명 기존 5개 리소스는 사용자 확인 전 보존했다.
- observed 런타임 종료: Phase 6/오래된 Phase 5 manifest는 destroyed·cleanup completed로 갱신했다. 미적용 Phase 4·Phase 7 두 계획·foundation canary도 신규 생성하지 않고 종료했다. 미적용 task는 skipped/미검증으로 남겼으며 모든 Phase manifest schema를 통과했다. 기존 binary plan은 감사 자료로 보존하지만 manifest guard가 재apply를 막는다.
- observed 복구 보존: gcloud의 soft-deleted JSON 목록은 HTTP404로 실패해 성공으로 간주하지 않았다. 공식 JSON API는 HTTP200으로 대상 bucket을 반환했고 hardDeleteTime은 2026-09-02 14:40:59 KST다. 새 백업은 없지만 기존 정책에 따른 복구 보존 데이터는 남아 있음을 별도로 보고한다. → recorded in memory/knowledge/gcp-storage-soft-delete.md (2026-08-26).
- 검증: exact project/run/delete-only plan guard·binary SHA, Terraform validate, 개별 Bash syntax, Phase 05/06 gate, 실제 inventory, IAM/API/비대상 전후 비교, 빈 state, manifest schema, diff check를 확인했다. 소스/원문/개인 로그인 설정은 변경하지 않았고 commit·push·Phase 8 apply는 수행하지 않았다.

## 2026-08-26 — 남은 5개 추가 삭제 완료(D-029)

- confirmed: 사용자가 남겨둔 5개 목록에 “전부 삭제해 ㅇㅇ”라고 답해 Q-008을 해결했다. 이어 “매번 재확인 하지말고 빨리 지워”라고 지시했다. 확정된 삭제 범위에 대한 추가 승인 질문 없이 실행했으며, 동일 대상 식별과 사후 검사는 도구로 수행했다. 별도 영구 pin/규칙 카탈로그 승인을 다시 묻거나 카탈로그를 수정하지 않았다.
- observed: 새 사전 조회에서 `lampstack`·`read-bucket-objects` SA는 이미 없어졌고 default compute SA만 남아 있었다. 두 계정의 삭제를 에이전트가 수행했다고 주장하지 않는다. project IAM에는 정확한 삭제 principal UID의 tombstone binding 4개가 남아 있어 제거했다. 제거 후 다른 principal/role/condition은 원래 policy와 동일했다.
- observed: `junseok-lab` bucket과 모든 객체 버전, `mynet-us-vm-us-central1-a-20260825000711-ynklv6qi` snapshot, `privatenet-allow-ssh` firewall 삭제 명령이 모두 성공했다. 저장 action plan SHA는 `f58cb941f25d7c83fa8cb0f9dc588d813235180c186834443275bcf6caad8618`, IAM exact tuple plan SHA는 `27942d7791f64b96a453cd0657a1fe5e399040d472f5c4c1d27c9387406ff425`다.
- observed 검증: live bucket/snapshot 0, 지정 firewall/SA/IAM 잔여 0, default compute SA 하나와 기본 firewall 3개만 남았다. project/ADC/billing preflight도 통과했다. 새 백업은 만들지 않았으며 기존 bucket의 soft-delete 보존 기간 604800초는 변경하지 않았다. 기본 네트워크·프로젝트·공통 API·사용자 로그인은 삭제 대상이 아니었다.
- 증거: ignored `artifacts/cleanup-extra-before-phase08.zWWylo/`의 action/iam plan, 삭제 로그, 전후 policy/inventory, `result.json`. 정리 결과만 로컬 memory에 기록했고 Git commit/push나 Phase 8 apply는 하지 않았다.

## 2026-08-26 — Phase 08 Cloud Storage 구현·로컬 검증

- 요청: 사용자가 Phase 8 구현을 요청했다. 기존 미커밋 cleanup 기록을 보존했으며 원격 main=HEAD `7e6df290`을 확인했다. dirty tree에서 pull/stash/reset하지 않았다. 이번 요청은 신규 Cloud apply·commit·push로 확대하지 않았다.
- observed: 원본 Lab 08 Task 1–8 전체, 기존 adapter·공통 계약·기록을 대조했다. 원문은 수정하지 않았다. 기존 CSEK rewrite 옵션 누락, 키/네트워크/인증 오류 혼동, 모든 bucket describe 실패를 부재로 처리, sync hash 미검사를 발견했다. 공식 API 오류표·rewrite·PAP·soft-delete 문서로 판정 기준을 검증했다. → recorded in memory/knowledge/gcp-storage-csek-api.md (2026-08-26).
- implemented: 본인 실제 사용자 한 명을 saved inputs로 고정, OAuth userinfo와 allowlist, source/fixture/input/action/bundle SHA, work module/TF state 대상, bucket label·project·생성 시각 검사. 같은 run 동시 실행과 verify 재실행 거부. 전역 gcloud 설정/로그인은 변경하지 않는다.
- implemented: 리전형 fine-grained 전용 bucket 1개, versioning/31일 Delete lifecycle, 새 bucket의 soft-delete=0. fixture 하나만 no-store 임시 public ACL 테스트 후 회수하며 grant 응답 유실도 회수 경로에 포함한다. PAP는 명시적 policy-prevented 경계로 표시하고 일반412/인증/네트워크 오류는 통과시키지 않는다.
- implemented: CSEK 두 개는 메모리에서 생성해 HTTPS JSON API header로만 사용한다. 두 객체의 최초 복호화/metadata, rewrite continuation, 구키·신키 성공/거부를 검사하고 키 폐기 전 모든 암호화 세대를 삭제한다. 원본·5줄씩 줄인 총3세대 목록/크기·저장 generation 로컬 hash 복구, gcloud recursive rsync 2개 객체와 개별 다운로드 hash를 검사한다. 원문 외부 Hadoop HTML·YAML 키 저장소·콘솔·정책 설정 순서와의 차이를 guide에 명시했다.
- observed: Python 40 tests, Terraform validate/fmt·mock 4 tests, 실제 provider mock JSON plan 3개→Python guard, Phase 08 gate, shared Phase 07–15 offline suite, diff check PASS. 실제 Bash 실패→destroy 후에도 실패 exit 유지, 삭제 후 inventory 실패→cleanup_required, 승인 입력/코드/TF override 차단을 격리 clone에서 검사했다. 로그: ignored `artifacts/phase-08-offline.log`, `artifacts/phase-08-shared-offline.log`.
- observed rehearsal 1회: ballast:rehearsal의 같은 모델 새 실행자가 한국어 clone 사용자 페르소나로 Phase 08 guide를 읽고 문서의 test script·phase gate·execute help를 실제 실행했다. 모두 exit0이며 막힘 없음. README/개인 config/credential 열람, 로그인, 실제 Cloud 명령, Git 쓰기는 하지 않았다. docs의 로컬 준비와 exact SHA 승인·verify 변경 작업·최종 destroy 경계를 이해했음을 보고했다.
- limits: 실제 OAuth/Storage 정책·CSEK 응답·Cloud E2E·Windows 실기동은 이번 검증 범위 밖이다. 강제 종료/전원 차단/권한 상실이나 OS swap/메모리 완전 소거는 자동 cleanup/비밀 폐기 보장으로 주장하지 않는다. plan/apply/실제 Cloud 리소스 생성·삭제·IAM 변경·commit·push는 이번에 수행하지 않았다.

## 2026-08-26 — Phase 08 실제 saved plan 준비

- 사용자 후속 “ㄱㄱ”를 Phase 08 실행/게시 진행 의도로 읽고(A-004) 새 plan을 준비했다. 아직 보지 못한 exact SHA를 승인한 것으로 간주하지 않았다. 같은 일반 쉘 실행은 재질문하지 않았다.
- observed: 실제 현재 사용자 OAuth userinfo, 공통 GCP/ADC/project allowlist/billing, live/soft-deleted bucket 이름 충돌 검사가 통과했다. run `p08-260826-8c1d` plan은 새 region bucket 1개 create, change0/destroy0이다. 기존 Cloud 리소스 변경은 없다.
- observed: Terraform binary SHA `87a9b242b1ae7f55e9a7d1b5a2ce1dbb6128cf4c5a3335a4ab03eae0f9d25150`, action SHA `b0d8bd1dd3a0ceb1d00970aa8097b42888504f5beac2882febf689545a42ad44`, bundle SHA `6d8a5c88f64c982508ff900f80aa632810a300d69f4b8fb302741154369499a3`를 대조했다. source/input hash, schema, create-only scope와 manifest planned도 일치한다.
- observed: Python40/Terraform mock4/provider JSON guard3/Phase08 gate 재통과. ignored 로그 `artifacts/phase-08-cloud-plan.log`, `phase-08-preapply-offline.log`, `phase-08-preapply-gate.log`. 개인 계정은 ignored saved inputs에만 기록하며 token/key는 출력하지 않는다.
- 경계: 새 bucket soft-delete=0, fixture 임시 공개·회수, CSEK 전체 암호화 세대 삭제와 실패 cleanup을 포함한 plan의 사용자 승인을 요청한다. 승인 후 apply/실습검증·관련 변경 stage/commit/push를 진행할 예정이며 정상 종료 후 전체 destroy는 별도다. 이번 턴에서는 apply·실제 객체 생성·IAM 변경·Git stage/commit/push를 수행하지 않았다. 기존 미커밋 cleanup 기록을 보존했고 원격 main=HEAD 7e6df290을 확인했다.

## 2026-08-26 — Phase 08 승인 실행·실패 정리·오류 판정 보완(D-030)

- confirmed: 사용자가 exact bundle SHA `6d8a5c88f64c982508ff900f80aa632810a300d69f4b8fb302741154369499a3`의 apply·실습 검증·관련 변경 stage/commit/push에 “ㅇㅇ”로 승인했다. A-004를 D-030으로 확정했다. 정상 성공 후 전체 bucket destroy 승인은 포함하지 않는다.
- observed: run `p08-260826-8c1d` Terraform apply는 1 added/0 changed/0 destroyed이며 bucket 정책·identity readback도 통과했다. 실제 verify는 HTTP401로 실패했고 자동 cleanup이 bucket 1개를 삭제했다. manifest destroyed/cleanup completed, 올바른 TF_DATA_DIR의 state list exit0/빈 목록과 state resources0, live bucket0/soft-deleted bucket0 evidence를 확인했다. 전체 Cloud 실습 성공으로 기록하지 않는다. 근거는 ignored `artifacts/phase-08-cloud-{apply,verify}.log` 및 해당 run의 `verification-cleanup.log`, `evidence/phase-08-destroyed.json`이다.
- observed/unknown: 삭제된 exact bucket의 alt=media를 읽기 전용으로 조회해 일반 텍스트404를 관측했다. 최초401은 기존 로그에 Task/응답 형식이 없어 요청 위치·정확한 원인을 단정하지 않는다. JSON-only 오류 가정을 수정하고, 익명401/403은 같은 generation의 인증 GET 전후 대조로 확인한다. CSEK media400에 구체 reason이 없으면 같은 generation·키의 checksum metadata에서 정확한 CSEK 거부를 추가 확인한다. 안전한 Task/오류 형식 진단만 출력하고 외부 body/비밀은 출력하지 않는다.
- observed: 수정 후 Python44 tests, Terraform mock4/provider JSON guard3, Bash syntax·TF fmt/validate, Phase08 gate, Phase07–15 offline suite와 diff check PASS. 로그는 ignored `artifacts/phase-08-media-fix-{offline,gate,suite}.log`다. 설정의 개인 계정과 실제 credential 패턴은 게시 후보에 없고 config는 ignored/mode600이다. artifacts의 추적 파일은 기존 `.gitkeep`뿐이며 원본 references/Phase06 코드는 변경하지 않았다.
- observed rehearsal 1회: ballast:rehearsal에 따른 같은 모델의 새 실행자가 Phase08 guide만 받아 Python44·Terraform/plan guard·gate와 CLI help를 실제 실행했고 exit0이었다. README/개인 설정/자격 증명 열람·Cloud 요청·Git 쓰기를 하지 않았다. 문서의 Cloud plan 경계 앞에서 중단했으며 로컬 실행 차단 문제는 없었다. help는 문서 명령이 아닌 별도 리허설 지시로 실행했다. 로그는 `/tmp/phase08-rehearsal.PKJo8q/`이며 실제 Cloud 성공 증거가 아니다.
- observed: 수정본 run `p08-260826-c924` 새 saved plan은 US-CENTRAL1 bucket `gcp-lab-p08-p08-260826-c924` 1개 create/change0/destroy0이다. binary SHA `61a32d1644bf1e6bfb0c6bf619d63a6fe5d060c53fefbdb351b01561ce68551e`, action SHA `46231c5b10f44c6c1cdb5f72ddeb46361b855e3d6b285a2905fc63268a63df6d`, bundle SHA `1222d79e290b309f117390ff457b5da1aa2577fef1a30bec32aa770ef575450a`와 source/input hash·schema·scope·manifest planned를 재확인했다. `artifacts/phase-08-revised-plan.log`가 근거다. 새 SHA 승인은 아직 없으며 apply하지 않았다.
- 게시 경계: D-030에 따라 관련 구현/테스트/문서/기록을 게시하되 실제 Cloud 실습 실패와 수정본 재검증 대기를 명시한다. 로컬 gate 통과와 Cloud 실습 성공을 혼동하지 않는다. 최종 원격 SHA는 실제 push 뒤 기록한다.
- observed 15:30 KST: 관련 24개 파일을 한국어 commit `33eae83edf73ccf272b6a8f352de4ecd3e14cd95`로 만들고 기존 저장소 전용 SSH alias를 통해 main에 일반 push했다. 무인증 HTTPS `git ls-remote origin refs/heads/main`으로 원격 SHA 일치를 확인했다. force push·원격/전역 설정 변경은 없었다. 게시 후 복귀 checkpoint를 archive하고 현 상태와 Q-009의 정확한 재개 명령을 갱신했다. 새 Cloud apply는 여전히 승인 대기다.

## 2026-08-26 — Phase 08 수정 plan 승인·실제 실습 성공(D-031)

- confirmed: 사용자가 bundle SHA `1222d79e290b309f117390ff457b5da1aa2577fef1a30bec32aa770ef575450a`의 재apply·실습 검증에 “ㅇㅇ”로 승인했다. D-031을 기록하고 Q-009를 닫았다. 같은 승인이나 일반 `.sh` 실행을 다시 묻지 않았다.
- observed: clean tree에서 `git pull --ff-only` 결과 already up to date이며 HEAD=origin/main `f39ffe070595885834b442ec3c709345c7799ac5`였다. saved source/input/bundle/binary SHA·planned 상태·단일 create 범위를 재확인하고 Python44/Terraform mock4·JSON guard3·Bash/TF 정적 검사·Phase08 gate를 재통과했다. 로그는 ignored `artifacts/phase-08-reapply-{local-tests,gate}.log`다.
- observed: run `p08-260826-c924` apply는 1 added/0 changed/0 destroyed와 bucket identity/policy readback 성공이다. 실제 verify는 exit0, manifest verified/Task1–8 passed다. 임시 public ACL 생성·익명 hash·회수, CSEK 두 객체의 구키/신키 matrix·rewrite와 암호화 전체 세대 삭제,31일 lifecycle readback,3세대 원본 로컬 복구,recursive sync2개 다운로드 hash를 통과했다. risks는 빈 목록이다. 로그는 ignored `artifacts/phase-08-reapply-{cloud,verify}.log`, 증거는 해당 run `evidence/phase-08-machine.json`이다.
- observed 15:35 KST: 별도 읽기 전용 gcloud 조회에서 bucket1/객체 세대5(setup3+sync2), 공개 객체 ACL0/공개 bucket IAM0/암호화 객체0을 확인했다. 생성 identity·versioning/lifecycle/soft-delete0과 Terraform state bucket1, 복구 및 sync 로컬 hash도 재대조했다. gcloud 생성 시각 `.891000+00:00`과 API `.891Z`는 표현만 달라 UTC epoch 정규화 후 일치했다. 새 변경이나 승인 guard 완화는 없었다. evidence는 `phase-08-postverify-audit.json`, 원시 metadata는 ignored `artifacts/phase-08-postverify-*.json`이다.
- limits: 성공 n=1이며 실제31일 삭제·Windows·15개 전체Lab 성공으로 확대하지 않는다. CSEK 임시 객체2개의 모든 암호화 세대는 승인된 실습 정리로 삭제했고 암호화 키는 보관하지 않는다. 원본 fixture는 저장소에 남아 재생성 가능하다. 최종 bucket 전체 destroy는 승인 범위가 아니므로 실행하지 않았으며 남은 비공개 bucket1은 보관/API 비용 대상이다.
- 기록: proof-standard에 따라 truth file을 먼저 갱신하고 guide의 실행 상태를 그 증거에 맞췄다. checkpoint는 archive 후 갱신한다. 이번 턴은 실행·검증과 로컬 결과 기록까지이며 새 commit/push는 수행하지 않는다. 기존 게시 구현 SHA와 다른 소스 변경은 없다.

## 2026-08-26 — Phase 08 검증 기록 게시·Phase 09 진행 요청(D-032)

- confirmed: 사용자가 “커밋 푸쉬 하고 phase 9 실행해줘”라고 요청했다. Phase08 관련 결과 기록 stage/한국어 commit/push와 Phase09 실행 준비를 진행한다. 새로운 Cloud plan SHA 승인과 Phase08 bucket 보존 경계는 유지한다.
- observed: recall로 index/knowledge/decisions/프로젝트·사용자 rules/goal 골격을 점검했다. SQL 전용 검증 지식은 없으며 기존 Cloud/Terraform 가드레일과 게시 워크플로, Phase09 원문·문서·execute/verify/Terraform을 열었다. Phase09는 Cloud SQL1/WordPress VM2 구성으로, 새 실습 실행 전 artifact URL/hash·제한 CIDR 입력과 비밀번호·실패 정리 경로를 점검한다.
- observed rehearsal 3차: 같은 모델 새 실행자가 Phase08 문서만으로 로컬 test(Python44/TF mock·JSON guard), phase gate, help를 실행해 모두 exit0이었다. 명령·Cloud 경계에 차단/추측은 없었다. README·개인 설정·기존 artifacts·Cloud·Git 쓰기는 범위 밖이었다. 로그 `/tmp/p08-rehearsal3.oj6dhb/`. Cloud 재검증을 뜻하지 않는다.
- observed: Phase08 기록을 `dad0cc0`으로 commit/push하고 무인증 원격 main SHA 일치를 확인했다. 기존 저장소 전용 SSH alias만 사용했으며 origin/global 설정·개인 키는 바꾸거나 열람하지 않았다. 이후 clean tree에서 `git pull --ff-only`가 Already up to date였다.
- observed: Phase09 첫 plan은 client CIDR 누락으로 run 생성 전에 중단됐다. SQL/Service Networking/IAP API 미활성, SDK quiet+password prompt 충돌, 기존 verifier의 실패 정리/HTTP 오탐 가능성을 확인했다. → `memory/knowledge/gcp-sql-wordpress.md`에 공식 근거·실제 관측·미검증 범위를 분리 기록했다.
- implemented: 공식 artifact lock·현재 client /32·실제 본인 OAuth, source/input/approved bundle·run state/identity guard, MySQL8 Enterprise 원문 tier·API3개, SQL API 비밀번호 초기화/교체, stdin guest config·관리자 설치, WordPress DB eval·두 HTTP SQL-backed marker와 probe 회수, 실패 자동 cleanup과 PSA 지연 상태 보존을 보완했다. Phase08 및 shared lib 소스는 변경하지 않았다.
- observed: 최종 Python33·Terraform validate/mock3·JSON plan guard2와 개별 Bash syntax가 통과했다. 최초 gate 호출에 문서 경로 대신 숫자09를 넣어 중단되어 올바른 문서 경로로 재실행했다. 이 CLI 인자 오류는 Cloud 실행과 무관하다. 최종 gate/suite와 문서 리허설은 별도로 진행 중이다.
- observed: 고유 run `p09-260826-5d82`의 읽기 전용 preflight·Terraform 저장 plan이 완료됐다. bundle SHA `d418a5b7ed219126889882f2e1e296b1e34dcea26b256dc329774119fb561cf4`. 신규 Cloud apply·실제 SQL/HTTP 검증은 하지 않았으며 새 exact SHA 승인 대기다.
- observed: 최종 Phase09 gate·Phase07–15 suite도 통과했다. 실제 plan은16create-only, SQL 원문 tier·region, 제한 HTTP /32이고 source/input/action/bundle/binary hash·manifest/action schema가 모두 일치했다. 개인 설정/tfvars는600·ignored이며 Phase08/shared lib/원문 변경 없음과 diff check를 확인했다. Phase09 변경은 로컬 미커밋 상태다. Q-010으로 새 exact SHA apply·실습 검증 승인을 요청한다.
- observed rehearsal 1차: 문서 로컬 검사3개가 exit0이었다(Python33/TF/gate/help). apply 예시의 `--approved-plan-sha`와 CLI help의 `--confirm-plan-sha` 불일치를 지적했고, 현재 문서는 실제 옵션인 confirm으로 수정됐다. 필수 AGENTS/index/decisions도 읽어 엄격한 무맥락 실험은 아니며 README/구현/credential/기존 artifacts·Cloud 실행은 범위 밖이었다. 로그 `/tmp/p09-doc-rehearsal.J3ttse/`. 수정 문서의 새 독자 2차 검사를 진행한다.
- observed rehearsal 2차: 새 실행자가 수정 문서의 로컬3명령(Python33/TF/gate/help)을 모두 exit0으로 실행했고 중단·추측·도움말 불일치가 없었다. 필수 AGENTS/index/decisions·관련 skill은 읽었고 README/구현/설정/credential/기존 artifacts/Cloud 실행·Git 쓰기는 하지 않았다. 로그 `/tmp/phase09-guide-rehearsal2.HJL6Fp/`. 로컬 범위 clean이며 Cloud E2E나 게시 승인으로 확대하지 않는다. Q-010 사용자 승인 대기로 마무리한다.

## 2026-08-26 — Phase09 승인 plan 적용·실제 검증(D-033)

- confirmed: Q-010 exact bundle SHA의 apply·실습 검증 제안에 사용자가 “ㄱ”으로 승인했다. D-033에 run·scope·실패 정리·비포함 범위를 기록했다.
- observed 16:05 KST: source/input/action/bundle/binary hash·create-only guard·manifest schema·diff 검사를 재통과한 후 저장 plan apply를 시작했다. 로그는 ignored `artifacts/phase-09-cloud-apply.log`이며 아직 성공으로 판정하지 않는다. 원문/Phase08/shared lib/승인 실행 소스는 변경하지 않았다.
- observed 16:13 KST: apply exit0, Terraform16added/0changed/0destroyed, manifest applied·전체 Cloud identity 기록·root 비밀번호 초기화 완료다. Python33/TF mock·validate/phase gate 재검사도 통과했다. 현재 client IPv4와 saved /32 일치, private VM startup 정상 종료를 읽기 전용으로 확인했다. 이어 승인된 실제 machine verify를 시작했으며 아직 SQL/HTTP E2E 성공으로 기록하지 않는다.
- observed: verify는 root API 갱신 후 guest readiness/WordPress config 단계에서 CLI 오류로 실패했다. SQL marker/HTTP 검증 단계에는 도달하지 못했다. 두 VM startup 정상 종료, 현재 사용자의 OS Login/Admin/IAP/actAs 권한을 재조회했으나 세부 guest 오류는 미보관이라 원인을 단정하지 않는다. WP-CLI 공식 stdin 설치/loader·로컬 gcloud SSH stdin/command 경로를 읽기 전용 점검했으며 아직 특정 결함 재현은 없다. Q-011에 등록했다.
- observed 16:21 KST: 승인된 자동 cleanup은 VM2/disk2/SQL1·DB/subnet/firewall2/SA2/관련 IAM을 삭제했지만 PSA Delete가 producer 사용 중 Error9로 거부됐다. 별도 Cloud 목록/identity/state/IAM 조회에서 전용 VPC1/range1/ACTIVE connection1만 남았고 공통 API3개는 유지됐다. state6개(전용3+API3)와 source SHA를 보존한다. manifest cleanup_required/cleanup failed/remaining3으로 수정하고 schema를 재검사한다. `evidence/phase-09-postfailure-audit.json`과 `verification-cleanup.log`가 근거다. Q-012에 지연 정리를 등록했다.
- 사용자 질문 “지금 어느 계정에서 만들고 있는거니”에 saved inputs의 실제 실행 사용자·프로젝트를 읽어 답했다. 다른 계정으로 전환하거나 새 리소스를 생성하지 않았다. 개인 이메일은 Git 기록에 추가하지 않는다. 추가 commit/push는 하지 않았으며 Phase08은 보존한다.

## 2026-08-26 — Phase09 재생성 준비(D-034)

- confirmed: 사용자가 “새로 생성 부탁해”라고 요청했다. 현재 로그인·허용 project를 유지하며 새 고유 run/plan을 준비하되 D-017의 exact SHA 승인과 추가 Git 게시 경계는 유지한다.
- observed: 이전 실행 소스만 `artifacts/approved-code/phase09-5d82`에 보존하고 config/artifacts를 원본으로 연결했다. 기존 state/lock을 공유하는 snapshot에서 승인 source hash를 검증한 뒤 기존 destroy를 재시도했으나 Error9/producer 사용 중으로 종료됐다. state 제거·강제 peering 삭제는 하지 않았다. 로그 `artifacts/phase-09-prior-cleanup-retry.log`, Q-012 유지.
- observed: 기존 guest startup 로그에 php8.2-cli 설치와 mysqli/mysqlnd가 명시되어 PHP CLI 누락 가설은 반증됐다. SSH 권한·설치 정상만으로 WordPress 실패 원인은 확정할 수 없으며 Q-011은 열린 상태다.
- implemented: `guest_install.py`를 source hash에 포함하고, sudo 비대화식 실행·PHP/mysqli·config lint·DB SELECT1 readiness·WordPress CLI/install/is-installed 검사를 나눴다. JSON stage/reason/exit_code 허용 목록만 evidence에 기록하고 child stdout/stderr·예외 원문을 출력하지 않는다. DB/admin 비밀번호는 stdin이며 config는 guest에서만 root:www-data0640으로 최초 생성한다. 최종 WordPress/SQL/HTTP gate와 실패 cleanup은 유지한다.
- observed: Python44 tests·Terraform fmt/validate/mock3·provider JSON guard2·Phase09 gate·Phase07–15 suite가 모두 통과했다. DB transient retry/deadline·비밀 비노출·실제 임시 config 생성/권한·덮어쓰기 거부·transport JSON 거부·추가 source hash 검사를 포함한다. PHP/DB child는 mock이며 실제 Cloud 성공 증거가 아니다.
- observed 16:34 KST: 새 run `p09-260826-eb03`, 16create/0change/0destroy, bundle SHA `bc763bc4bec0092bdbd0a1fd8efc3e564df8a2ed6c0952bb43762fce102fb7ab`. Terraform SHA `ff0c2f9209d58eb22646a4f5ea0f3717554f095bd7394ef02b391f4e07d93e19`, action SHA `053599b926532ef1923aa2c154bc11e3fdd91377d48345a982c9518b1bccb72c`. source/input/action/binary/bundle·manifest/action schema와 이전 cleanup snapshot hash를 재확인했다. 새 manifest planned, apply/verify 미실행. Q-013에 exact plan 승인 질문을 등록한다.
- observed rehearsal: 새 같은 모델 독자가 수정 문서의 로컬3명령만 실행해 exit0/막힘0/도움말 불일치0이었다. Cloud/auth/Git 쓰기와 구현/credential/기존 artifacts 열람은 범위 밖이다. 로그 `/tmp/phase09-rehearsal.1e31Wf/`. 문서가 별도 설명 없이 로컬 단계까지 실행됨을 입증하며 Cloud E2E는 아니다.
- 경계: Phase08 bucket/소스·shared lib·원문은 변경하지 않았다. 원시 로그·plan/state·snapshot은 ignored이고 새 Cloud 생성·commit/push는 하지 않았다. 새 exact SHA 승인 후 해당 저장 plan apply와 즉시 verify로 진행한다.

## 2026-08-26 — Phase09 재생성 승인·실제 적용(D-035)

- confirmed: exact bundle SHA `bc763bc4bec0092bdbd0a1fd8efc3e564df8a2ed6c0952bb43762fce102fb7ab`의 apply·실제 검증 질문에 사용자가 “ㄱㄱㄱ”으로 승인했다. D-035를 기록하고 Q-013을 닫았다. 동일 승인·일반 쉘 실행은 다시 묻지 않는다.
- observed 16:37 KST: source/input/action/binary/bundle hash·planned 상태·create-only guard·manifest/action schema·현재 client /32 일치를 재확인한 후 저장 plan을 apply 중이다. session17815, 로그 `artifacts/phase-09-recreate-cloud-apply.log`. 아직 Cloud 생성·WordPress 성공을 판정하지 않는다. 추가 코드 수정/commit/push는 하지 않는다.
- observed 16:44 KST: apply exit0, Terraform16added/0changed/0destroyed와 Cloud identity 기록·SQL root 초기화가 완료됐다. manifest applied·root_password_initialized=true/password_persisted=false를 검사했고 즉시 machine verify를 session89979에서 시작했다. private VM startup 완료도 읽기 전용 확인했다. Python44/TF mock·gate 재검사는 모두 exit0이다. 아직 WordPress/SQL E2E 성공 판정은 아니다.
- observed: verifier는 proxy guest의 `stage=db-ready/reason=db-connect/exit_code31`로 실패했다. PHP/config lint 이후 DB readiness 단계이며 WordPress 설치·SQL marker·HTTP 실습 성공은 아니다. private/proxy startup과 proxy 서비스 로그는 ignored artifacts에 확보했으며 정확한 하위 원인 분석은 미완료다. 기존 EXIT trap이 자동 destroy를 시작했다.

## 2026-08-26 — 전체 삭제 대신 보존·진단·수정·재apply 원칙(D-036)

- confirmed: 사용자가 자동 전체 삭제는 비효율적이라며 진단 로그로 원인을 좁혀 해결하고 수정 Terraform을 apply하는 방향으로 ballast:pin을 요청했다. 복구 정책 불일치(진단·수정보다 전체 삭제를 기본 복구로 삼음)로 분류했다. D-036으로 향후 실패 자동 삭제를 대체하고 과거 승인·이미 수행된 삭제 기록은 보존한다.
- observed 16:53 KST: 정확한 run 경로/프로세스를 확인해 Terraform destroy PID292326에 SIGINT 한 번을 보냈다. 로그에 Interrupt received/Stopping operation이 기록됐고 session89979는 exit1, 관련 Terraform/부모 프로세스 종료를 확인했다. 추가 destroy는 시작하지 않았다. 이미 제출된 SQL 삭제는 중단 후 완료됐으며 별도 실제 VM/SQL list는 모두[]다. state에는 전용 network/range/connection3개와 유지 API3개가 남았다. ignored `artifacts/phase-09-recreate-stop-{sql,vms}.json`이 근거다. 새 백업·복구·재생성은 하지 않았다.
- pin 절차: 사용자에게 exact entry를 보여준 뒤 OK를 받아 catalog에 merge하는 스킬 단계에 따라 현재는 Q-015 확인 대기다. 프로젝트 catalog는 기존1개 규칙을 그대로 보존했다. AGENTS·shared adapter·Phase09 verify/support·config 등 실제 자동 삭제 경로는 아직 존재하며 수정/재apply 경로 이관을 Q-014에 등록했다. 변경 전 기존 apply/verify 실행 금지, 이전 cleanup 재시도도 금지다.

## 2026-08-26 — 보존·진단·수정 우선 규칙 pin 완료(D-037)

- confirmed: exact entry 영구 고정 질문에 사용자가 “ㅇㅇㅇ ㄱㄱ”으로 승인했다. 제시한 `terraform-repair-before-destroy`의 id/title/8개 keywords/body를 프로젝트 `.claude/ballast.rules.json`에 그대로 병합하고 기존 verifier 규칙을 보존했다. Q-015 closed.
- implemented: AGENTS의 실패 정리 지침을 D-036/D-037의 보존·진단·수정·변경 plan 승인·재apply로 동기화했다. 자동화 코드 수정 완료로 오해하지 않도록 Q-014 이관 전 기존 자동 삭제 경로 실행 금지를 명시했다. 실제 Terraform/Cloud/commit/push는 실행하지 않았다.
- observed: jq로 승인된 exact entry 일치·규칙2개·id 중복0을 검사했다. 설치된 ballast rule engine을 실제 프로젝트 cwd로 실행해 8개 키워드(대문자 TERRAFORM 포함)의 주입과 무관 문장의 새 규칙 미주입을 확인했다. BALLAST_NO_LOG=1로 테스트가 사용자 delivery 통계를 바꾸지 않게 했다. Bash 문법·Terraform fmt/validate·Phase09 gate(Python44)와 git diff check도 통과했다. 근거는 현재 catalog와 ignored `artifacts/phase-09-pin-{terraform-validate,gate}.log`다. 실제 Desktop의 다른 cwd까지 프로젝트 규칙이 전달된다고 확대하지 않는다.

## 2026-08-26 — Phase09 실패 보존·동일 state 복구 준비(D-038)

- confirmed: 사용자 “ㅇㅇ 다시 phase 9 생성도와줘”. 기존 저장 계정/project·Phase08 보존, 새 exact SHA 승인 경계와 추가 Git 게시 미승인은 유지한다.
- observed: 기존 Proxy 로그에 ADC 초기화·127.0.0.1:3306 listen·연결 수락 후 instance closed connection이 반복된다. SQL8.0·TLS 강제 없음이며 PHP CLI/mysqli가 설치돼 있다. 정확한 MySQL errno가 없어 하위 원인은 아직 모른다. 관련 진단/state/log는 보존하고 전체 destroy를 다시 실행하지 않았다.
- implemented: shared apply의 두 자동 삭제 분기를 우회하는 Phase09 전용 apply/실패 trap을 구현했다. apply/초기화/verify 실패는 failed/recovery.json 기록과 state·plan·로그 보존만 한다. read-only diagnose, 같은 state replan, 새 baseline+source/input/bundle SHA, 삭제/교체 거부, 승인 create+state 기록에 한한 재생성 identity 허용, 현재 apply receipt 확인을 연결했다. 기존 계획/승인 소스 메타데이터와 검증 시도는 archive하며 Terraform state를 복사/이동/삭제하지 않는다.
- implemented: guest DB errno 숫자 허용, run/hash 일치 managed config만 갱신, 기존 WordPress 설치 재사용·SQL marker upsert·동일 내용 probe만 회수, startup 전체 html 삭제 제거. 관리 밖/이전 버전 표식 없는 config는 자동 채택하지 않는다. 원인 해결·실제 PHP 성공은 주장하지 않는다.
- observed: Python58·Terraform validate/mock3/JSON guard2(복구 no-op 허용·삭제/교체 거부 포함)·Phase09 gate·Phase07–15 suite PASS. 격리 Bash에서 apply/초기화/verify/timeout/중단 code 보존과 no-destroy, plan/state/hash/Cloud identity drift 거부, managed config drift/symlink 거부·errno redaction·동일 run 재검증을 검사했다. `artifacts/phase-09-preserve-local-tests.log`, `phase-09-preserve-suite.log` 참조.
- observed rehearsal: 새 같은 모델 독자가 Phase09 문서만 전달받아 로컬3명령을 실제 실행해 모두 exit0, 막힘/추측/오독0. 37–39줄 검사 실행, 63–104줄의 exact SHA·보존 복구·명시적 destroy 경계 이해 확인. Cloud/login/plan/replan/apply/실제 verify/destroy/Git 쓰기와 수동 파일 편집 없음. 로컬 리허설 통과이지 Cloud E2E 증거가 아니다.
- observed 17:16 KST: diagnose는 VM/disk/SQL/subnet/firewall/SA0, 기존 VPC1/range1을 반환했다. replan은 이전 state로10create/6no-op, 변경/삭제/교체0. bundle SHA `3d8e72d72c34a5b2b97097490959b0ed9d4b2a55d42ddcdbb5020d170f9483e2`; state SHA `70c8146655a4f64b43b74a258fb7f7d589d4efc60fcd132e503d00f7865e52d6` 전후 동일. 계획 생성은 Cloud 변경이 아니다. Q-016 승인 대기, 추가 commit/push 없음. Phase08/shared lib/원문 변경0.

## 2026-08-26 — Phase09 승인 보존 복구 apply(D-039)

- confirmed: Q-016 exact bundle 제안에 사용자 “ㅇㅇ apply ㄱㄱ”. D-039에 저장 계획 apply·실제 검증과 비포함 경계를 기록하고 Q-016을 닫았다.
- observed 17:20 KST: 실행 소스는 그대로 두고 승인된 Phase09 apply를 session60283에서 시작했다. 실제 source/input/baseline/state/Cloud identity/binary SHA 검사와 preflight는 실행 스크립트가 강제한다. 로그 `artifacts/phase-09-preserve-cloud-apply.log`. 아직 생성·SQL/WordPress 성공을 판정하지 않으며 실패 시 보존·진단한다.
- observed 17:25 KST: apply exit0,10added/0changed/0destroyed·root API 초기화 완료. 기존6개는 계획대로 유지했다. 현재 bundle의 apply-completed receipt와 state SHA `0b745001ff3e0f4a9904773fe59d6b9afcb25e4da890dc3e9dffab7621b7cd1a`, manifest applied·root_password_initialized=true/password_persisted=false를 확인했다. 즉시 같은 run verifier를 session94183에서 시작했다. Python58/TF mock·validate/gate 재검사도 exit0이다. private VM serial에 logging.logEntries.create 거부 경고가 있었으나 PHP 설치 진행을 관측했고 이 경고를 DB 장애 원인으로 단정하거나 IAM을 임의 확장하지 않았다. 실제 WordPress/SQL E2E는 아직 진행 중이다.
- observed 17:30 KST: verify exit1, proxy stage=db-ready/reason=db-connect/exit31/mysql_errno1044. 전용 실패 경로에서 automatic_destroy=false/state_preserved=true, VM2 RUNNING·SQL1 RUNNABLE·disk2 등 기존 환경을 유지했다. 읽기 전용 SQL 진단은 양쪽 경로의 root@% 인증 성공·CURRENT_ROLE NONE·SHOW GRANTS USAGE만·wordpress DB 선택1044를 반환했다. Provider7.45.0 기본 root 삭제 소스와 기존 자동화의 사용자/역할 준비 누락을 확인했다. → recorded in memory/knowledge/gcp-sql-wordpress.md (2026-08-26).
- implemented 17:34 KST: SQL root가 없으면 insert, 있으면 update databaseRoles query로 cloudsqlsuperuser 추가·기존 역할 회수 없음으로 보완했다.1044 별도 privilege-denied 분류와 새 action-plan 역할 변경 명시·안전 검사6개를 추가했다. Python64/TF validate/mock3/JSON guard2 PASS(`artifacts/phase-09-root-role-local-tests.log`). 실제 역할 변경은 새 승인 전이다. 이전 승인 소스만 ignored tar에 보존했으며 state/DB 백업이나 전체 삭제는 하지 않았다.
- observed 17:37 KST: 같은 run/state의 새 replan을 session51419에서 시작했다. 로그 `artifacts/phase-09-root-role-replan.log`. 아직 새 계획 완료/승인/Cloud 권한 보완을 주장하지 않는다. Phase08/shared lib/원문·commit/push 변경 없음.
- observed 17:39 KST: replan exit0,16no-op/추가·변경·삭제·교체0, bundle SHA `7ce28fea77bfd9f4e1eb8076c848c489411a9494bed7208a4f7e44345d6d758d`. state SHA는 apply 직후0b745…와 동일하다. source/input/baseline/state/현재 Cloud identity/binary/action/bundle·schema·0600 읽기 전용 audit와 Phase07–15 suite도 exit0이었다. Q-017에 새 DB 관리자 역할 action+비밀번호 교체+실제 재검증 승인을 등록했다. 새 apply/DB 역할 변경은 하지 않았다.
- observed rehearsal: 새 한국어 Linux 사용자 페르소나에게 수정 문서 하나만 전달했다. 문서37–39줄 로컬3명령을 실제 실행해 모두 exit0(64tests/TF mock·validate/phase gate/help), 막힘·추측·오독0이었다.16no-op이어도 새 action SHA 승인이 필요하고 실패 보존·과금·별도 destroy 경계를 문서만으로 설명했다. Cloud/auth/Git 쓰기·실제 verify·소스/개인 설정/기존 artifacts 수동 열람 없음. 도구 실행 transcript가 증거이며 별도 원시 로그 파일은 생성하지 않았다. 로컬 리허설이지 Cloud 성공은 아니다.

## 2026-08-26 — Phase09 DB 권한 보완 승인·적용(D-040)

- confirmed: 사용자가 “리소스는 삭제하지말고 db 권한 보완 적용과 실제 동작 확인해줘”라고 명시했다. 제시된 Q-017 exact7ce28… SHA의 apply/권한 보완/실제 검증을 승인한 D-040을 기록하고 Q-017을 닫았다. 기존 계정/project·Phase08·리소스/state/로그 보존, 삭제·교체·추가 Git 게시 미승인은 유지한다.
- observed 17:49 KST: saved bundle SHA 일치·16no-op를 재확인하고 승인된 Phase09 apply를 session33615에서 시작했다. 소스/identity/state/계획 경계는 실행 코드가 강제한다. 로그 `artifacts/phase-09-root-role-cloud-apply.log`. 아직 실제 보완 성공을 판정하지 않는다. Bash/Python64·TF 정적/mock·Phase09 gate 재검사를 별도로 시작했다.
- observed 17:50 KST: Terraform0/0/0 완료 후 root 초기화 API가HTTP400으로 실패했다. operation UPDATE_USER/DONE/INTERNAL_ERROR 확인, audit 조회는 빈 결과라 세부 오류를 추정하지 않는다. 자동 삭제 없이 VM2/SQL1/disk2·identity 유지, 기존 guest 비밀번호로 양쪽 root 인증은 되지만USAGE/1044가 계속된다. 실제 WordPress verifier는 시작하지 않았다. approved64/TF/gate 재검사는 통과했다.
- implemented: 공식gcloud assign-roles 소스와 비교해 기존 root 요청의type 누락과 password 결합을 발견했다. BUILT_IN 명시·비밀번호 없는 역할 요청 완료 후 별도 비밀번호 갱신·공유600초deadline으로 수정했다. HTTP 오류는 고정 허용목록 category/status/reason으로만 기록한다. 테스트가 비밀 값의 password 단어로 인한 분류오류를 잡아 분류 전 비밀값 제거로 보완했다. 로컬70/TF 검사는 통과했고 새 same-state 최종 replan은session14022에서 준비 중이다. → recorded in memory/knowledge/gcp-sql-wordpress.md (2026-08-26). 코드 변경 후 기존 승인SHA 실행 금지, 삭제·교체·GCP IAM/방화벽·다른Phase 변경 없음.
- observed 17:57 KST: 최종 replan exit0,16no-op·bundle SHA `e701120a9f6d8ef03a5df23bf41f8d0e056d6238cd7d7ca3dee37ce14658e707`. state SHA d1e523…는 replan 전후 동일하다. 읽기 전용 source/input/baseline/state/Cloud identity/plan/action/bundle·schema·0600 audit와 Phase07–15 suite가 exit0이었다. Q-018 새 exact SHA 승인 질문을 작업 중 전달했으며 아직 새 승인은 없다. 분리 요청의 Cloud 적용·실제 SQL/WordPress verifier는 실행하지 않았다.
- observed rehearsal: 새 한국어 Linux 사용자 페르소나에게 수정 Phase09 문서만 전달해 로컬37–39줄 세 명령을 실행했다.70tests/TF validate·mock·guard/phase gate/help 모두exit0,막힘·추측·오독0. 기존계정 역할→비밀번호 순서·실패보존·새SHA 경계를 문서만으로 설명했다. Cloud/auth/Git 변경과 실제 E2E는 미수행이다. 도구 transcript를 근거로 기록하며 배포/commit/push는 하지 않았다.

## 2026-08-26 — Phase09 HTTP400 수정본 적용·실측(D-041)

- confirmed: 제시된 e701… 수정 계획 적용·검증 질문에 사용자가 “400 으로 실패하지 않게 해줘”라고 지시했다. D-041/Q-018에 현재 계획의 수정 실행 요청을 기록했다. 모든API오류가 영원히 없다는 보장이 아니라 현재 실패 경로의 실제 수정/검증이며 리소스 삭제 금지·동일계정/project·Phase08·Git 미게시 경계를 유지한다.
- observed 18:02 KST: saved bundle SHA·16no-op 재확인 후 같은 run apply를 session64463에서 시작했다. 로그 `artifacts/phase-09-separated-role-cloud-apply.log`. 아직 API/SQL/WordPress 성공을 판정하지 않으며 승인 소스는 수정하지 않는다.
- observed 18:02 KST: apply exit0,Terraform0/0/0·root역할/비밀번호API operation 성공. manifest applied·current bundle apply receipt/state SHA4b4cbe…·root_user_mode updated/requested_database_role cloudsqlsuperuser를 대조했다.400오류가 이번 적용에서 재발하지 않았다. 동일run 실제verifier를session15423에서시작했으며 로그는`artifacts/phase-09-separated-role-cloud-verify.log`다.70tests/TF validate/mock/gate 재검사도PASS. 아직전체SQL/WordPress 성공판정은하지않는다.
- observed 18:05 KST: 실제verifier exit0,양쪽guest complete/ok/0,ProxySQL marker 쓰기/private VM 직접SQL 읽기·두WordPress HTTP200/본문·양쪽SQL-backed probe·probe회수PASS. manifest verified/Task1–6 passed/command-code-result waiting_extension_review를대조했다. 리소스는유지하고 lab_completion.complete=false/destroy_pending=true는미정리상태로구분했다. Q-011의현재실패경로를해결상태로갱신했고옛400의단일원인·과거미보관errno까지확정하지않았다.
- observed 18:08 KST: 사후diagnose/read-only SQL/HTTP 재조회도통과했다. VM2 RUNNING·SQL1 RUNNABLE·disk2·baseline모든identity유지,두SQL연결의활성cloudsqlsuperuser/wordpress선택true/errno0,두frontendHTTP200을확인했다. `phase-09-separated-role-final-diagnosis.log`, `phase-09-separated-role-final-db.log`, `phase-09-separated-role-final-vms.json` 및run evidence가근거다. 기존단계미완료관측은knowledge/gcp-sql-wordpress.md의실제성공항목으로갱신했다.
- implemented: ballast:skill-forge와skill-creator 기준으로검증된Phase09복구순서를프로젝트 `.claude/skills/phase09-mysql-repair/SKILL.md`에저장하고quick_validate PASS. 로컬3명령·역할→비밀번호·새승인경계·실패보존·단일표본한계를명시했고전역설치/Cloud권한추가는하지않았다. 사용자안내서의현재상태도실제검증성공/리소스유지로수정했다.
- observed rehearsal 18:10–18:11 KST: 독립 독자 1차는 공통 로컬3명령 exit0(70tests/TF/gate/help), 복구 스킬의 권한 확장 중단 문구가 승인된 root 역할 보완까지 포함하는지 모호하다고 보고했다. 새 plan에서 승인받은 DB 역할 보완과 그 범위를 넘는 GCP IAM 등 권한 확장을 구분하도록 수정했다. 새 독자 2차도 같은3명령을 실제 실행해 모두 exit0, 로컬 실행의 차단/추측0·역할→비밀번호/새SHA 승인/검증과destroy 대기 구분을 확인했다. 두 회차 모두 Cloud/auth/Git 쓰기·실제 복구 재실행은 하지 않았다. 도구 transcript가 근거다. 비차단 관찰인 일부 문장 띄어쓰기와 수동 SQL 진단 명령 상세 부족은 남아 있으며 초심자용 독립 수동 복구 매뉴얼 완성을 주장하지 않는다.
- observed 18:11 KST: manifest의 verified/Task6개 passed, evidence의 destroy_pending=true, read-only DB 양쪽 errno0, baseline/diagnosis identity 일치, git diff --check 및 최종 skill validator를 다시 확인했다. checkpoint의 이전 진행 중 내용을 보관하고 실제 완료 상태로 갱신했다. 추가 Cloud 변경·재apply·commit/push는 하지 않았다.

## 2026-08-26 — Phase09 종료 정리와 Task별 콘솔 안내(D-042/D-043)

- confirmed: 사용자가 현재 Phase09 destroy와 각 Phase 완료 후 Task별 콘솔 확인법의 상시 안내·로컬/원격 커밋 반영을 요청했다. 현재 run만 정리하고 Phase08/이전 run 잔여는 유지한다. 복구 실패 자동 전체 삭제 금지는 그대로다.
- observed: 삭제 전 diagnose의 VM2/SQL1 등 identity를 확인하고 saved destroy plan `73fa2672048f1e6f30ce25a80d3b7952c49d069be1f8a2b238ca15fbcf67c30f`의16개 delete와 API 유지 설정을 검사했다. 표준 execute destroy는 소유권을 다시 검사해 실행했으며 SQL/VM/disk/subnet/firewall/SA를 제거했다. 이후 PSA producer 사용 중 Error9로 exit1/cleanup_required, state·로그 보존. 사후 diagnose의 해당 자원0·VPC1/범위1과 별도 PSA list의연결1을 확인했다. API3개와 Phase08 bucket 유지도 확인했다. 새 백업·강제 peering 삭제·state 제거·임의 재apply는 하지 않았다.
- implemented: 15개 Phase/원본90개 Task에 콘솔 경로·대상·통과 기준·한계/보조 evidence 표를 추가했다. 로컬 전용 console-checks.py, 8개 회귀 테스트, 공통 gate/Makefile 검사, Extension/단일 모델 완료 출력과 세 prompt·AGENTS/README를 연결했다. README/실행 prompt의 남은 자동 실패 정리 문구는 기존 D-036/D-037과 Q-014 실행 금지 경계로 맞췄고 실제 shared adapter/다른 Phase Cloud 코드는 변경하지 않았다.
- observed: 90개 coverage·8tests, Phase09 70tests/TF validate/mock/gate, controller·Phase01–06/07–15 offline suites PASS. 독립 한국어 초심자 페르소나의 문서 리허설도3명령 exit0/막힘0이고 Phase07 권한 회수, Phase08 CSEK 제거, Phase09 probe 회수/삭제 이후 구분을 설명했다. 도구 transcript가 근거이며 실제 Console 클릭·새 clone/Windows 실기는 미수행이다.
- pin: 자동 검증 결과만으로 사용자 확인 안내를 대신한 간극을 추가 완료 보고 계약으로 보완했다. exact `phase-task-console-check` 항목을 제시했으나 현재 사용자 확인은 없어 catalog 저장만 Q-019 대기다. 사용자 원문의 D-043은 문서·AGENTS에 반영했다.
- observed: dirty worktree를 보존하며 git fetch 후 HEAD와 origin/main의 ahead/behind0을 확인했다. 현재 관련 파일의 stage·commit·push 검사를 진행 중이며 비밀/state/원시 로그는 게시하지 않는다.
- observed 18:28 KST: 공개 대상75개 파일의 경로·새 추가 줄에 대한 개인 실행값/비밀 패턴 검사와 commit 전 Phase09 gate를 통과했다. 한국어 commit `eb9aad9f043ebd749e67c695c0e447755c2fafda`를 생성했다. HTTPS push는 credential helper 부재로 실패했지만, 기존 repo 전용 SSH alias로 같은 저장소에 일반 push했다. 무인증 HTTPS ls-remote의 main SHA 일치·fetch·pull --ff-only·clean tree를 확인했다. origin/global 설정·키 내용은 변경/열람하지 않았다. 근거는 ignored `artifacts/phase-09-console-{commit,push,push-ssh,pull}.log`와 Git 기록이다.
- observed: 사후 IAM 조회도 해당 run principal binding0이었다(`artifacts/phase-09-user-destroy-iam.json`). 전체 destroy는 PSA3개 때문에 여전히 미완료이며, 게시 성공을 Cloud 정리 완료로 혼동하지 않는다. checkpoint를 archive하고 이 게시 확인 기록을 별도 한국어 커밋으로 남긴다.

## 2026-08-26 — Task 하위 콘솔 안내·Phase10–15 보존형 구현(D-044)

- confirmed: 사용자가 원문 Task 아래 하위 항목까지 상세 콘솔 확인법과 Phase10–15 구현·오류 보완을 요청했다. 새 Cloud apply/destroy 또는 새 commit/push 승인을 추론하지 않았다.
- observed 시작20:20 KST: main5aa5749의 clean tree에서 pull --ff-only는 Already up to date였다. recall/decision/knowledge 자산과 원문을 대조했다. 대규모 원문 감사는 recall의 분담 지침으로 read-only 조사했고, 새 독자 리허설은 rehearsal 지침에 따라 독립 실행했다.
- implemented: Phase01–15의90개 Task에 원문 하위 제목167개·번호 절차를 연결한221개 상세 확인 항목을 추가했다. 클릭 경로·읽을 값·판정·한계/보조 증거를 적고 단일 Task 출력에 준비 안내를 포함했다. 원문은 수정하지 않았다. 최초177 집계는 Task 밖 제목 포함이라167로 정정했다.
- implemented: Phase10–15는 별도 safe adapter의 실패 보존·동일 run replan·새 정확한 SHA 승인·명시적 destroy plan을 사용한다. config/account/source/work/input/state 변경·일반 복구의 delete/replace를 차단한다. initial plan 실패·replan·apply·verify 시도 로그를 보존한다. 기존 Phase08/09·공통4개 승인 lib는 변경하지 않았다.
- implemented: BigQuery 구조화 jobs/전체 행 수/비용 상한, Monitoring INSTANCE/실제 checker IP·정확한 chart/group/조건·최근 uptime=true, VPN 단계/Cloud ID 재개와 선택 정리 상태, ALB builder 보존/지역별 health/부하 종료, ILB NAT 선행·실제 Client IP·HTTP 실패·전체 zone inventory, Terraform managed/data 구분을 보완했다. 컨트롤러는 선언된 manual-boundary만 허용하고 누락/실패는 거부한다.
- observed 최종20:58 KST:40개 회귀·13개 안내 검사·TF mock6개/fmt/init/validate·Phase10–15 gate·make test-offline·Phase09 기존70개 회귀가 모두exit0. 로그는 ignored artifacts/phase10-15-{local-tests,full-offline,gates}.log 및 phase09-regression-after-10-15.log다. git diff --check도 통과했고 원문/Phase08/09/기존공통4개lib diff0이다.
- observed rehearsal: 1차의 준비 안내·P10 필드·P09 상태·중복 검사 간극을 수정했다. 2차 새 독자는 로컬 명령·34문서/107개 링크·90Task/167원문제목/221안내 항목을 확인해 차단0·broken0이었다. 네 비차단 문구를 정정하고13개 안내 검사를 재실행했다. 실제 로그인/UI/Cloud/Git 쓰기는 하지 않았다.
- limits: 실제 Cloud 권한/quota/수렴·통신은 아직 미검증이며 원문 전체 수동 단계 완료를 주장하지 않는다. Phase13 reset/삭제·두번째 backend 방식·부하 위치, P10 전체 golden 비교 등의 차이는 docs/audits/phase-10-15-repair.md에 명시했다. 자동 비용 종료는 없다. Q-014는10–15 로컬 이관까지 partial, Q-021은 새 실기/차이 추적이다. Q-019 catalog 제안은 승인 없이 저장하지 않았다.
- preserved: 기존 Phase08·Phase09 PSA3개·이전 run/state·승인 소스에 Cloud 변경을 하지 않았다. 로컬 미커밋 변경이며 마지막 원격 게시5aa5749와 구분한다. 다음 실제 실행은 본인 계정/project 및 새 저장 plan 승인 경계부터 진행한다.

## 2026-08-26 — Phase10–15 게시와 실제 실행 준비(D-045)

- confirmed: 로컬 완료 보고 후 사용자가 “커밋 푸쉬하고 apply 해서 안되는 부분 확인하면서 수정해줘”라고 요청했다. 관련 변경 게시와 순차 실기 준비를 진행한다. D017 exact plan 승인, 실패 보존, 다른 run/Phase08/09 보호는 유지한다.
- observed: recall의 index/knowledge/decisions/catalog/skills/goal을 확인하고 GitHub SSH 게시 근거와 보존 규칙을 재사용했다. 현재 ACTIVE 계정·허용 프로젝트·ADC/billing preflight와 BigQuery/Compute/Monitoring/Logging/Storage 활성 API 조회가 통과했다. 개인 계정/설정은 ignored 경로에만 남겼다.
- observed:40개 회귀·13개 안내·TF mock6개/fmt/validate·Phase10–15 gate를 재통과했다.82개 staged 파일의 경로와 민감 패턴·diff check를 검사한 뒤 한국어 commit b67ce8c91542a9738870af80a19db1f8073392fc를 만들고 기존 repo 전용 SSH alias로 main에 일반 push했다. 원격 HTTPS SHA 일치·fetch·pull --ff-only·clean tree를 확인했다. 원격 설정/키 내용은 변경/열람하지 않았다.
- observed: 새로운 Phase10 run p10-260826-2106의 plan을 시작했다. 아직 apply·load/query·Cloud 리소스 변경은 하지 않았다. 로그 artifacts/phase10-initial-plan.log 및 phase-10-plan.*.log는0600/ignored 경로다.
- observed 21:11 KST: 최초 plan exit0, US BigQuery dataset1create·update/delete/replace0을 확인했다. binary/action/binding/manifest 해시와 source/work/input/config/account/state·소유권 guard·schema/0600 재검사도exit0이다. manifest planned/state absent, bundle da21cf4a35d39146664507e7b2545b07945f3389fb0a04a8d818a844c4efd5d9. 사용자에게 exact SHA·계정/project·fixture 적재/8쿼리·기존 삭제 없음·조건부 비용 추정을 제시하여 Q-022 승인 대기로 기록했다. 승인 전 Cloud 변경하지 않았다.
- estimate: 공식 BigQuery 온디맨드$6.25/TiB와 query8개×1GiB 상한으로 분석 비용은1회 약$0.04883이다. 저장/전송/예약용량/세금/재시도 비용은 별도이며 무료 잔여를 가정하지 않는다. table TTL1일과 전체 자동 destroy를 구분했다. PRODUCT-TRUTH에 출처·조건을 기록했다.
- checkpoint: ballast:checkpoint에 따라 기존21:05 상태를 archive하고 게시 완료·Q-022 승인 대기·정확한 재개 명령으로 갱신했다. 기존 Q-014/019/020/021을 완료 처리하지 않았다. 이 후속 증거 기록도 D-045 범위에서 검사·게시한다.

## 2026-08-26 — Phase10 승인 apply·Avro 스키마 오류 보완(D-046)

- confirmed: 사용자가직전exact da21cf4a35d39146664507e7b2545b07945f3389fb0a04a8d818a844c4efd5d9의apply/검증제안에“ㄱㄱ”으로승인했다. D-046을기록하고Q-022를닫았다. D-045게시요청·D017새SHA승인·D036/37실패보존을유지한다.
- observed 21:44 KST: clean tree에서FF pull Already up to date, 저장bundle일치를확인했다. 최초apply exit0·dataset1개생성·manifest applied/applied binding일치. 이어실제verify를실행했다. Bash/fmt/validate/Phase gate도통과했다(첫gate호출에는번호대신문서경로가필요해명령을정정했으며코드오류가아니다).
- observed 21:45–21:46 KST: load job DONE/415602행/badRecords0이지만schema검사에서verify exit1. 테이블의usage_start_time/usage_end_time/export_time은INTEGER, load job의useAvroLogicalTypes는생략됐다. 원본Avro의승인generation header64KiB를읽어세필드의timestamp-micros를확인했다. 공식변환문서의기본INTEGER/옵션true→TIMESTAMP와대조했다. query0, dataset/table/state/receipt/실패로그보존, 자동destroy없음. 진단근거는PRODUCT-TRUTH와knowledge/gcp-bigquery-avro.md.
- implemented: billing load에useAvroLogicalTypes=true, schema불일치필드/기대/실제상세, action plan에같은run table의WRITE_TRUNCATE(data/schema reload)/실패보존을명시했다. 원문/SQL8개/Phase08/09/shared4개lib변경없음. 신규회귀2개가실제POST옵션·대상/재적재방식·오류schema후query0을검사한다. 최초새test의evidence폴더fixture누락을수정후42개검사·TF mock1개/fmt/validate·Bash/gate PASS, 안내13개검사PASS.
- observed 21:49 KST: 같은run replan exit0,dataset1no-op/추가·변경·삭제·교체0. bundle eb50a9f987064e100984e7b79e2b9f552ade151eeba51451423f1d9784dbf106의source/work/input/config/account/state/hash/schema/0600검사PASS. state SHA2e1a4222d88e38937aaff5a595ad9e25d6e3623b11e357167a1083d7e263c529는전후동일. 과거plan/manifest를보존하고현재planned, Q-023새승인대기. 수정후Cloud재적재·쿼리성공은아직없다.
- observed rehearsal: ballast:rehearsal에따라새독자에게세개안내문서만주고Task2출력·전체coverage·안내13tests를실행하게했다. 세명령모두exit0/차단·추측0이며INTEGER실패, 보존대상과WRITE_TRUNCATE의data/schema갱신범위,새SHA승인을정확히구분했다. 도구transcript가근거이고실제Cloud/UI확인은아니다.

## 2026-08-26 — Phase15까지 재질문 없는 위임 실행(D-047)

- confirmed: 사용자가“나한테 물어보지말고 phase 15까지 전부 구현 apply해줘. 중간에 문제 생기면 수정 알아서 하고”라고명시하여이번작업의개별SHA재확인을범위위임으로대체했다. D047·AGENTS·실행안내·프로젝트한정pin을갱신했다. pin항목을먼저표시했고사용자의재질문금지지시에따라추가catalog질문없이반영했다. 범위밖/전체destroy보호는유지한다.
- observed: clean tree에서FF pull후Phase10 수정eb50…apply/verify모두exit0. dataset1no-op,415602행·시간3개TIMESTAMP·8query·Task1–5검사PASS,총billed bytes333MiB. 실제GET table로사후재확인했다. 리소스/state/과거실패증거보존. 상세는PRODUCT-TRUTH와run evidence.
- implemented: Phase11 사전API대조에서dashboard GET의잘못된v3경로를v1로분리했다. 공식dashboard GET문서와검사추가후43회귀·Phase11 gate/TF mock PASS. 현재Phase11실기전이다.
- estimate: 공식VM/VPN/NAT/LB요금과소형현재구성으로모든후속실습유지시대략시간당$0.5–1수준을안내했다. 데이터처리/전송/세금등은별도이며청구상한/무료를보장하지않는다. 각계획에서재확인한다.
- observed rehearsal: 새독자가D047예외문서/AGENTS/catalog만읽고현재작업한정·완료후승계없음·일반clone승인경계를정확히구분했다. Task2출력/전체coverage두명령exit0·차단/추측0. Cloud/auth/Git변경없음. 전체Cloud준비절차가아닌위임문구와로컬출력범위의리허설이다.
- observed 22:32 KST: Phase11 p11-260826-2224 초기12create계획 e364e9…는그룹필터HTTP400으로10개생성후실패. diagnose/state주소확인후metadata.user_labels접두어수정·Python45개/Phase11 TF/gate통과. 동일state fecc81639ab7b0344faf1ba0f8efc2a78968c610117d992c1dd447e6e8051507은10no-op/2create/삭제교체0이며D047검토후apply exit0, VM/Monitoring검증진행중이다. 전체destroy없음.
- implemented: Phase12onprem같은region다른활성zone자동선택·입력고정·Terraform validation과negative mock·선택회귀를추가했다. gate/mock2개통과. 새Phase12실기전관련변경을D045로게시하며공통승인lib/Phase08/09는보존한다.
- observed 22:36 KST: Phase11 CPU시계열400을aligned query누락으로분리진단했다. CPU60초ALIGN_MEAN·API단계명/수렴evidence추가후12no-op인3f5eb9…재apply/verify exit0. VM3 exact CPU/group·15uptime시계열최근true·alert true→false·Task1–7통과. 콘솔확인출력을읽고사용자에게Monitoring4개화면과상세링크를전달했다. 메일/UI/MCP/destroy는수행하지않았다.
- observed: 관련15파일을한국어commit d9d96696c4a8edfc58fca0286489e7453c7493e6로main에push·FF pull·당시clean tree확인. Phase12 p12-260826-2236 계획df554e1a7818c9f623b182bf31a399870a449e49070ac44276356b107ceadc9d은28create·기존변경삭제0, PSK비공개/VM외부IP없음·onprem다른zone·IAP/내부CIDR방화벽을확인해D047apply/verify시작했다.
- implemented: Phase13원문reset자동기동·RATE50/UTILIZATION80·세번째region customimage loadgen/NAT보완. 48회귀·TF mock2개/gate·안내13개PASS. 단일Phase13관리리소스상한25와MIG최대4VM·load360초는유지한다. builder는중지보존한다.
- observed rehearsal: Phase13새독자1차가원문min1/max2를축소라고잘못설명한부분과tfvars경로누락을발견했다. 주실행자원문직접대조후규모설명·경로/키·성공시제를정정했고2차새독자가5개로컬명령exit0·막힘/추측/오독0을보고했다. Cloud/UI/Git변경없음. 과거감사/기록의규모축소설명은현재정정으로대체한다.
- observed 22:42 KST: Phase12 apply28개/verify exit0,4터널baseline·BGP원격prefix·REGIONAL교차리전실패/GLOBAL성공·양방향ping·single-tunnel0삭제후양쪽리전ping통과. manifest verified/Task1–7/9passed/Task8manual-boundary. 실제남은3터널중양쪽tunnel1ESTABLISHED,onprem0FIRST_HANDSHAKE를읽기확인하고의도된장애상태·복원가능·전체정리미수행을사용자에게설명했다.
- observed: Phase13원문보완/문서리허설결과를a97d2cdd6b117763f7eec2095d65db4702c26d3e로main에push·FF pull·clean tree확인. 새run p13-260826-2243의bundle c643e6005afa686213955a2c4b064f586e210605e43b45f6d9bfad100b5b9693은25create/변경삭제0,원문backend모드·privateVM·세번째region NAT·MIG1–2·load360초를검토후D047apply/verify시작했다. 기존리소스확장권한이나전체destroy로해석하지않았다.
- observed: make test-offline은exit0(기존Phase09 70tests포함), Phase14/15사전gate·TF mock도각exit0이다. 실제Phase14/15Cloud는미실행으로구분한다.

## 2026-08-26 — Phase13 직렬 증거 보존 복구

- observed 22:52 KST: 초기 Terraform은25added/0changed/0destroyed 완료했지만 post-apply가 중지 builder의 직렬 로그를 읽어 실패했다. 실제 get-serial-port-output의 resource-not-ready와 공식 RUNNING 조회 제한을 대조했다. LB·image·MIG·state·실패 로그를 보존했다.
- implemented: wait-builder가 RUNNING 중 서로 다른 boot/Apache version/Cloud ID를0600 receipt로 저장한 뒤 stop한다. 기존 run은 정확한 ID/라벨/image sourceDisk를 검사해 동일 builder만 start/reset/capture/stop한다. recovered_after_image를 receipt에 저장하여 후속 no-op에서도 원본 제작시점 증거로 오인하지 않는다.49회귀 통과.
- observed 22:57 KST: 최종 재계획2fc9f4353a4e6021bf1427c23328f79a903ca4feff0cdb9438534a6fd34106a6은25no-op·resource 추가변경삭제교체0, builder ID output만 추가한다. 조건부 builder 복구·기존 bounded 부하 action/기존 계정·프로젝트/과금 유지 검토 후 D047 apply/verify를 시작했다. 중간225041… 계획은 미적용으로 보존했다. Phase14/15 실행 전이며 새 승인 질문은 필요하지 않다.
- observed: 중지 전 증거 보완의49회귀/Bash/fmt/init/validate/TF mock/전체10–15 suite와3차안내리허설4명령·13tests가exit0이었다.88cbe3909cb17382958fc1081af6aacf80877e03을main게시·원격SHA일치·clean FF pull한 뒤 Phase14/15 각각새plan을시작했다.
- observed: Phase13 복구 apply exit0·기존25개0/0/0, Apache2.4.68-1~deb12u1·서로다른2boot·중지beforeimage·receiptSHA·readiness_recovered_after_image=true를확인했다. 현재dual-region/backend/HTTP를거쳐bounded load/scale검증중이며전체완료는아니다.

## 2026-08-26 — Phase14/15 신규 배포

- implemented: Phase14 Apache가설치중이미시작된경우 a2enconf만으로새DirectoryIndex를반영하지못할수있는경로를배포전에발견했다. 공식Apache재기동/설정재읽기와Debian a2enconf링크생성계약을대조해configtest→enable→restart로보완하고50회귀·Phase14gate/TFmock을통과했다. 최초35b7de… 계획은미적용보존했다. Cloud에서해당오류가발생했다고주장하지않는다.
- observed: p14-260826-2300 최종eeb808c9bfb9416583df459758540f80adb41170f0915953e2eed92c26b71f1f는18create/기존변경삭제0. private e2-micro VM3·30GBdisk·NAT1·INTERNAL LB1·같은region다른zone2·IAP/내부/health ingress와VIP60HTTP action을검토해D047apply/verify를시작했다. 해당VM/disk/NAT/LB유지비용이있고자동종료없음.
- observed: p15-260826-2300의882a7abedca9495caed530c62820b1769d26dd40eab248afd9a4ddfff4df9427은4create/기존변경삭제0. 별도autoVPC/firewall·private e2-micro VM2·20GBdisk·두region과privateping/0변경재plan action을검토해D047apply/verify를시작했다. 기존계정/project·이전리소스보존·VM/disk유지비용을확인했다. Phase13scale검증대기와독립VPC배포를병행하며공유승인lib를변경하지않았다.
- observed: Phase15 apply4개/verify exit0·Task1–4passed·managed주소4·cross-region privateping·idempotency detailed-exitcode0을확인했다. 콘솔출력을읽고Task1CloudShell/2VPC·방화벽·VM/3상세대조/4로컬멱등성증거와하위안내를사용자에게전달했다. 리소스유지·destroy미수행.
- observed: Phase14는16개생성후backend 기본UTILIZATION 때문에400이었다. 공식INTERNAL passthrough CONNECTION계약과API응답을대조하여두backend를명시CONNECTION으로보완했다. TFmock은plan시unknown set문제를실제Cloud성공으로오인하지않고추가mock apply assertion으로해결했다. gate/TFmock2/회귀통과후6c7cae0382d52983abd4e1b322cd4710cef16f93df3c3f3c6e117b6f548f9555의16no-op/2create/삭제교체0을검토해동일run재apply했다.
- observed: Phase13부하unit이30초exit1로종료한것을journal로확인했다. 유한ab재현은43요청후timeout,단순curl/동시2는정상. NAT mapping64포트와OUT_OF_RESOURCES893드롭으로원인을좁혔다. 비어있는부하를기다리던기존verifier만TERM하여rc143/실패로그를보존했고Cloud리소스삭제없음.
- implemented: 부하NAT8192포트·ab keepalive/동시100/350초(systemd360초)·journal보존/조기종료검사/scale진행evidence/재시도baseline수렴대기추가.51회귀·Phase13gate/TFmock2통과. f5c0dead0e61b28ebb570ddc5cf35ad966f6dae41692cf67a7787d64098fc446은기존24no-op/NAT1update·추가삭제교체0이며기존VM/이미지/LB를유지한다. action/비용/대상을검토해D047재apply/verify시작. 부하전용NAT외수정없음,무제한ingress없음.
- observed: P13 NAT재apply0/1/0·P14 CONNECTION재apply2/0/0이성공했다. P13재시도provenance의recovered=true유지와NAT mapping8256(최소8192·이전매핑포함)을확인했고실제MIG2→3 scale-out을관측했다. scale-in은진행중이다.
- observed: P14검증의gcloud value(instance)가zone을출력해잘못된VM조회404였다. 같은명령의JSON URL은올바른VM이므로원시JSON/project/zone/run검사로수정했다. 추가utility 직접HTTP로두backend/VIP가Debian기본페이지를반환함을확인했고DirectoryIndex누적규칙과대조했다. 실패후18개모두보존했다.
- implemented: P14post-apply의정확한memberID/라벨확인후DirectoryIndex disabled→index.php/configtest/reload/localhost본문검사를추가했다. 기존immutabletemplate/VM/state를교체하지않고새run도동일수렴action을사용한다.54회귀·TFmock2·gate통과;코드보완전중간JSON수정계획은미적용보존하고최종18no-op계획을준비중이다.
- observed: 최종7652d55ede1f18bfe48de3a12939e0e440517ed509ac799ceec9fe62a8b5f79f/18no-op 및정확한VM두개Apache수렴action을D047검토·apply/verify해모두exit0이었다. Task1–5passed·양쪽healthy·direct HTTP·VIP60성공/정확한두marker/clientIP보존·VM외부IP0을확인하고Task별콘솔안내를전달했다. 실제리소스교체/삭제0.
- implemented: 성공후지속성검토에서기존startup이같은p14-index.conf를다시쓰는경로를발견했다. 별도후순위p14-php-index.conf로분리하여기존파일을수정하지않고재기동시에도설정이남도록보완했다.54회귀의반복수렴/기존파일보존·gate통과후새18no-op계획을준비한다. 실제VM재부팅시험을했다고주장하지않는다.
- observed 23:16 KST: 최종9af07dc9cf7fc3e9bf3294fc51d6576a4fb32065d349b96f25cec055bc467d30의18no-op/action범위·비용유지를검사하여D047 apply/verify exit0을확인했다. persistent_drop_in=p14-php-index.conf·소유backend2/configtest/localHTTP·Task1–5passed/VIP60/marker2/clientIP/외부IP0이통과했다. 현재source/work가저장binding과일치하며재부팅/전체destroy는수행하지않았다.

## 2026-08-26 — Phase10–15 최종 실기 완료·게시 준비

- observed 23:22 KST: Phase13 최종f5c0dead…apply/verify exit0, manifest verified/Task1–7passed. 최초확장관측3·별도snapshot4,부하23:09:50종료후목표합계2복귀. marker4/LB로그20·IPv4HTTP성공,IPv6HTTP는route부재로unavailable이다. 수동resize/전체destroy없이자동축소를관측했다. 당시MIG는각1target/자동삭제처리중이므로실제settled VM수는후속readback으로구분한다.
- observed: Phase14 최종문서fresh-reader가Task3/4/5출력·전체coverage·안내13tests의5명령exit0/차단0이었다. 별도persistent설정·CONNECTION·privateVIP·60응답/clientIP·verified와UI/cleanup/clone증거부재경계를문서에서찾았다. 전체onboarding/원문일치/Cloud/API/SSH/부하/Git/UI검증은아니다.
- observed: 최신코드54회귀/TFmock9/Bash/fmt/init/validate/각gate·make test-offline(Phase09기존70포함)exit0. 안내13tests와15Phase90Task167원문제목coverage도재통과했다. 로그artifacts/phase10-15-final-verified-{local-tests,full-offline}.log. 기존shared6lib/Phase08/09/원문은유지한다.
- static-gap: 요청받지않은Phase11종료inventory의dashboard list v3경로를발견해Q024로분리했다. 현재성공한별도v1apply/verify와다르며다음명시적destroy전에v1조회보완/새계획이필요하다. 현재전체destroy검증완료로과장하지않고기존binding을유지했다.
- record: Phase10–15 최신실기표·Task하위콘솔링크·실제/수동/정리경계를실행안내/감사/truth/Q021/goal/checkpoint에반영한다. D047는이번결과게시후종료하며새실행/cleanup을자동승계하지않는다. 비밀·개인설정·state·원시로그를제외한관련변경만D045한국어commit/push대상이다.
- observed 23:27–23:28 KST: 관련30파일의경로/추가행비밀패턴/diff를검사하고한국어commit 5f04475987115736401f356a5c3243de4a7893c2를main에일반push했다. HTTPS원격SHA일치·FF pull/clean tree확인. 게시후make test-offline도exit0(54/안내13/기존Phase09 70포함)이다. 최종5필드binding(source/work/input/config/account)와applied receipt는6개run모두일치했다. 최초직접dict전체비교는저장본의추가state필드때문에assert실패했으나Cloud나코드불일치가아니며필드별검사로정정했다.
- observed 23:28 KST: 양쪽MIG wait-until --stable exit0. 실제API target1/stabletrue/none1/deleting0씩,각리전backend HEALTHY1개와HTTP정상확인. settled-mig-readback/settled-backend-health.json에보존했다. 부하확장분2개VM은autoscaler가자동축소했고template/기존리소스/state는유지한다. 수동resize/전체destroy없음. 이최종관측·게시확인기록만후속문서커밋하며추가Cloud변경은없다.
