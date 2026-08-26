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
