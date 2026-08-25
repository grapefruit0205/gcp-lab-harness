# Google Cloud 실습 자동화 하네스

공개 GitHub 저장소를 받아 한국어 Google Cloud 실습 15개를 Phase 단위로 계획·실행·검증·정리하는 프로젝트입니다. Windows는 WSL 없이 PowerShell과 Git for Windows Bash를 사용하고, Linux는 Bash를 사용합니다.

> 현재 상태: Foundation과 Phase 01–15 adapter 구현, Google provider schema와 전체 offline 계약 검증까지 완료했습니다. 개정 adapter의 실제 Google Cloud apply·machine evidence·전체 destroy E2E와 Windows 실기동은 아직 완료로 주장하지 않습니다.

저장소: [grapefruit0205/gcp-lab-harness](https://github.com/grapefruit0205/gcp-lab-harness) (public)

## 0. 가장 쉬운 시작: Windows Desktop에 링크와 프롬프트 붙여넣기

Codex Desktop의 Codex 작업 화면 또는 Claude Desktop의 Code 탭을 사용합니다. Claude의 일반 Chat 탭은 로컬 파일과 터미널을 실행하는 경로가 아닙니다.

1. 새 로컬 작업을 만들고 필요하면 `C:\Users\<사용자이름>`을 폴더로 선택합니다.
2. 아래 프롬프트 전체를 붙여넣습니다.
3. 모델이 요청하면 자신의 실습용 GCP 프로젝트 ID를 입력합니다.
4. 설치·Google 로그인·ADC 브라우저 승인은 사용자가 직접 완료합니다.
5. clone 뒤 앱이 폴더를 전환하지 못하면 `C:\Users\<사용자이름>\gcp-lab-harness`를 새 프로젝트로 엽니다.

```text
Windows 환경에서 다음 public GitHub 저장소로 Google Cloud 실습 하네스를 준비해줘.

저장소: https://github.com/grapefruit0205/gcp-lab-harness
로컬 경로: $HOME\gcp-lab-harness

다음 계약을 반드시 지켜줘.

1. 현재 GUI 세션에서 선택된 모델 하나만 사용한다. subagent, 멀티 모델,
   cmd/claude/codex CLI를 통한 다른 모델 호출은 사용하지 않는다.
2. WSL을 설치하거나 사용하지 않는다. Git for Windows, PowerShell, gcloud,
   Terraform, jq, ripgrep, Python 상태를 먼저 읽기 전용으로 확인한다.
3. 저장소가 없으면 위 주소를 $HOME\gcp-lab-harness에 clone한다.
   이미 있으면 사용자 변경을 보존하고 working tree가 clean할 때만 git pull --ff-only를 실행한다.
4. clone 후 저장소를 작업 폴더로 전환하고 AGENTS.md, README.md,
   memory/DECISIONS.md, memory/PRODUCT-TRUTH.md, memory/CHECKPOINT.md를 읽는다.
5. 내 GCP 프로젝트 ID를 물은 뒤 다음 PowerShell 명령으로 준비한다.
   powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 -ProjectId <GCP_PROJECT_ID>
6. 비밀번호, 토큰, 서비스 계정 key, Terraform state, binary plan과 원시 로그를
   채팅이나 Git에 기록하지 않는다.
7. UTC 현재 시각으로 lab-YYYYMMDD-HHMMSS 형식의 고유 RUN_ID를 만들고,
   .\harness.ps1 run init --run <RUN_ID> --mode cloud 로 pipeline을 초기화한다.
8. .\harness.ps1 doctor와 offline gate부터 실행하고 현재 Phase를 보고한다.
9. 현재 Phase의 execute.sh와 verify.sh만 별도 실행 질문 없이 사용할 수 있다.
   직접 gcloud, terraform, rm 전체를 포괄 허용하지 않는다.
10. apply 전에는 Terraform plan의 생성/변경/삭제 수와 plan-bundle SHA256을 보여주고 멈춘다.
    내가 그 SHA256을 명시적으로 승인하기 전에는 apply하지 않는다.
11. apply 뒤 machine verification과 읽기 전용 GCP 검증을 실행하고 evidence를 보여준 뒤 멈춘다.
    내가 "검증 승인"이라고 말하기 전에는 정상 리소스 cleanup, commit, push, 다음 Phase를 하지 않는다.
12. apply·post-apply 실패 시에는 manifest가 소유한 리소스만 자동 cleanup하고 잔여 0을 확인한다.
13. 검증 승인 후 현재 Phase 소유 리소스만 cleanup하고 잔여 0을 확인한다.
    그다음 한국어 commit과 push를 완료하고 다음 Phase의 plan 승인 대기에서 멈춘다.

지금은 외부 변경을 하지 말고 설치 상태와 저장소 상태를 확인한 다음 내 GCP 프로젝트 ID를 물어봐.
```

GUI가 네트워크·clone·파일·터미널 권한을 요청하면 저장소와 위 경로에 한해 승인합니다. `apply`, 정상 `destroy`, `commit`, `push`의 사용자 승인 지점은 유지합니다.

## 1. Windows Desktop에서 단일 GUI 모델로 실행

### Codex Desktop

1. Windows용 Codex Desktop에 로그인합니다.
2. clone 전에는 사용자 홈, clone 후에는 `C:\Users\<사용자이름>\gcp-lab-harness`를 엽니다.
3. Windows native 환경과 PowerShell을 사용합니다.
4. 위의 첫 프롬프트를 붙여넣습니다.

### Claude Desktop

1. Claude Desktop에 로그인하고 **Code** 탭을 엽니다.
2. Environment에서 **Local**을 선택합니다.
3. clone 전에는 사용자 홈, clone 후에는 저장소 폴더를 선택합니다.
4. 위의 첫 프롬프트를 붙여넣습니다.

### Phase마다 사용할 짧은 프롬프트

계획:

```text
현재 Phase를 같은 GUI 모델 하나로 진행해줘. 먼저 offline gate와 저장 plan까지만 만들고,
생성/변경/삭제 수와 plan-bundle SHA256을 보고한 뒤 멈춰.
```

plan 승인:

```text
plan-bundle SHA256 <SHA256>을 승인해. exact saved plan만 apply하고 machine verification과
읽기 전용 GCP 검증을 수행한 뒤 evidence를 보고하고 멈춰.
```

검증 승인:

```text
검증 승인. 현재 Phase 소유 리소스만 cleanup하고 잔여 리소스 0을 확인해.
그다음 한국어 메시지로 commit하고 push한 뒤 다음 Phase의 plan 승인 대기에서 멈춰.
```

같은 모델을 사용하더라도 구현 pass와 검증 pass를 분리하며 모델이 사용자 승인을 대신 추론하지 않습니다.

## 2. git clone 후 환경 준비

### Windows PowerShell

WSL은 필요하지 않습니다. `bootstrap.ps1`이 `winget`으로 Git for Windows, Google Cloud CLI, Terraform, jq, ripgrep, Python을 확인·설치하고 Git Bash 호환층으로 같은 Phase 스크립트를 실행합니다.

```powershell
git clone https://github.com/grapefruit0205/gcp-lab-harness.git "$HOME\gcp-lab-harness"
Set-Location "$HOME\gcp-lab-harness"
powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 -ProjectId <GCP_PROJECT_ID>
```

Windows의 `cmd.exe`와 Command Code CLI 이름이 충돌하면 실제 Command Code 실행 파일을 지정합니다.

```powershell
.\bootstrap.ps1 -ProjectId <GCP_PROJECT_ID> -CommandCodePath 'C:\path\to\command-code\cmd.exe'
```

Codex Desktop·Claude Desktop·VS Code만 사용하면 `CommandCodePath`는 생략할 수 있습니다. Windows wrapper는 코드와 정적 계약이 연결됐지만 실제 Windows 호스트 검증은 남아 있습니다.

### Linux Bash

```bash
git clone https://github.com/grapefruit0205/gcp-lab-harness.git "$HOME/gcp-lab-harness"
bash "$HOME/gcp-lab-harness/bootstrap.sh" <GCP_PROJECT_ID>
export PATH="$HOME/.local/bin:$PATH"
```

bootstrap은 GCP 사용자 로그인·ADC, exact project allowlist, billing preflight와 Terraform provider 연결을 준비합니다. 인증정보와 로컬 project·billing 값은 Git에서 제외됩니다.

## 3. Windows VS Code에서 Codex 또는 Claude로 실행

PowerShell에서 저장소를 열고 VS Code Extension 하나를 선택합니다.

```powershell
winget install --id Microsoft.VisualStudioCode -e
Set-Location "$HOME\gcp-lab-harness"
code .
```

- Codex: VS Code Codex Extension에 로그인하고 Codex Sidebar를 엽니다.
- Claude: Claude Code Extension에 로그인하고 패널을 엽니다.

선택한 Extension에 다음 프롬프트를 전달합니다.

```text
현재 열린 gcp-lab-harness를 Windows native PowerShell 환경에서 운영해줘. WSL은 사용하지 마.
AGENTS.md, README.md, memory/DECISIONS.md, PRODUCT-TRUTH.md와 CHECKPOINT.md를 먼저 읽어.
이 Extension에서 선택된 모델 하나만 사용하고 subagent나 다른 모델 CLI를 호출하지 마.
현재 Phase의 offline gate와 저장 plan까지만 만들고 생성/변경/삭제 수와 plan-bundle SHA256을 보고해.
내가 plan hash를 승인하면 exact saved plan만 apply하고 실제 상태 machine verification을 수행해.
evidence를 보고한 뒤 멈추고, 내가 "검증 승인"이라고 말한 경우에만 cleanup, 잔여 0 확인,
한국어 commit, push, 다음 Phase plan 순서로 진행해. key, credential, state, raw plan은 Git에 넣지 마.
```

Codex와 Claude 중 하나만 선택하면 단일 GUI 모델 경로입니다. 자동 review handoff는 VS Code Codex Extension에 연결돼 있으며 Claude Extension에서는 같은 계약을 수동으로 수행합니다.

## 4. Command Code 실행 + VS Code Codex Extension 검증

현재 Command Code 계정에 고정된 모델을 사용하며 `--model`이나 `--effort`를 전달하지 않습니다.

Linux:

```bash
gcp-lab-harness run-all --run lab-20260825-01
```

Windows:

```powershell
.\harness.ps1 run-all --run lab-20260825-01
```

열린 Command Code 세션에는 다음처럼 지시합니다.

```text
현재 Phase를 확인하고 offline gate와 저장 plan까지만 만들어줘.
생성·변경·삭제 수와 plan-bundle SHA256을 보여준 뒤 내 승인을 기다려.
승인 후 exact plan apply와 machine verification을 완료하면 VS Code Codex Extension으로 handoff해줘.
```

Phase 07 이상에서 review 입력은 binary plan이 아니라 exact `plan-bundle.json`입니다.

```bash
gcp-lab-harness handoff review --run <RUN_ID> \
  --plan artifacts/runs/<RUN_ID>/phase-<NN>/plan-bundle.json \
  --evidence artifacts/runs/<RUN_ID>/phase-<NN>/manifest.json
```

plan-bundle은 Terraform binary plan hash와 imperative action-plan hash를 묶습니다. binary plan은 apply 직후 삭제하며 Extension에는 민감 mask가 적용된 plan JSON과 evidence index만 전달합니다.

사용자가 Extension 결과를 승인한 뒤 같은 Command Code 세션을 재개합니다.

```bash
gcp-lab-harness handoff next --run <RUN_ID>
```

```powershell
.\harness.ps1 handoff next --run <RUN_ID>
```

반려하면 findings가 같은 세션으로 돌아가며 다음 Phase로 넘어가지 않습니다.

## 5. Command Code 고정 모델 단독 실행

같은 Command Code 고정 모델 하나로 구현 pass와 자기 검증 pass를 순서대로 수행할 수 있습니다. 사용자 plan 승인과 최종 검증 승인은 유지됩니다.

```powershell
.\harness.ps1 single-model run --run lab-20260825-01
.\harness.ps1 single-model run --run lab-20260825-01 --confirm-plan-sha <PLAN_BUNDLE_SHA256>
.\harness.ps1 single-model approve --run lab-20260825-01
.\harness.ps1 handoff next --run lab-20260825-01
```

Linux에서는 같은 하위 명령을 `gcp-lab-harness`로 실행합니다. 권한 설정은 Phase 01–15의 `execute.sh`·`verify.sh`만 허용하며 전체 command auto-accept를 사용하지 않습니다.

## Phase별 추가 입력

다음 값은 자격 증명이나 서비스 계정 key가 아닙니다.

- Phase 03: 외부 ICMP 검증 source CIDR과 기존 `default` VPC 보존 확인
- Phase 06: Minecraft client source CIDR, HTTPS artifact URL·SHA-256, 정확한 JRE version, EULA 동의
- Phase 09: HTTP client source CIDR, WordPress·Cloud SQL Auth Proxy·WP-CLI HTTPS URL·SHA-256
- Phase 11: Monitoring·Logging MCP endpoint 등록과 OAuth 연결

## 설계 원칙

- 모든 Phase는 `plan -> apply -> verify -> destroy` 순서를 따릅니다.
- exact project allowlist, saved plan, 사용자 hash 승인, 수량·timeout·cleanup 보호 없이 apply하지 않습니다.
- Terraform 밖 mutation은 action-plan에 기록하고 Terraform plan과 plan-bundle hash로 결합합니다.
- 리소스 존재나 명령 종료 코드만으로 완료하지 않고 guest·network·data·metric·log 실제 상태를 검증합니다.
- 실패 시 manifest가 증명하는 소유 리소스만 정리하며 이름을 추측해 삭제하지 않습니다.
- Phase 시작 전 `git pull --ff-only`, 승인·cleanup 뒤 한국어 commit과 push를 사용합니다.
- raw artifact, state, credential, key, 개인 식별자와 binary plan은 Git에 넣지 않습니다.

## 저장소 안내

- [Phase 목록](docs/phases/README.md)
- [하네스 아키텍처](docs/architecture.md)
- [실행·검증·Git 워크플로](docs/workflow.md)
- [15-Phase 오케스트레이션](docs/orchestration.md)
- [Monitoring·Logging MCP 연동](docs/mcp-integration.md)
- [원본 실습 자동화 매핑](docs/source-map.md)
- [Phase 01–06 누락 감사와 반영](docs/audits/phase-01-06-coverage.md)
- [Phase 07–15 누락 감사와 반영](docs/audits/phase-07-15-coverage.md)
- `references/google-cloud-labs-ko/`: 한국어 실습 보존본
- `phases/`: Phase 01–15 Terraform·execute·verify adapter
- `artifacts/runs/`: Git에서 제외된 runtime state와 evidence

## 선택: Foundation canary

실제 create/destroy 권한만 작게 확인하려면 단일 custom-mode VPC canary를 사용합니다.

```bash
"$HOME/gcp-lab-harness/scripts/foundation-canary.sh" plan --run canary001
"$HOME/gcp-lab-harness/scripts/foundation-canary.sh" apply --run canary001 --confirm-plan-sha <PLAN_SHA256>
"$HOME/gcp-lab-harness/scripts/foundation-canary.sh" verify --run canary001
"$HOME/gcp-lab-harness/scripts/foundation-canary.sh" destroy --run canary001
```

예산 한도는 필수 설정이 아닙니다. exact project allowlist, 결제 연결, 리소스 상한, apply timeout과 cleanup 보호는 유지합니다.

개발자용 최소 점검:

```bash
gcp-lab-harness doctor
"$HOME/gcp-lab-harness/scripts/validate-design.sh"
make -C "$HOME/gcp-lab-harness" test-offline
```

## 다음 단계

새 run ID로 Phase 01 saved plan을 만들고 사용자 승인, Cloud machine verification, Extension 또는 단일 모델 review, destroy와 잔여 0을 Phase별로 수행해야 합니다. Cloud 실행 없이 tunnel 수렴, autoscaling, uptime metric, SQL·BigQuery 데이터 경로 성공을 주장하지 않습니다.
