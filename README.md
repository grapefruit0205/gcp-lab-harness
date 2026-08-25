# Google Cloud 실습 자동화 하네스

한국어 Google Cloud 실습 15개를 CLI에서 재현·검증·정리하기 위한 harness engineering 저장소입니다. Ubuntu Bash의 **Command Code CLI `cmd`**가 Phase 실행을 오케스트레이션하고, 현재 사용 중인 **VS Code Codex Extension**이 변경과 실행 증거를 독립 검증합니다. `cmd`는 현재 계정에 고정된 모델을 그대로 사용합니다.

> 현재 상태: **Foundation과 canary adapter 준비, 1단계 Terraform plan 완료**. 실제 Google Cloud 리소스 apply는 아직 수행하지 않았습니다.

원격 저장소: [grapefruit0205/gcp-lab-harness](https://github.com/grapefruit0205/gcp-lab-harness) (public)

## 1. git clone 후 한 번에 준비

Linux에서는 저장소를 `$HOME/gcp-lab-harness`에 받고 Bash로 root bootstrap만 실행합니다. Google 로그인 창이 열리면 각자의 실습 계정으로 승인합니다.

```bash
git clone https://github.com/grapefruit0205/gcp-lab-harness.git "$HOME/gcp-lab-harness"
bash "$HOME/gcp-lab-harness/bootstrap.sh" <GCP_PROJECT_ID>
export PATH="$HOME/.local/bin:$PATH"
```

`bootstrap.sh`는 `gcp-lab-harness` 사용자 명령을 `$HOME/.local/bin`에 설치하고, gcloud·Terraform 설치, GCP 사용자 로그인·ADC, 프로젝트 allowlist, billing preflight와 Terraform provider 연결까지 실행합니다. 인증정보와 로컬 project·billing 값은 Git에 올라가지 않습니다.

Windows PowerShell에서는 WSL Ubuntu를 설치한 상태에서 다음 두 파일만 사용합니다. PowerShell 진입점이 같은 Bash 하네스를 WSL에서 실행하므로 별도 구현이 갈라지지 않습니다.

```powershell
git clone https://github.com/grapefruit0205/gcp-lab-harness.git "$HOME\gcp-lab-harness"
Set-Location "$HOME\gcp-lab-harness"
powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 -ProjectId <GCP_PROJECT_ID>
```

## 2. Command Code에서 자연어로 단계 구현

Bash에서 다음 명령을 실행하면 저장소를 workspace로 사용하는 Command Code 대화형 세션이 열립니다. `--model`과 `--effort`는 전달하지 않으므로 현재 계정에 고정된 모델을 그대로 사용합니다.

```bash
gcp-lab-harness start --run lab-20260825-01
```

PowerShell에서는 같은 명령을 wrapper로 실행합니다.

```powershell
.\harness.ps1 start --run lab-20260825-01
```

열린 `cmd` 안에서는 자연어로 지시합니다.

```text
현재 Phase를 확인하고 구현을 시작해줘. 먼저 저장 plan까지만 만들고,
생성·변경·삭제 수와 plan SHA256을 보여준 뒤 내 승인을 기다려.
승인 후 apply와 machine verification을 완료하면 VS Code Codex Extension으로 handoff해줘.
```

Command Code는 `sync → preflight → plan → apply → machine_verify`를 상태 파일에 기록합니다. apply 전에는 plan hash 승인을 기다리고, 구현·기계 검증이 끝나면 다음 명령을 내부에서 호출해 VS Code와 검증 prompt를 엽니다.

```bash
gcp-lab-harness handoff review --run <RUN_ID> --plan <저장-plan> --evidence <검증-manifest>
```

## 3. Extension 검증 후 다음 Phase handoff

VS Code Codex Extension은 열린 `EXTENSION_REVIEW_PROMPT.md`에 따라 diff, plan, evidence와 실제 GCP 상태를 읽기 전용으로 검증합니다. 사용자가 검증 완료를 명시적으로 승인한 경우에만 prompt에 포함된 exact `gate approve` 명령을 실행합니다.

승인 후 Bash에서 다음 명령을 실행하면 같은 Command Code 세션으로 돌아가 cleanup, 잔여 리소스 0 확인, 한국어 commit·push를 수행하고 다음 Phase 구현으로 이어집니다.

```bash
gcp-lab-harness handoff next --run <RUN_ID>
```

PowerShell에서는 다음과 같습니다.

```powershell
.\harness.ps1 handoff next --run <RUN_ID>
```

반려된 경우에도 같은 `handoff next`가 Extension findings를 기존 Command Code 세션에 전달하며, 다음 Phase로 넘어가지 않고 현재 Phase를 다시 구현합니다.

## 4. 선택: 단일 모델로 구현과 검증

VS Code Extension과 별도 모델을 사용하지 않고, 현재 Command Code 계정에 고정된 **같은 모델 하나**가 구현 패스와 자기 검증 패스를 연속 수행할 수도 있습니다. 모델·effort override는 사용하지 않습니다.

```bash
gcp-lab-harness single-model run --run lab-20260825-01
```

plan 단계에서는 생성·변경·삭제 수와 SHA256을 출력하고 중단합니다. 사용자가 그 hash를 확인한 뒤에만 다음처럼 apply까지 허용합니다.

```bash
gcp-lab-harness single-model run --run lab-20260825-01 \
  --confirm-plan-sha <PLAN_SHA256>
```

이미 `waiting_extension_review` 상태인 Phase도 첫 명령으로 같은 모델 검증만 수행할 수 있습니다. 결과가 `pass`이고 세 hash가 현재 bundle과 일치하는 것을 사용자가 확인한 뒤 승인과 다음 handoff를 실행합니다.

```bash
gcp-lab-harness single-model approve --run lab-20260825-01
gcp-lab-harness handoff next --run lab-20260825-01
```

PowerShell에서는 앞에 `.\harness.ps1`을 붙입니다.

```powershell
.\harness.ps1 single-model run --run lab-20260825-01
.\harness.ps1 single-model approve --run lab-20260825-01
.\harness.ps1 handoff next --run lab-20260825-01
```

Phase session을 열 때 `.commandcode/settings.json`에 Phase 01–15의 repo `run.sh`·`verify.sh`와 필수 하네스 스크립트만 허용 목록으로 병합해 `.sh` 실행 여부를 매번 묻지 않도록 설정합니다. 모든 명령을 포괄 승인하지 않으며 plan SHA 사용자 승인, project allowlist, cleanup 소유권과 push gate는 그대로 유지됩니다.

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
