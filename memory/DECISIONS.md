# DECISIONS — append-only ledger

Rules: only user-confirmed decisions are recorded. Nothing is edited or deleted. A changed decision gets a **new** entry that `supersedes D-xxx`, and the old entry receives exactly one added line: `→ superseded by D-yyy (date)`. Sequential ids, never reused. (Full protocol: ballast decision-ledger skill.)

---

## D-001 · Adopt the ballast memory structure — 2026-08-25 (user, project setup)

This project uses `memory/` as its durable brain: decisions in this ledger, unresolved items in OPEN-QUESTIONS, per-session notes in SESSION-LOG. Standing decisions are followed without relitigating; changes go through the supersede protocol.

<!-- Append new entries below. Example of a superseded pair:

## D-002 · Weekly report goes out Fridays — 2026-01-10 (user, chat)

→ superseded by D-005 (2026-02-01)

## D-005 · Weekly report moves to Mondays — 2026-02-01 (user, chat)

Supersedes D-002. Fridays kept slipping into the weekend; Monday forces the week to start closed-loop.
-->

## D-002 · Google Cloud 실습 자동화 하네스를 만든다 — 2026-08-25 (사용자, 설계 요청)

기존 Google Cloud 한국어 실습 15개를 계정에서 CLI로 실행하고 검증하는 자동화 도구를 만든다. 설계와 구현은 Phase로 나누며, 각 Phase는 독립된 Markdown 문서를 가진다.

## D-003 · Ubuntu Bash 실행과 Codex 검증을 분리한다 — 2026-08-25 (사용자, 실행 방식 지정)

→ superseded by D-005 (2026-08-25)

구현·실행은 Ubuntu Bash에서 Codex CLI로 handoff하고, 검증은 VS Code의 Codex CLI/IDE 환경에서 수행한다. 실행과 검증은 GUI가 아니라 CLI를 기준으로 한다.

## D-004 · Phase 완료마다 한국어 Git 이력을 남긴다 — 2026-08-25 (사용자, 형상관리 방식 지정)

각 Phase가 완료될 때마다 한국어 커밋 메시지로 커밋하고 GitHub 저장소에 푸시한다.

## D-005 · 검증자는 VS Code Codex Extension이다 — 2026-08-25 (사용자, 실행 환경 정정)

→ superseded by D-007 (2026-08-25)

Supersedes D-003. 구현·실행은 Ubuntu Bash의 Codex CLI로 handoff하고, 독립 검증은 현재 사용 중인 VS Code Codex Extension에서 수행한다. `codex review` CLI는 재현 가능한 보조 정적 gate로만 사용한다.

## D-006 · Google Cloud 계정 연동을 포함한다 — 2026-08-25 (사용자, 계정 연동 확인)

하네스 실행과 검증을 위해 실습용 Google Cloud 계정·프로젝트를 연동한다. 인증과 권한은 Phase 00에서 별도 검증하며 비밀 키를 저장소에 넣지 않는다.

## D-007 · 검증은 VS Code Codex Extension에서 수행한다 — 2026-08-25 (사용자, 검증 경로 재확인)

→ superseded by D-009 (2026-08-25)

Supersedes D-005. Ubuntu Bash의 Codex CLI는 구현·실행 handoff를 담당하고, 검증자는 VS Code Codex Extension이다. 별도의 `codex review` CLI를 검증 흐름에 포함하지 않으며, Extension이 저장소의 정적·통합 검증 명령을 실행하고 diff와 evidence를 판정한다.

## D-008 · 한 번의 실행으로 Lab 01–15를 승인 게이트와 함께 순차 진행한다 — 2026-08-25 (사용자, 오케스트레이션 방식 지정)

→ superseded by D-009 (2026-08-25)

단일 `run-all` 스크립트가 원본 Lab 01–15를 각각 독립 실행 Phase로 순차 처리한다. 각 Phase 완료 시 `code` CLI가 사용자의 VS Code와 Codex Extension에 검증을 handoff하고, 사용자가 Extension에서 검증 완료를 명시적으로 승인하면 정리·한국어 commit·push를 수행한 뒤 다음 Phase로 자동 진행한다. 실행 상태는 영속화하여 중단 후 resume할 수 있어야 한다.

## D-009 · Command Code `cmd`로 실행하고 VS Code Codex Extension으로 검증한다 — 2026-08-25 (사용자, 도구·모델·승인 흐름 정정)

Supersedes D-007 and D-008. Ubuntu Bash의 실행 오케스트레이터는 사용자의 Command Code 계정으로 인증된 `cmd` 명령이다. `cmd`에 `--model`이나 `--effort`를 전달하지 않고 현재 계정에 고정된 모델을 상속한다. 단일 run이 Lab 01–15를 순차 실행하며, 각 Lab은 VS Code Codex Extension에서 사용자가 검증 완료를 명시적으로 승인한 뒤 cleanup·한국어 commit·push를 거쳐 다음 Lab으로 자동 진행한다.

sweep: README, 아키텍처, 워크플로, 오케스트레이션, Foundation, Phase 01–15, prompt, schema, 실행·검증 스크립트에 반영함 (2026-08-25)

## D-010 · GitHub 저장소 생성과 pull 동기화를 포함한다 — 2026-08-25 (사용자, Git 워크플로 추가 요청)

프로젝트를 GitHub 원격 저장소로 만들고 로컬 변경을 커밋하며, Phase 작업 흐름에 원격 변경을 가져오는 pull 단계도 포함한다. 각 Phase는 최신 원격 기준에서 시작하고 완료 후 커밋·push한다.

sweep: AGENTS, README, Makefile, controller dry-run, Git sync script, 아키텍처, 워크플로, 오케스트레이션, Foundation, Phase 목록, Command Code prompt에 반영함 (2026-08-25) → Q-001

## D-011 · GitHub 원격은 `grapefruit0205/gcp-lab-harness` private 저장소다 — 2026-08-25 (AI-proposed, user-confirmed)

→ superseded by D-015 (2026-08-25)

사용자는 앞서 제안한 저장소 이름 `gcp-lab-harness`와 private 공개 범위로 원격 저장소를 생성하는 것을 승인했다. GitHub 계정 `grapefruit0205` 아래 빈 저장소로 생성하고 로컬 `main`을 연결한다.

sweep: GitHub private 저장소 생성, repo 전용 Read/write deploy key, origin/main push, SHA 대조, fast-forward-only pull 및 README·Foundation 상태에 반영함 (2026-08-25)

## D-012 · 예산 한도 없이 GCP 계정 연동과 Cloud apply를 진행한다 — 2026-08-25 (사용자, Foundation A 구현 요청)

사용자는 별도 예산 한도를 정하지 않아도 되며, GCP 계정을 하네스에 연동해 실제 Cloud apply를 수행하는 것이 목적이라고 확정했다. 예산 값은 필수 gate에서 제거하되 프로젝트 allowlist, 저장된 plan 승인, 리소스 수 제한, 실행 시간 제한과 cleanup 보호는 유지한다.

sweep: README, Foundation A, 아키텍처, goal, config 예시, preflight, checkpoint와 open question에서 예산 필수 조건을 제거하고 대체 보호를 반영함 (2026-08-25)

## D-013 · `kdt5-05`에서 canary Cloud apply를 단계적으로 진행한다 — 2026-08-25 (AI-proposed, user-confirmed)

사용자는 연동된 `kdt5-05` 프로젝트에서 Terraform canary를 plan, apply, verify, destroy 순서로 진행하고 1단계 완료 시 보고하도록 승인했다. 각 외부 변경은 저장 plan과 승인 hash에 묶고 cleanup 후 활성 잔여 리소스를 확인한다.

## D-014 · git clone 기반 실행법을 원격 README에 남긴다 — 2026-08-25 (사용자, 배포·실행 문서 요청)

다른 사용자가 GitHub 저장소를 `git clone`으로 받은 뒤 스크립트만으로 설치·인증·프로젝트 설정·검증·실행할 수 있도록 README에 순서와 명령을 기록하고, 변경을 커밋·push한 뒤 pull로 원격 동기화를 검증한다.

## D-015 · GitHub 저장소를 public으로 전환한다 — 2026-08-25 (사용자, 공개 전환 요청)

Supersedes D-011. `grapefruit0205/gcp-lab-harness`의 코드와 커밋 이력을 누구나 열람·clone할 수 있도록 GitHub 저장소 공개 범위를 public으로 전환한다. 인증정보, 로컬 GCP 설정과 실행 artifact는 계속 Git에서 제외한다.

sweep: GitHub 공개 전환, README clone 안내, workflow, product truth, checkpoint와 open question에 반영함 (2026-08-25)

## D-016 · clone 후 Bash 또는 PowerShell에서 대화형 handoff 흐름을 시작한다 — 2026-08-25 (사용자, 실행 진입점 정정)

→ superseded by D-019 (2026-08-25)

사용자는 임의의 `/path/to/...`로 이동해 개발용 `make` 명령을 실행하는 방식 대신, GitHub 저장소를 `$HOME`에 clone한 뒤 root script 하나로 GCP 로그인과 Terraform 연결을 구성하도록 정했다. 이후 Bash에서 Command Code `cmd` 대화형 세션을 열어 자연어로 Phase를 구현하고, 구현 완료 시 VS Code Codex Extension으로 검증 handoff하며, 사용자 승인 후 같은 Command Code session으로 handoff해 cleanup·한국어 commit·push·다음 Phase를 계속한다. Windows PowerShell은 WSL의 동일 Bash 하네스를 호출하는 wrapper를 제공한다.

sweep: README, Bash·PowerShell bootstrap, 사용자 명령 installer, Command Code start, Extension review, next handoff, CLI usage, workflow와 orchestration에 반영함 (2026-08-25)

## D-017 · 같은 고정 모델의 구현·검증 경로와 Phase 쉘 자동 승인을 제공한다 — 2026-08-25 (사용자, 선택 실행 모드 요청)

기본 Command Code 구현·VS Code Codex Extension 검증 경로는 유지하되, 사용자가 선택하면 현재 Command Code 계정의 같은 고정 모델 하나가 한 Phase의 구현과 자기 검증을 연속 수행할 수 있게 한다. 한 Phase session에서는 저장소가 소유한 `.sh` 실행을 다시 묻지 않도록 자동 승인 모드를 사용한다. 모델·effort override는 금지하며, 저장 plan SHA 사용자 승인, project allowlist, cleanup 소유권, 최종 사용자 승인과 push gate는 생략하지 않는다.

sweep: CLI, single-model prompt·schema·실행·검증·승인 스크립트, Command Code start·next handoff, README, workflow, orchestration과 validation에 반영함 (2026-08-25)

## D-018 · Windows에서 GitHub 주소로 시작하는 GUI 안내를 README 최상단에 둔다 — 2026-08-25 (사용자, 공개 사용법 요청)

Windows 사용자가 `https://github.com/grapefruit0205/gcp-lab-harness`를 Claude Desktop 또는 Codex Desktop에 붙여넣고 시작할 수 있도록 README의 첫 사용법을 구성한다. 이어서 단일 GUI 모델 실행법, VS Code의 Claude Code 또는 Codex Extension 실행법 순서로 설명하며, 수동 clone이 필요할 때도 같은 공개 저장소 주소와 `$HOME\gcp-lab-harness` 경로를 사용한다. 기존 Command Code 실행·VS Code Codex 검증 경로는 별도 고급 경로로 유지한다.

sweep: README 최상단 링크+공용 프롬프트, Windows Desktop 단일 GUI 모델, PowerShell clone, VS Code Claude/Codex, 기존 Command Code 경로 순서로 반영함 (2026-08-25)

## D-019 · Windows는 WSL 없이 PowerShell에서 동일 하네스를 실행한다 — 2026-08-25 (사용자, Windows 실행 환경 정정)

Supersedes D-016. `$HOME` clone, 자연어 Command Code 실행, Extension handoff, 사용자 승인 뒤 cleanup·한국어 commit·push·다음 Phase 진행은 유지한다. Linux는 Bash를 사용하고 Windows는 WSL을 요구하지 않으며, PowerShell entrypoint가 Git for Windows의 Bash 호환층을 내부적으로 호출해 같은 adapter와 상태 머신을 사용한다.

sweep: `bootstrap.ps1`, `harness.ps1`, `scripts/bootstrap-windows.sh`, portable pipeline lock, README, workflow, orchestration, product truth에 반영함 (2026-08-25)

## D-020 · Phase 06 Minecraft 게임 포트를 공개하고 Terraform·Git에 반영한다 — 2026-08-26 (사용자, 접속 제한 해제 요청)

→ Minecraft 보존 방침에 한해 superseded by D-028 (2026-08-26)

사용자 요청: “제한 서버 옵션 풀어서 반영하여 테라폼, 커밋, 푸쉬까지 반영해줘 그리고 다시 apply 해줘.” 후속으로 TCP 25565의 접속 IP 허용을 재요청했다. Phase 06 Minecraft TCP 25565의 source를 전체 IPv4 `0.0.0.0/0`으로 전환한다. SSH IAP 제한, 비공개 backup bucket, 기존 VM·data disk·월드·고정 IP와 다른 Phase의 공개 제한은 유지한다. 해당 변경과 필요한 검증을 Terraform·코드에 반영하고 한국어 commit·push 및 기존 run의 재적용을 수행한다. 기존 source CIDR 제한을 해제하는 예외는 Minecraft 게임 포트에만 적용한다.

sweep: Phase 06 Terraform·execute·verify, 공통 network policy, Phase 01–06 offline 예외 검사, Python·Terraform mock 회귀 테스트와 Phase 06 문서에 반영함 (2026-08-26). 실제 저장 plan 재적용은 D-017의 exact SHA 승인 후 수행한다.

## D-021 · Phase 07 exact plan apply와 IAM 실습 검증을 승인한다 — 2026-08-26 (AI-proposed, user-confirmed)

사용자는 Phase 07 bundle SHA `cbadfcca92660a44a40653665e8ad1bc35cb61895b5699eb1467b0908ddd095e`를 제시한 “이 plan으로 apply와 IAM 실습 검증까지 진행해도 될까요?”라는 질문에 “ㅇㅇ”로 승인했다. 허용 project `kdt5-05`, run `p07-260826-72bd`의 Terraform 신규 12개와 해당 action plan의 임시 IAM 전이·private VM 검증을 수행한다. 임시 grant는 검증 종료 시 회수하고, 실패 시 해당 run 소유 리소스만 자동 cleanup한다. 기존 Phase 06 서버는 보존한다. Phase 07 최종 destroy·commit·push 승인을 포함하지 않는다.

## D-022 · Resource Manager API를 포함한 Phase 07 수정 plan 재apply를 승인한다 — 2026-08-26 (AI-proposed, user-confirmed)

사용자는 수정 bundle SHA `78871cff6b5edfe12fb965d5f8c032595a52d4bc1c933318adc32fe366c70837`를 제시한 “이 plan으로 재apply와 IAM 검증을 진행할까요?”라는 질문에 “ㄱㄱ”로 승인했다. project `kdt5-05`, run `p07-260826-e6a1`의 Terraform 신규 13개와 고정된 action plan의 IAM 전이·private VM 검증을 수행한다. Resource Manager API는 활성화하고 cleanup 후에도 유지한다. 임시 IAM 권한은 검증 종료 시 회수하며 실패 시 해당 run 소유 리소스만 cleanup한다. 기존 Phase 06 서버 변경, 성공 후 최종 destroy, commit·push는 포함하지 않는다. D-021의 이전 run은 정리 완료된 별도 거래로 보존한다.

## D-023 · 비동기 VM 판정을 보완한 Phase 07 plan 적용·검증을 승인한다 — 2026-08-26 (AI-proposed, user-confirmed)

사용자는 bundle SHA `85a107f4f0bd2bbf4ab084d3babb563cc74d15dafb1b2aacdb8c8b1f70e89653`를 제시한 “이 plan으로 재apply와 IAM 검증을 진행할까요?”라는 질문에 “ㅇㅇ”로 승인했다. project `kdt5-05`, run `p07-260826-a9d2`의 Terraform 13개 create와 고정된 action plan의 IAM 전이·비동기 VM 최종 결과·guest 검증을 수행한다. 검증 종료 시 임시 IAM을 회수하며 실패 시 해당 run 소유 리소스만 cleanup한다. 공용 Resource Manager API는 cleanup 후에도 유지한다. Phase 06 서버 변경, 성공 후 최종 destroy, commit·push는 포함하지 않는다.

## D-024 · Phase 07은 원문대로 실제 사용자 두 계정으로 자동화한다 — 2026-08-26 (사용자, 대체 구현 수정 요청)

사용자는 “원문대로 진행할 수 있도록 자동화 구현 수정해줘”라고 요청하고 계정 2의 Google 사용자 이메일을 지정했다. 계정 1은 현재 로그인된 사용자, 계정 2는 사용자가 제공한 별도 사용자로 구성한다. 실제 사용자 두 개의 인증과 프로젝트 수준 Viewer 회수·Storage Object Viewer 부여를 검증하며 SA 가장 두 개를 사용자 로그인 완료로 대체하지 않는다. VM에는 별도 workload SA를 연결한다. 이메일은 ignored 로컬 설정에만 기록한다. 임의의 Google 계정 생성이나 가상 교육 도메인에 대한 실제 권한 부여는 하지 않는다. 구현 변경 후 실제 IAM 변경/apply는 두 계정 인증 확인 및 새 saved plan 승인 뒤 수행한다. D-023의 기존 실행과 cleanup은 역사적 거래로 보존한다.

## D-025 · 각 사용자가 자신의 계정을 추가하는 준비 흐름을 자동화한다 — 2026-08-26 (사용자, 요구사항 명확화)

사용자는 수동 실습 초기 상태만 준비하자는 제안을 거절하고 “각자 계정을 추가할 수 있도록 너가 자동화 해줘야지”라고 요청했다. D-024의 실제 두 사용자 실습은 유지하되 사용하는 사람이 자신의 관리자·실습 계정을 입력/추가하고 각 계정의 Google 브라우저 인증으로 연결할 수 있게 한다. 특정 개인 이메일에 의존하거나 JSON 수동 편집만 안내하는 것으로 완료하지 않는다. 로그인은 사용자가 직접 승인하며 비밀번호·인증 코드를 대신 수집하지 않는다. 이 요청은 새로운 Cloud plan 승인이나 commit·push 승인이 아니다.

## D-026 · Notion 본문을 기준으로 Phase 07 재수정·커밋·푸시·apply를 요청한다 — 2026-08-26 (사용자, 기준 문서 지정과 실행 요청)

→ 기존 실습 유지·Phase 07 새 apply 대기에 한해 superseded by D-028 (2026-08-26)

사용자는 자신의 Notion `07. Exploring IAM` 페이지를 지정하고 “이거 확인해서 phase 07 재수정 커밋 푸쉬 apply 전부 부탁해”라고 요청했다. 현재 본문의 실제 계정 A/B 흐름을 기준으로 재대조하고 관련 구현·검증·문서를 수정해 커밋과 푸시를 수행한다. Notion Task 6은 B에게 workload-only Service Account User와 project Compute Instance Admin을 임시 부여한 뒤 B가 VM을 생성하며, Task 7은 Creator 전환 후 업로드 성공뿐 아니라 기존 객체 읽기 거부도 요구한다. 이전 User1 생성 대체 경로를 이 요구의 충족으로 주장하지 않는다. 계정 인증과 새로운 exact saved plan 승인 gate는 유지하고, Notion 페이지 자체는 읽기 전용이다. 기존 Minecraft와 다른 사용자 변경은 보존한다.

## D-027 · clone한 사람의 계정으로 준비하고 원 사용자 계정에 고정하지 않는다 — 2026-08-26 (사용자, 재사용 요구 재확인)

사용자는 다른 사람도 GitHub를 clone해 사용할 수 있으므로 로그인 단계를 자신의 계정에 고정하면 안 된다고 명시했다. 배포 코드·예시 설정에는 특정 개인 계정이나 프로젝트를 로그인 기본값으로 넣지 않는다. clone한 사람이 자신의 실제 User1/User2를 입력하고, 최초 User1 제안값은 그 환경의 현재 gcloud 사용자에서만 얻는다. 개인 이메일·프로젝트 설정·자격 증명은 Git에 포함하지 않는다. 이미 승인된 실행의 계정은 해당 실행의 saved inputs로 고정하며 새 사용자로 바꾸려면 새 준비/plan을 만든다.

## D-028 · Phase 8 준비를 위해 이전 실습을 백업 없이 전부 정리한다 — 2026-08-26 (사용자, 명시적 삭제 요청)

사용자는 Phase 6 destroy가 Minecraft 서버·월드 디스크·기존 백업 버킷·고정 IP를 삭제한다는 설명 후 “백업 하지말고 전부 destroy 해줘.”라고 지시했다. D-020/D-026의 기존 Minecraft 보존 방침을 이번 정리에 한해 대체한다. 허용 프로젝트의 이전 하네스 실습에 소유권이 확인되는 리소스와 임시 IAM을 모두 정리하고 새 백업/스냅샷은 만들지 않는다. GCP 프로젝트·결제 연결·사용자 로그인·공통 API와 실습 밖 기존 리소스는 유지한다. Phase 07의 미적용 plan은 이번 정리로 apply하지 않으며, 이후 재개하려면 새 계획을 검토한다. 저장된 삭제 계획과 실제 inventory로 범위를 검사하고 삭제 후 잔여를 재조회한다. 이 요청은 새 실습 apply나 Git commit/push 승인이 아니다.

sweep: 현행 checkpoint·실행 로그의 Minecraft 유지/Phase 07 apply 대기를 이번 정리 상태로 갱신한다. 과거 증거·archive와 실습 코드는 역사/재실행용으로 보존한다 (2026-08-26).

## D-029 · 남겨둔 관리 밖 5개도 백업 없이 삭제한다 — 2026-08-26 (사용자, 대상 목록 확인 후 추가 삭제 승인)

사용자는 `junseok-lab` bucket, `mynet-us-vm-us-central1-a-20260825000711-ynklv6qi` snapshot, `lampstack`·`read-bucket-objects` 서비스 계정, `privatenet-allow-ssh` firewall의 삭제 여부 질문에 “전부 삭제해 ㅇㅇ”라고 명시했다. Q-008의 5개를 이전 실습 정리 대상으로 확정하고, bucket 내용/버전과 두 서비스 계정에 연결된 프로젝트 IAM 부여도 정확한 principal/role 범위에서 회수한다. 새 백업/스냅샷은 만들지 않는다. 프로젝트·결제·사용자 로그인·기본 네트워크/기본 방화벽·공통 서비스 계정/API는 계속 유지한다. 실제 식별자를 재확인하고 저장된 cleanup action plan과 사후 inventory로 검증한다. Git commit/push 또는 새 Phase apply 승인은 아니다.

## D-030 · Phase 08 저장 plan 적용·실습 검증·관련 변경 게시를 승인한다 — 2026-08-26 (AI-proposed, user-confirmed)

→ 실패 시 자동 전체 삭제 방침의 향후 적용에 한해 superseded by D-036 (2026-08-26)

사용자는 bundle SHA `6d8a5c88f64c982508ff900f80aa632810a300d69f4b8fb302741154369499a3`를 제시한 “이 계획으로 apply·실습 검증 후 관련 변경을 스테이징·커밋·푸시할까요?”에 “ㅇㅇ”로 승인했다. run `p08-260826-8c1d`의 새 region bucket 1개와 고정된 action plan을 적용한다. fixture 하나의 임시 공개·즉시 회수, 새 bucket soft-delete=0, CSEK 암호화 전체 세대 삭제, 실패 시 해당 run 자동 cleanup을 포함한다. 관련 코드·테스트·문서·기록을 검사 후 stage·한국어 commit·push한다. 기존 다른 Cloud 리소스 변경과 정상 종료 후 전체 bucket destroy는 포함하지 않는다. A-004를 확정하며 같은 exact plan 승인은 반복 질문하지 않는다.

## D-031 · Phase 08 비정형 오류 처리 수정 plan 재적용·실습 검증을 승인한다 — 2026-08-26 (AI-proposed, user-confirmed)

→ 실패 시 자동 전체 삭제 방침의 향후 적용에 한해 superseded by D-036 (2026-08-26)

사용자는 bundle SHA `1222d79e290b309f117390ff457b5da1aa2577fef1a30bec32aa770ef575450a`를 제시한 “이 계획으로 재apply·실습 검증 진행할까요?”에 “ㅇㅇ”로 승인했다. run `p08-260826-c924`의 새 region bucket 1개와 고정된 action plan을 적용·검증한다. fixture의 임시 공개·즉시 회수, soft-delete=0, CSEK 암호화 전체 세대 삭제와 실패 시 run 자동 cleanup을 포함한다. 정상 성공 후 전체 bucket destroy나 다른 Cloud 리소스 변경은 포함하지 않는다. Q-009를 해결하며 이전 D-030 실행·실패 정리와 Git 게시 결과는 역사적 기록으로 유지한다.

## D-032 · Phase 08 검증 기록 게시와 Phase 09 실행을 요청한다 — 2026-08-26 (사용자, 후속 Phase 진행)

사용자는 “커밋 푸쉬 하고 phase 9 실행해줘”라고 요청했다. 로컬의 Phase 08 실제 검증 성공 기록·문서 상태를 검사해 stage·한국어 commit·push하고 Phase 09 실행 준비·검증·새 저장 계획을 진행한다. Phase 09 실제 Cloud 변경은 D-017의 새 exact plan SHA 승인 경계를 유지한다. Phase 08의 성공 run bucket 삭제는 이번 요청에 포함되지 않으며 그대로 보존한다. 비밀·state·원시 실행 로그를 게시하지 않는다.

## D-033 · Phase 09 저장 계획 apply·SQL/WordPress 실습 검증을 승인한다 — 2026-08-26 (AI-proposed, user-confirmed)

→ 실패 시 자동 전체 삭제 방침의 향후 적용에 한해 superseded by D-036 (2026-08-26)

사용자는 bundle SHA `d418a5b7ed219126889882f2e1e296b1e34dcea26b256dc329774119fb561cf4`와 SQL1/VM2 등 신규16개·client /32·유료/자동 삭제 없음·API3개 유지·PSA 정리 최대4일 지연을 제시한 “이 계획으로 apply·실습 검증 진행할까요?”에 “ㄱ”으로 진행을 승인했다. 허용 프로젝트의 run `p09-260826-5d82` 저장 plan과 결합 action plan을 적용·검증하고 실패하면 해당 run 소유 리소스만 자동 cleanup한다. Q-010을 해결한다. 정상 성공 후 전체 destroy, Phase08 bucket 변경, 추가 commit·push 승인은 포함하지 않는다.

## D-034 · 실패한 Phase09를 새 run으로 재생성한다 — 2026-08-26 (사용자, 재생성 요청)

실행 계정·프로젝트와 실패 후 VM/SQL 삭제·PSA 정리 지연을 보고받은 사용자가 “새로 생성 부탁해”라고 요청했다. 계정 전환 지시는 없으며 같은 준비 환경에서 실패 원인/진단을 보완하고 새로운 고유 run의 계획을 준비한다. 기존 승인 run의 정리 소스·state와 Phase08 리소스는 보존한다. 새 exact plan SHA 승인 경계는 D-017대로 유지하며 이 요청을 추가 Git 게시 승인으로 확대하지 않는다.

## D-035 · Phase09 재생성 exact plan 적용·실제 검증을 승인한다 — 2026-08-26 (AI-proposed, user-confirmed)

→ 실패 시 자동 전체 삭제 방침의 향후 적용에 한해 superseded by D-036 (2026-08-26)

사용자는 Q-013의 run `p09-260826-eb03`, bundle SHA `bc763bc4bec0092bdbd0a1fd8efc3e564df8a2ed6c0952bb43762fce102fb7ab`와 SQL1/VM2를 포함한16개 생성·과금·이전 네트워크 정리 대기·Phase08 보존을 제시한 “이 계획으로 apply와 실제 검증까지 진행할까요?”에 “ㄱㄱㄱ”으로 승인했다. 저장된 계획과 보완된 guest 진단/DB readiness·SQL/WordPress 검증을 실행하고 실패하면 해당 run 소유 리소스만 정리한다. 정상 성공 후 전체 destroy, Phase08 변경, 추가 commit/push는 이번 승인에 포함하지 않는다. Q-013을 해결하고 같은 exact 계획 승인을 반복 질문하지 않는다.

## D-036 · 실패 시 전체 삭제 대신 진단·수정·재apply를 기본으로 한다 — 2026-08-26 (사용자, 복구 방식 정정)

Supersedes D-030/D-031/D-033/D-035의 실패 시 자동 전체 삭제 방침을 앞으로의 실행에 한해 대체한다. 사용자는 “앞으로 실패했다고 전부 지우는 것은 비효율적이니 그렇게 하지말고 실패한 부분 진단 로그로 원인 좁히고 해결하여 재반영한 테라폼 을 apply 하는 방향으로 … 고정해줘”라고 지시했다. 실패한 환경·Terraform state·진단 증거를 보존하고 원인을 좁혀 수정 후 변경 계획을 확인하여 재적용한다. 이전 실행에 실제 수행된 삭제 이력은 바꾸지 않으며, 이번 지시 이후 실패만을 이유로 전체 destroy를 재개하지 않는다. 새 계획 승인·소유권·비밀 보호 경계는 유지한다. ballast:pin 규칙안은 사용자에게 보여준 뒤 확인을 받아 프로젝트 catalog에 넣는다.

sweep: 진행 중인 새 run destroy에 정상 중단 신호를 보냈고 checkpoint의 자동 cleanup 재시도 지시를 폐기했다. AGENTS/Phase09/shared adapter/config/schema/tests/docs/prompt의 자동 destroy 및 새 run 강제 정책은 아직 변경하지 않았고, 적용 위치 조사·복구 경로 이관을 Q-014에 등록했다. 규칙 catalog 저장은 Q-015 확인 대기다 (2026-08-26) → Q-014, Q-015

## D-037 · 보존·진단·수정 우선 복구 규칙을 프로젝트에 pin한다 — 2026-08-26 (AI-proposed, user-confirmed)

사용자는 표시된 `terraform-repair-before-destroy` entry를 프로젝트에 영구 고정할지 묻는 질문에 “ㅇㅇㅇ ㄱㄱ”으로 승인했다. 제시한 id/title/8개 keywords/body를 그대로 `.claude/ballast.rules.json`에 병합하고 기존 규칙은 보존한다. D-036 복구 원칙을 AGENTS에도 일치시킨다. 이번 승인은 규칙 저장이며 Cloud apply/destroy나 commit/push를 새로 승인하는 것이 아니다.

sweep: 프로젝트 catalog에 정확한 entry를 저장하고 AGENTS의 실패 전체 정리 지침을 보존·진단·수정·재apply로 바꿨다. Q-015를 닫았다. 실제 adapter/Phase09/config/schema/tests/docs/prompt의 복구 코드 이관은 여전히 Q-014이며 변경 전 기존 자동 삭제 경로는 실행하지 않는다 (2026-08-26) → Q-014

## D-038 · 보존 복구 방식으로 Phase09 재생성을 준비한다 — 2026-08-26 (사용자, 후속 생성 요청)

사용자는 보존·진단·수정 우선 규칙 pin 후 “ㅇㅇ 다시 phase 9 생성도와줘”라고 요청했다. Phase09의 실제 자동 삭제 경로를 제거하고 잔여 리소스·state를 확인해 재사용하는 변경 계획을 준비한다. 실패 로그로 원인을 좁히고 진단·동일 state 재계획/재검증 경로를 보완한다. 기존 계정·프로젝트와 Phase08 보존은 유지하고 실제 Cloud 변경은 새 exact plan 승인 뒤 수행한다. 전체 destroy·추가 Git 게시 승인은 아니다.

sweep: Phase09 전용 실패 보존/diagnose/replan/재검증 구현·오프라인58/TF/gate/suite 통과. 기존 run의 state를 그대로 쓰는 새 plan은10create/6no-op, 삭제·교체0이며 Q-016 새 exact SHA 승인 대기다. shared lib/Phase08/원문 소스는 유지했다. 다른 Phase 이관은 Q-014에 남겨 둔다 (2026-08-26).

## D-039 · Phase09 보존 복구 exact plan apply·실제 검증을 승인한다 — 2026-08-26 (AI-proposed, user-confirmed)

사용자는 Q-016의 bundle SHA `3d8e72d72c34a5b2b97097490959b0ed9d4b2a55d42ddcdbb5020d170f9483e2`, 기존 run `p09-260826-eb03`의10create/6no-op·삭제/교체0·기존 계정/project·실패 보존·Phase08 유지·과금을 제시한 “이 계획으로 비용이 발생하는 apply와 실제 검증까지 진행할까요?”에 “ㅇㅇ apply ㄱㄱ”으로 승인했다. 저장 계획을 적용하고 즉시 실제 SQL/WordPress 검증을 수행한다. 실패하면 리소스/state/로그를 보존하고 진단하며, 코드/계획 변경 시 새 exact SHA 승인 경계는 유지한다. 자동 destroy·Phase08 변경·추가 commit/push 승인은 아니다. Q-016을 닫고 같은 승인·일반 쉘 실행은 반복 질문하지 않는다.

## D-040 · 리소스를 유지한 Phase09 DB 권한 보완 적용·실제 검증을 승인한다 — 2026-08-26 (AI-proposed, user-confirmed)

사용자는 Q-017의 새 bundle SHA `7ce28fea77bfd9f4e1eb8076c848c489411a9494bed7208a4f7e44345d6d758d`, 기존16개 Terraform no-op·실습 root DB 관리자 역할 추가·비밀번호 갱신·재검증 제안 및 승인 대기 상태 설명 후 “리소스는 삭제하지말고 db 권한 보완 적용과 실제 동작 확인해줘”라고 명시했다. 같은 run `p09-260826-eb03`의 저장 계획과 root@% cloudsqlsuperuser 역할 추가(기존 역할 회수 없음)·난수 비밀번호 갱신·SQL/WordPress 두 경로 실제 검증을 실행한다. 기존 계정/project·Phase08과 리소스/state/로그를 유지하고 실패해도 삭제하지 않는다. Q-017을 닫으며 같은 승인·일반 쉘 실행을 다시 묻지 않는다. 리소스 삭제/교체·다른 Phase 변경·추가 commit/push 승인은 포함하지 않는다.

## D-041 · HTTP400 보완 계획 적용과 실제 확인을 진행한다 — 2026-08-26 (AI-proposed, user-confirmed)

Q-018의 bundle SHA `e701120a9f6d8ef03a5df23bf41f8d0e056d6238cd7d7ca3dee37ce14658e707`·기존16개 유지·역할/비밀번호 분리 요청을 제시한 “이 계획으로 권한 보완을 재적용하고 실제 검증까지 진행할까요?”에 사용자가 “400 으로 실패하지 않게 해줘”라고 수정 실행을 요청했다. 직전의 리소스 삭제 금지·DB 권한 보완 적용·실제 동작 확인 요청을 이어, 같은 run `p09-260826-eb03`의 제시된 수정 계획을 실행하고 API 응답 및 실제 SQL/WordPress 결과로 확인한다. 이를 임의의 다른 권한/계정/프로젝트 확장이나 삭제·교체·Git 게시 승인으로 확대하지 않는다. 모든HTTP400이 발생하지 않는다는 보장이 아니라, 현재 실패 경로를 수정·실측하는 요청이다. Q-018을 닫고 동일 계획의 승인·일반 쉘 실행을 반복 질문하지 않는다.

## D-042 · 완료한 Phase09를 명시적으로 종료 정리한다 — 2026-08-26 (사용자, destroy 요청)

Phase09의 실제 검증 성공과 리소스 유지·과금을 보고받은 사용자가 “destroy 해줘.”라고 요청했다. 현재 run `p09-260826-eb03`의 소유권이 확인된 SQL·WordPress VM/디스크·전용 IAM·네트워크를 삭제한다. 이는 정상 실습 종료이며 실패 시 자동 전체 삭제 금지(D-036/D-037)는 유지한다. 새 백업을 만들지 않고 기존 state·검증 증거·진단 로그는 보존한다. Phase08 bucket과 이전 별도 run의 PSA 잔여·공통 API·프로젝트·사용자 로그인은 삭제 대상이 아니다. PSA producer 해제가 지연되면 원인과 정확한 잔여를 기록하고 강제 peering 삭제/state 제거로 완료를 가장하지 않는다.

## D-043 · Phase별 Task 콘솔 확인 안내와 관련 변경을 Git에 반영한다 — 2026-08-26 (사용자, 완료 보고 방식 지정)

사용자는 “각 phase 별 완료 후에 task 별로 콘솔에서 완료를 확인하는 법을 항상 알려줬으면 좋겠어. 그걸 로컬과 원격 커밋에 반영하고 싶어”라고 요청했다. 각 Phase의 완료 보고·안내서에 Task별 Google Cloud Console 경로·확인 대상·통과 기준을 제공하고, 콘솔만으로 판정할 수 없는 데이터 경로·과거 전이는 그 한계와 보조 증거를 구분한다. 관련 Phase09 수정·검증/정리 기록과 이 안내 변경을 검사해 stage·한국어 commit·push하고 원격 SHA를 확인한다. 비밀·개인 실행 설정·Terraform state·원시 로그는 제외한다. ballast catalog entry는 제시한 정확한 항목에 대한 확인을 받은 뒤 저장한다.
