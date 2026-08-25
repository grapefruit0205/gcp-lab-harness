# Google Cloud 실습 자동화 하네스

한국어 Google Cloud 실습 15개를 CLI에서 재현·검증·정리하기 위한 harness engineering 저장소입니다. Ubuntu Bash의 **Command Code CLI `cmd`**가 Phase 실행을 오케스트레이션하고, 현재 사용 중인 **VS Code Codex Extension**이 변경과 실행 증거를 독립 검증합니다. `cmd`는 현재 계정에 고정된 모델을 그대로 사용합니다.

> 현재 상태: **설계와 실행 골격만 준비됨**. Google Cloud 리소스 자동화 모듈은 아직 구현되지 않았으며 계정에 어떤 변경도 수행하지 않았습니다.

원격 저장소: [grapefruit0205/gcp-lab-harness](https://github.com/grapefruit0205/gcp-lab-harness) (private)

## 설계 원칙

- 콘솔 클릭을 자동화하지 않고 같은 최종 상태를 만드는 `gcloud`, `bq`, Terraform, REST 검증으로 전환합니다.
- 모든 시나리오는 `plan -> apply -> verify -> destroy` 상태 전이를 따릅니다.
- 프로젝트 allowlist, plan 저장, 명시적 승인, 비용 사전 점검 없이 `apply`하지 않습니다.
- 실행자(builder)와 검증자(verifier)를 분리하고, 검증 통과 후에만 Phase 단위 한국어 커밋을 남깁니다.
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
- `schemas/`: Command Code 실행 결과, Extension 승인, Phase manifest의 기계 판독 계약

## 시작

```bash
cd /path/to/gcp-lab-harness
make doctor
make validate-design
```

Foundation에는 `gcloud`, Terraform, 동작하는 Git 원격 인증이 필요합니다. `gh`는 저장소 관리용 선택 도구입니다. 누락 도구와 계정·결제 설정이 있으면 설계 검증과 `run-all --dry-run`까지만 실행합니다.

15개 Phase의 단일 실행 진입점을 먼저 점검할 수 있습니다.

```bash
./scripts/run-all.sh --dry-run
```

원격 저장소가 연결된 뒤 Phase 시작 전 동기화합니다.

```bash
./scripts/sync-before-phase.sh
```

Foundation과 해당 adapter를 구현한 뒤 Phase 실행을 Ubuntu Bash에서 Command Code CLI로 넘깁니다. 스크립트는 모델·effort를 지정하지 않습니다. 현재 골격은 `config/harness.env`와 `phases/NN/execute.sh`가 없으면 안전하게 중단합니다.

```bash
make handoff-execute PHASE=docs/phases/phase-01-console-cloud-shell.md
```

Extension에 전달할 검증 prompt를 만들고 VS Code에서 해당 파일을 연 뒤 Codex Extension에 검토를 요청합니다.

```bash
make prepare-extension-review PHASE=docs/phases/phase-01-console-cloud-shell.md
make phase-gate PHASE=docs/phases/phase-01-console-cloud-shell.md
```

생성된 `artifacts/reviews/.../EXTENSION_REVIEW_PROMPT.md`를 VS Code에서 열고 Codex Extension에 “이 prompt에 따라 검증 명령을 실행하고 현재 uncommitted 변경과 evidence를 판정해줘”라고 전달합니다. Extension의 `/review`도 함께 사용할 수 있습니다.

검증 결과를 확인한 뒤 필요한 파일만 직접 stage하고 Phase 커밋을 만듭니다.

```bash
git add <검증된-파일>
./scripts/commit-phase.sh docs/phases/phase-01-console-cloud-shell.md "Console과 Cloud Shell"
./scripts/push-phase.sh --confirm
```

`push-phase.sh`는 `origin`이 구성된 경우에만 동작하며, `--confirm` 없이는 외부 변경을 만들지 않습니다.

## 다음 결정

Google Cloud 프로젝트·결제 계정·예산 한도와 라이선스를 확정한 뒤 Foundation과 실제 Cloud adapter를 구현합니다.
