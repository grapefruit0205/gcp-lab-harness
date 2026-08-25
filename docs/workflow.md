# Command Code 실행·Codex Extension 검증·Git 워크플로

## 역할 분리

| 역할 | 실행 위치 | 권한 | 결과 |
|---|---|---|---|
| Phase runner | Ubuntu Bash의 Command Code `cmd` | 승인된 Phase 범위의 Cloud 실행 | 실행 evidence와 Extension 대기 상태 |
| Harness runner | Ubuntu Bash | 승인된 Google Cloud 범위 | plan, 리소스, 원시 evidence |
| Verifier | VS Code Codex Extension | 읽기 전용 | `/review`와 Phase별 심각도 review |
| Maintainer | 사용자 터미널 | stage, commit, 명시적 push | 한국어 Git 이력 |

## 1. Phase 시작

```bash
git status --short --branch
./scripts/sync-before-phase.sh
make doctor
make validate-design
```

작업 트리에 이전 Phase의 미확인 변경이 있으면 pull하지 않고 먼저 해결한다. 동기화는 `git pull --ff-only`만 허용하며 remote와 local이 분기되면 자동 merge·rebase 없이 중단한다. 새 Phase 문서의 선행 조건과 비용 등급을 읽고, Google Cloud 변경이 필요한 경우 plan 단계까지만 먼저 실행한다.

## 2. Ubuntu Bash에서 Command Code 실행 handoff

Foundation과 대상 Phase adapter가 구현된 뒤 실행한다. 현재 설계 골격은 둘 중 하나라도 없으면 Command Code를 호출하기 전에 중단한다.

```bash
make handoff-execute PHASE=docs/phases/phase-NN-name.md
```

스크립트는 공통 실행 규칙과 Phase 문서를 합쳐 인증된 Command Code `cmd -p`에 전달한다. 이벤트와 최종 JSON은 Git에서 제외된 `artifacts/runs/`에 저장한다. `cmd`에는 `--model`과 `--effort`를 전달하지 않아 현재 계정의 고정 모델을 사용한다. Command Code는 Extension 승인, commit, push, 다음 Phase 전이를 수행하지 않는다.

반려 finding을 같은 Command Code session에 다시 전달할 때 다음 형태로 이어간다.

```bash
cmd --session <session-id> -p "Extension 반려 finding을 수정하고 machine verification을 다시 실행해줘"
```

## 3. 하네스 plan·apply·verify·destroy

Foundation에서 최종 CLI와 안전장치가 구현되면 다음 순서로 실행한다.

```bash
./bin/gcp-lab-harness preflight NN
./bin/gcp-lab-harness plan NN
./bin/gcp-lab-harness apply NN --plan artifacts/<run-id>/plan --approve <run-id>
./bin/gcp-lab-harness verify NN --run <run-id>
./bin/gcp-lab-harness destroy NN --run <run-id>
./bin/gcp-lab-harness inventory NN --run <run-id>
```

`apply` 전에는 저장된 plan과 예상 비용을 사람이 확인한다. 검증 실패 여부와 관계없이 destroy와 inventory를 실행하되, 소유권 manifest가 손상되었으면 자동 삭제하지 않고 `cleanup_required`로 중단한다.

## 4. VS Code Codex Extension에서 독립 검증

Extension에 전달할 Phase별 검증 prompt를 생성한다.

```bash
make prepare-extension-review PHASE=docs/phases/phase-NN-name.md
make phase-gate PHASE=docs/phases/phase-NN-name.md
```

VS Code에서 생성된 `EXTENSION_REVIEW_PROMPT.md`를 열고 Codex Extension에 저장소의 Phase gate와 필요한 CLI 검증을 실행한 뒤 현재 uncommitted changes와 실행 증거를 판정하도록 지시한다. Extension의 `/review`를 함께 사용해도 된다. Verifier는 파일을 고치지 않는다. P0/P1, Phase 목표 누락, 안전장치 우회, 정리 누락을 발견하면 builder로 되돌린다. GCP 통합 테스트를 실행하지 않은 경우 “통과”가 아니라 “미실행”으로 남긴다.

## 5. 한국어 commit과 push

검증된 파일만 사용자가 직접 stage한다.

```bash
git add <phase-산출물>
git diff --cached --check
git diff --cached
./scripts/commit-phase.sh docs/phases/phase-NN-name.md "Phase 요약"
./scripts/push-phase.sh --confirm
```

커밋 형식은 `Phase NN: <한국어 요약> 완료`다. 한 커밋은 한 Phase의 완료 조건만 담는다. GitHub 생성 전에는 로컬 commit까지만 허용하며, `origin`과 공개 범위가 확인된 뒤 push한다.

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
