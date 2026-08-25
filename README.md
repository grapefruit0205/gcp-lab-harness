# Google Cloud 실습 자동화 하네스

Windows에서 공개 GitHub 저장소를 받아 Google Cloud 실습을 Phase 단위로 계획·실행·검증·정리하기 위한 프로젝트입니다.

> **현재 구현 상태**: Foundation과 Terraform canary의 저장 plan까지 검증됐습니다. Windows PowerShell→WSL wrapper는 코드가 연결된 상태이며 실제 Windows 실행은 아직 검증되지 않았습니다. Lab 01–15 전체 Cloud 자동 실행 adapter도 아직 완성되지 않았으므로, 현재 없는 Phase 기능을 완료된 것으로 간주하거나 한 번에 전부 apply하면 안 됩니다.

공개 저장소 주소:

```text
https://github.com/grapefruit0205/gcp-lab-harness
```

## 가장 쉬운 시작: Windows Desktop에 링크와 프롬프트 붙여넣기

아래 방법은 **Codex Desktop의 Codex 작업 화면** 또는 **Claude Desktop의 Code 탭**에서 사용합니다. Claude의 일반 Chat 탭은 로컬 파일과 터미널을 실행하는 용도가 아니므로 반드시 Code 탭을 선택합니다.

1. Codex Desktop 또는 Claude Desktop을 실행하고 로그인합니다.
2. 새 로컬 작업을 만듭니다. 폴더 선택을 먼저 요구하면 Windows 사용자 홈인 `C:\Users\<사용자이름>`을 선택합니다.
3. 아래 프롬프트를 통째로 복사해 붙여넣습니다.
4. 모델이 GCP 프로젝트 ID를 물으면 **자신의 실습용 프로젝트 ID**를 입력합니다.
5. Windows 관리자 권한, 재부팅 또는 Google 브라우저 로그인이 필요하면 사용자가 직접 완료합니다.

clone이 끝났는데 GUI가 작업 폴더를 자동으로 바꾸지 못하면 새 Local/Project 작업을 열고 `C:\Users\<사용자이름>\gcp-lab-harness`를 선택한 뒤 같은 대화를 계속합니다.

### 처음 한 번 붙여넣을 프롬프트

```text
Windows 환경에서 다음 public GitHub 저장소로 Google Cloud 실습 하네스를 준비해줘.

저장소: https://github.com/grapefruit0205/gcp-lab-harness
로컬 경로: $HOME\gcp-lab-harness

다음 계약을 반드시 지켜줘.

1. 현재 GUI 세션에서 선택된 모델 하나만 사용한다. subagent, 멀티 모델,
   cmd/claude/codex CLI를 통한 다른 모델 호출은 사용하지 않는다.
2. 먼저 Git for Windows, WSL2, Ubuntu 설치 상태를 읽기 전용으로 확인한다.
   설치나 재부팅이 필요하면 정확한 PowerShell 명령을 보여주고 내가 완료할 때까지 기다린다.
3. 저장소가 없으면 위 주소를 $HOME\gcp-lab-harness에 clone한다.
   이미 있으면 사용자 변경을 보존하고, working tree가 clean할 때만 git pull --ff-only를 실행한다.
4. clone 후 $HOME\gcp-lab-harness를 작업 폴더로 전환한다. GUI가 폴더를 자동 전환할 수 없으면
   내가 새 Local/Project 작업에서 해당 폴더를 선택하도록 안내하고 기다린다.
5. 저장소에서 AGENTS.md, README.md, memory/DECISIONS.md,
   memory/PRODUCT-TRUTH.md, memory/CHECKPOINT.md를 먼저 읽는다.
6. 내 GCP 프로젝트 ID를 물어본다. 받은 뒤 Windows PowerShell에서 다음 형식으로 준비한다.
   powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 -ProjectId <GCP_PROJECT_ID>
7. Google 로그인 또는 ADC 브라우저 승인은 내가 직접 할 수 있도록 기다린다.
   비밀번호, 토큰, Terraform state와 원시 로그를 채팅이나 Git에 기록하지 않는다.
8. UTC 현재 시각으로 lab-YYYYMMDD-HHMMSS 형식의 고유 RUN_ID를 만들고 보고한다.
   기존 run과 겹치지 않는지 확인한 뒤 다음 형식으로 cloud mode pipeline을 초기화한다.
   .\harness.ps1 run init --run <RUN_ID> --mode cloud
9. .\harness.ps1 doctor와 읽기 전용 preflight부터 실행하고 현재 구현 상태와 현재 Phase를 보고한다.
10. 같은 GUI 모델이 현재 Phase의 구현과 검증을 순서대로 수행한다.
   저장소 소유의 정확한 phases/<NN>/run.sh와 verify.sh 실행은 Phase 동안 다시 묻지 않아도 된다.
   그러나 Cloud apply, destroy, commit, push 승인은 자동화하지 않는다.
11. apply 전에는 저장된 Terraform plan의 생성/변경/삭제 수와 SHA256을 보여주고 멈춘다.
   내가 그 SHA256을 명시적으로 승인하기 전에는 apply하지 않는다.
12. apply 뒤 machine verification과 읽기 전용 GCP 검증을 수행하고 evidence 위치를 보여준 뒤
    다시 멈춘다. 내가 "검증 승인"이라고 말하기 전에는 cleanup, commit, push, 다음 Phase를 하지 않는다.
13. 검증 승인 후 현재 Phase가 소유한 리소스만 cleanup하고 잔여 리소스 0을 확인한다.
    그다음 한국어 커밋 메시지로 commit하고 push한 뒤 다음 Phase의 plan 승인 대기까지만 진행한다.
14. 저장소에 아직 구현되지 않은 Phase adapter가 있으면 없는 기능을 실행된 것처럼 보고하지 말고,
    구현 범위와 막힌 지점을 먼저 설명한다.

지금은 외부 변경을 하지 말고, 설치 상태와 저장소 상태를 확인한 다음 내 GCP 프로젝트 ID를 물어봐.
```

GUI가 네트워크 접근, `git clone`, 파일 쓰기 또는 터미널 실행 권한을 요청하면 저장소와 위 경로에 한해 승인합니다. 저장소 소유의 정확한 `phases/<NN>/run.sh`·`verify.sh`에서만 UI의 **Always allow**를 선택할 수 있습니다. 전체 Bash/PowerShell을 포괄 허용하지 말고 `apply`, `destroy`, `commit`, `push`는 프롬프트의 별도 승인 지점을 유지합니다.

## 1. Windows Desktop에서 단일 GUI 모델로 실행

### Codex Desktop

1. Windows용 Codex Desktop을 설치하고 로그인합니다.
2. 새 프로젝트에서 `C:\Users\<사용자이름>` 또는 이미 clone한 `C:\Users\<사용자이름>\gcp-lab-harness`를 엽니다.
3. Agent environment는 **Windows native**, 통합 터미널은 **PowerShell**을 사용합니다. 저장소의 `harness.ps1`과 `bootstrap.ps1`이 필요한 Bash 명령만 WSL2 Ubuntu로 전달합니다.
4. 위의 「처음 한 번 붙여넣을 프롬프트」를 사용합니다.

Codex Desktop의 Windows·WSL·통합 터미널 설정은 [공식 OpenAI 문서](https://learn.chatgpt.com/docs/windows/windows-app)를 참고합니다.

### Claude Desktop

1. Claude Desktop을 설치하고 로그인한 뒤 상단의 **Code** 탭을 엽니다.
2. Environment에서 **Local**을 선택합니다.
3. 처음 clone할 때는 `C:\Users\<사용자이름>`, clone이 끝난 뒤에는 `C:\Users\<사용자이름>\gcp-lab-harness`를 프로젝트 폴더로 선택합니다.
4. 위의 「처음 한 번 붙여넣을 프롬프트」를 사용합니다.

Windows의 Claude Desktop Code 로컬 세션에는 Git for Windows가 필요합니다. 자세한 시작 방법은 [Claude Code Desktop 공식 문서](https://code.claude.com/docs/en/desktop-quickstart)를 참고합니다.

### Phase마다 사용할 짧은 프롬프트

첫 설정이 끝나면 같은 Desktop 대화에서 다음 세 문장만 순서대로 사용합니다.

계획 시작:

```text
현재 Phase를 같은 GUI 모델 하나로 진행해줘. 먼저 저장 plan까지만 만들고,
생성/변경/삭제 수와 plan SHA256을 보고한 뒤 멈춰.
```

plan 승인 후:

```text
plan SHA256 <여기에_SHA256>을 승인해. 해당 저장 plan만 apply하고
machine verification과 읽기 전용 GCP 검증을 수행한 뒤 evidence와 함께 멈춰.
```

검증 결과를 직접 확인한 후:

```text
검증 승인. 현재 Phase 소유 리소스만 cleanup하고 잔여 리소스 0을 확인해.
그다음 변경을 한국어 메시지로 commit하고 push한 뒤 다음 Phase의 plan 승인 대기까지만 진행해.
```

## 2. Windows에서 먼저 clone한 뒤 Desktop으로 실행

링크 붙여넣기 방식에서 폴더 선택이나 권한 문제가 생기면 PowerShell에서 먼저 clone하는 방법이 가장 확실합니다.

PowerShell을 열고 Git과 WSL 상태를 확인합니다.

```powershell
git --version
wsl --status
```

명령을 찾을 수 없으면 관리자 PowerShell에서 필요한 항목을 설치합니다.

```powershell
winget install --id Git.Git -e
wsl --install -d Ubuntu
```

Git 설치 후 PowerShell을 다시 열어야 `git`이 인식될 수 있습니다. WSL 설치 후에는 재부팅이 요구될 수 있습니다. 재부팅과 Ubuntu 초기 사용자 설정을 마친 다음 저장소를 clone합니다.

```powershell
Set-Location $HOME
git clone https://github.com/grapefruit0205/gcp-lab-harness.git "$HOME\gcp-lab-harness"
Set-Location "$HOME\gcp-lab-harness"
```

프로젝트를 준비합니다.

```powershell
Set-Location "$HOME\gcp-lab-harness"
powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 -ProjectId <GCP_PROJECT_ID>
```

이후 Codex Desktop 또는 Claude Desktop의 Code 탭에서 다음 폴더를 열고 위의 첫 프롬프트를 붙여넣습니다.

```text
C:\Users\<사용자이름>\gcp-lab-harness
```

## 3. Windows VS Code에서 Claude 또는 Codex로 실행

### 공통 준비

PowerShell에서 VS Code 명령을 확인합니다.

```powershell
code --version
```

`code` 명령이 없으면 VS Code를 설치한 뒤 PowerShell을 다시 엽니다.

```powershell
winget install --id Microsoft.VisualStudioCode -e
```

저장소를 clone하고 VS Code로 엽니다. Git과 WSL을 아직 준비하지 않았다면 먼저 「Windows에서 먼저 clone한 뒤 Desktop으로 실행」 절의 확인·설치 단계를 수행합니다.

```powershell
Set-Location $HOME
git clone https://github.com/grapefruit0205/gcp-lab-harness.git "$HOME\gcp-lab-harness"
Set-Location "$HOME\gcp-lab-harness"
code .
```

VS Code의 Extensions 화면(`Ctrl+Shift+X`)에서 다음 중 하나를 설치하고 로그인합니다.

- **Codex**: Codex 아이콘을 누르거나 Command Palette에서 `Codex: Open Codex Sidebar`를 실행합니다.
- **Claude Code**: `Claude Code` Extension을 설치하고 Spark 아이콘으로 패널을 엽니다.

공식 설치 안내: [Codex IDE Extension](https://learn.chatgpt.com/docs/codex/ide), [Claude Code for VS Code](https://code.claude.com/docs/en/ide-integrations)

VS Code 통합 터미널을 PowerShell로 열어 GCP 연결을 준비합니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 -ProjectId <GCP_PROJECT_ID>
```

그다음 설치한 Codex 또는 Claude Code 패널에 아래 프롬프트를 붙여넣습니다.

```text
현재 열려 있는 gcp-lab-harness 저장소를 Windows PowerShell+WSL2 환경에서 운영해줘.
AGENTS.md, README.md, memory/DECISIONS.md, memory/PRODUCT-TRUTH.md와 현재 checkpoint를 먼저 읽어.

이 Extension에서 선택된 모델 하나만 사용하고 subagent나 다른 모델 CLI를 호출하지 마.
현재 Phase를 확인한 뒤 저장 plan까지만 만들고 생성/변경/삭제 수와 SHA256을 보여준 후 멈춰.
내가 plan SHA를 승인하면 그 저장 plan만 apply하고 machine verification과 읽기 전용 GCP 검증을 수행해.
검증 evidence를 보고한 뒤 다시 멈추고, 내가 "검증 승인"이라고 말한 경우에만
현재 Phase cleanup, 잔여 리소스 0 확인, 한국어 commit, push, 다음 Phase plan 순서로 진행해.
비밀정보와 Terraform state는 Git에 넣지 말고, 구현되지 않은 Phase는 완료됐다고 보고하지 마.
```

Codex와 Claude Code 중 **한 Extension만 선택**하면 단일 모델 경로입니다. 저장소의 자동 Extension handoff는 현재 VS Code Codex Extension 경로만 연결되어 있으므로, Claude Code Extension을 선택한 경우에는 위 프롬프트로 같은 승인 순서를 직접 진행합니다.

## 4. 기존 Command Code 실행 + VS Code Codex 검증 경로

기존 설계대로 구현 모델과 검증 화면을 분리하려면 Windows PowerShell에서 Command Code 세션을 시작합니다. `cmd`의 현재 계정에 고정된 모델을 사용하며 `--model`과 `--effort`는 전달하지 않습니다.

```powershell
Set-Location "$HOME\gcp-lab-harness"
.\harness.ps1 start --run lab-20260825-01
```

열린 `cmd` 세션에는 다음처럼 지시합니다.

```text
현재 Phase를 확인하고 구현을 시작해줘. 먼저 저장 plan까지만 만들고,
생성·변경·삭제 수와 plan SHA256을 보여준 뒤 내 승인을 기다려.
승인 후 apply와 machine verification을 완료하면 VS Code Codex Extension으로 handoff해줘.
```

VS Code Codex Extension에서 열린 `EXTENSION_REVIEW_PROMPT.md`에 따라 검증하고 사용자가 승인한 뒤 다음 명령으로 기존 Command Code 세션을 재개합니다.

```powershell
.\harness.ps1 handoff next --run lab-20260825-01
```

반려된 경우에도 같은 명령이 findings를 기존 세션에 전달하며 다음 Phase로 넘어가지 않고 현재 Phase를 다시 구현합니다.

## 5. Command Code 고정 모델 단독 실행

GUI가 아니라 Command Code 계정의 같은 고정 모델 하나로 구현과 자기 검증을 연속 수행하려면 다음 명령을 사용합니다.

```powershell
.\harness.ps1 single-model run --run lab-20260825-01
```

출력된 plan SHA256을 확인한 뒤에만 apply를 허용합니다.

```powershell
.\harness.ps1 single-model run --run lab-20260825-01 --confirm-plan-sha <PLAN_SHA256>
```

자기 검증 결과가 `pass`이고 세 hash가 현재 bundle과 일치하는 것을 직접 확인한 뒤 승인·다음 handoff를 실행합니다.

```powershell
.\harness.ps1 single-model approve --run lab-20260825-01
.\harness.ps1 handoff next --run lab-20260825-01
```

Command Code Phase session은 저장소 소유 `run.sh`·`verify.sh`의 정확한 패턴만 허용 목록에 추가합니다. 모든 명령을 포괄 승인하지 않으며 plan SHA, project allowlist, cleanup 소유권과 push gate는 유지합니다.

## 설계 원칙

- 콘솔 클릭을 자동화하지 않고 같은 최종 상태를 만드는 `gcloud`, `bq`, Terraform, REST 검증으로 전환합니다.
- 모든 시나리오는 `plan -> apply -> verify -> destroy` 상태 전이를 따릅니다.
- 프로젝트 allowlist, plan 저장, 명시적 승인, 비용 사전 점검 없이 `apply`하지 않습니다.
- 기본 경로는 실행자와 Extension 검증자를 분리하며, 선택 경로는 같은 고정 모델의 구현·자기 검증 뒤 사용자 승인을 받습니다. 두 경로 모두 검증 승인 후에만 Phase 단위 한국어 커밋을 남깁니다.
- 각 Phase는 clean working tree에서 `git pull --ff-only`로 시작하고 승인·cleanup 뒤 commit과 push로 닫습니다.
- 원시 로그·state·비밀정보는 Git에서 제외하고 정제된 증거 요약만 보존합니다.

## 저장소 안내

- [Phase 목록](docs/phases/README.md)
- [하네스 아키텍처](docs/architecture.md)
- [Command Code 실행·Extension 검증·커밋 흐름](docs/workflow.md)
- [한 번의 실행으로 Lab 01–15를 진행하는 오케스트레이션](docs/orchestration.md)
- [Google Cloud 계정과 Monitoring·Logging MCP 연동](docs/mcp-integration.md)
- [15개 실습 자동화 매핑](docs/source-map.md)
- `references/google-cloud-labs-ko/`: 자동화 기준이 되는 한국어 실습 원본 보존본
- `prompts/`: builder와 verifier의 handoff 계약
- `scripts/`: 환경 점검, Command Code handoff, Extension review, Phase gate, 커밋·push 보조 명령
- `lib/harness/`: pipeline 상태 전이와 Extension 승인 gate
- `schemas/`: pipeline 상태, Command Code 실행 결과, Extension 승인, Phase manifest의 기계 판독 계약

## 선택: Foundation canary

15개 Phase 전에 Terraform의 실제 create/destroy 권한만 작게 확인하려면 단일 custom-mode VPC canary를 사용합니다.

```bash
"$HOME/gcp-lab-harness/scripts/foundation-canary.sh" plan --run canary001
# 출력된 plan_sha256을 확인한 다음에만 apply
"$HOME/gcp-lab-harness/scripts/foundation-canary.sh" apply --run canary001 --confirm-plan-sha <PLAN_SHA256>
"$HOME/gcp-lab-harness/scripts/foundation-canary.sh" verify --run canary001
"$HOME/gcp-lab-harness/scripts/foundation-canary.sh" destroy --run canary001
```

예산 한도는 필수 설정이 아닙니다. 대신 허용 프로젝트 exact match, 결제 연결 확인, 저장된 plan 승인, Phase당 리소스 상한, apply timeout과 실패 시 cleanup을 사용합니다. 실제 실행 데이터는 Git에서 제외된 `artifacts/runs/`에 저장됩니다.

개발자용 최소 점검은 clone 경로를 직접 입력하지 않고 다음처럼 실행합니다.

```bash
gcp-lab-harness doctor
"$HOME/gcp-lab-harness/scripts/validate-design.sh"
"$HOME/gcp-lab-harness/tests/offline-controller.sh"
```

## 다음 결정

저장 plan hash를 승인한 뒤 canary apply·verify·destroy를 순서대로 진행하고, 저장소 라이선스를 확정합니다. 실제 Lab adapter는 선택한 프로젝트의 allowlist preflight 뒤에만 apply됩니다.
