# Command Code 실행·Codex Extension 검증·Git 워크플로

## 역할 분리

| 역할 | 실행 위치 | 권한 | 결과 |
|---|---|---|---|
| Phase runner | Ubuntu Bash의 Command Code `cmd` | 승인된 Phase 범위의 Cloud 실행 | 실행 evidence와 Extension 대기 상태 |
| Harness runner | Ubuntu Bash 또는 PowerShell→WSL wrapper | 승인된 Google Cloud 범위 | plan, 리소스, 원시 evidence |
| Verifier | VS Code Codex Extension | 읽기 전용 | `/review`와 Phase별 심각도 review |
| Single-model verifier(선택) | 같은 Command Code 고정 모델 | 현재 Phase의 구현·자기 검증 | hash 결합 review JSON과 사용자 승인 대기 |
| Maintainer | 사용자 터미널 | stage, commit, 명시적 push | 한국어 Git 이력 |

## 1. Phase 시작

```bash
gcp-lab-harness start --run <RUN_ID>
```

PowerShell에서는 clone한 저장소에서 `.\harness.ps1 start --run <RUN_ID>`를 실행한다. 시작 스크립트가 pipeline 상태를 만들고 Command Code 대화형 세션을 연다. 작업 트리에 이전 Phase의 미확인 변경이 있으면 pull하지 않고 먼저 해결한다. 동기화는 `git pull --ff-only`만 허용하며 remote와 local이 분기되면 자동 merge·rebase 없이 중단한다.

## 2. Ubuntu Bash에서 Command Code 실행 handoff

Command Code 세션 안에서 자연어로 현재 Phase 구현을 지시한다.

```text
현재 Phase를 구현해줘. 저장 plan의 영향과 SHA256을 먼저 보고하고 내 승인을 기다려.
승인 후 apply와 machine verification을 완료하면 Extension으로 handoff해줘.
```

`start`는 공통 실행 규칙과 현재 pipeline 상태를 인증된 Command Code `cmd`에 전달한다. `cmd`에는 `--model`과 `--effort`를 전달하지 않아 현재 계정의 고정 모델을 사용한다. Command Code는 Extension 승인 전 commit, push, 다음 Phase 전이를 수행하지 않는다.

반려 finding을 같은 Command Code session에 다시 전달할 때 다음 형태로 이어간다.

반려 finding은 `gcp-lab-harness handoff next --run <RUN_ID>`가 같은 이름의 Command Code session으로 다시 전달한다.

## 3. 하네스 plan·apply·verify·destroy

Command Code는 controller의 next action을 읽고 다음 상태만 실행한다.

```bash
gcp-lab-harness resume --run <RUN_ID>
gcp-lab-harness transition <NN> synced --run <RUN_ID>
gcp-lab-harness transition <NN> preflight --run <RUN_ID>
gcp-lab-harness transition <NN> planned --run <RUN_ID>
# 사용자 plan hash 승인 뒤 applied, machine_verified 순으로 기록
```

`apply` 전에는 저장된 plan과 예상 비용을 사람이 확인한다. 검증 실패 여부와 관계없이 destroy와 inventory를 실행하되, 소유권 manifest가 손상되었으면 자동 삭제하지 않고 `cleanup_required`로 중단한다.

## 4. VS Code Codex Extension에서 독립 검증

machine verification이 끝난 Command Code가 Phase별 검증 prompt를 생성하고 VS Code에 연다.

```bash
gcp-lab-harness handoff review --run <RUN_ID> --plan <저장-plan> --evidence <검증-manifest>
```

VS Code Codex Extension은 prompt의 저장 plan·diff·evidence hash와 필요한 CLI 검증을 실행한 뒤 현재 uncommitted changes와 실행 증거를 판정한다. 사용자가 명시적으로 승인한 경우에만 prompt에 포함된 exact `gate approve` 명령을 실행한다. Verifier는 파일을 고치지 않는다. P0/P1, Phase 목표 누락, 안전장치 우회, 정리 누락을 발견하면 builder로 되돌린다.

## 5. 한국어 commit과 push

사용자 승인 뒤 같은 Command Code 세션으로 handoff한다.

```bash
gcp-lab-harness handoff next --run <RUN_ID>
```

PowerShell에서는 `.\harness.ps1 handoff next --run <RUN_ID>`를 사용한다. Command Code는 승인된 Phase의 리소스만 cleanup하고 잔여 리소스 0을 확인한 뒤 검증된 파일만 stage한다. 커밋 형식은 `Phase NN: <한국어 요약> 완료`다. push까지 성공하면 controller가 다음 Phase로 이동하고 같은 흐름을 반복한다.

## 선택 경로: 단일 모델 구현·검증

별도 Extension 모델 없이 같은 Command Code 고정 모델을 사용할 때 다음 명령으로 현재 Phase를 실행한다.

```bash
gcp-lab-harness single-model run --run <RUN_ID>
```

승인 plan SHA가 없으면 `planned`에서 멈춘다. hash 확인 뒤 `--confirm-plan-sha <SHA256>`을 붙여 다시 실행하면 apply·machine verification·자기 검증까지 진행한다. 단일 모델은 `single-model-review.json`을 만들지만 자기 결과를 승인하지 않는다.

```bash
gcp-lab-harness single-model approve --run <RUN_ID>
gcp-lab-harness handoff next --run <RUN_ID>
```

`single-model approve`는 사용자가 직접 실행하는 승인 명령이다. review schema, verdict, 모든 check, P0/P1 부재와 plan/diff/evidence hash 일치를 다시 검사한다. Phase Command Code session은 `.commandcode/settings.json`에 Phase 01–15의 repo `run.sh`·`verify.sh`와 필수 하네스 스크립트만 허용 목록으로 병합해 `.sh` 실행 질문이 발생하지 않도록 하며 Cloud·Git 외부 변경 gate는 유지한다.

GitHub CLI가 설치되고 저장소 이름·공개 범위가 확정된 뒤 최초 1회만 다음 중 하나를 사용한다.

```bash
gh repo create <repo-name> --public --source=. --remote=origin --push
# 비공개 저장소가 필요할 때만 --private
```

최초 push 뒤부터는 모든 Phase가 `sync-before-phase.sh`를 통과해야 한다. `pull --ff-only` 실패는 자동 해결하지 않고 사용자에게 remote/local SHA를 보고한다.

## 6. 실패와 복구

- Builder 실패: `artifacts/runs/<run-id>/<phase>/command-code/events.jsonl`을 읽고 같은 Command Code session을 resume한다.
- Apply 실패: manifest를 보존하고 `destroy --run <run-id>`를 시도한다.
- Verify 실패: 리소스를 유지해야 진단 가능한 경우 최대 유지 시간을 기록하고, 만료 전에 destroy한다.
- Destroy 실패: `cleanup_required`로 표시하고 남은 종류·지역·hash를 출력한다. 이름 추측으로 삭제하지 않는다.
- Review 실패: commit하지 않고 builder에 구체적 finding을 전달한다.
- Push 실패: 로컬 commit은 유지하고 remote/auth 상태를 고친 뒤 같은 commit을 다시 push한다.
