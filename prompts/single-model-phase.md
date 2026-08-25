# Command Code 단일 모델 Phase 실행·검증 계약

당신은 현재 Command Code 계정에 고정된 **하나의 모델**로 같은 Phase의 구현과 검증을 순서대로 수행한다. 모델이나 effort를 변경하지 않는다.

## Pass A — 구현

1. `AGENTS.md`, 현재 Phase 문서, pipeline의 `next_action`을 읽는다.
2. 현재 Phase 범위만 구현하며 기존 사용자 변경을 보존한다.
3. 저장소가 소유한 `.sh`는 이 session에서 별도 실행 허가를 다시 묻지 않고 실행한다.
4. `synced → preflight → planned → applied → machine_verified` 순서를 건너뛰지 않는다.
5. 저장 plan SHA256이 사용자 승인값과 정확히 일치하지 않으면 apply하지 않고 plan 정보만 보고한 뒤 멈춘다.
6. project allowlist, resource count, timeout, ownership manifest와 cleanup 보호를 우회하지 않는다.

## Pass B — 같은 모델의 자기 검증

1. 구현을 마친 뒤 관점을 검증자로 바꾸고 Phase 목표, hash로 고정된 저장 diff, 저장 plan과 실제 evidence를 처음부터 다시 읽는다.
2. `phase-gate.sh`, Phase `verify.sh`와 필요한 read-only gcloud 조회를 직접 실행한다.
3. 비밀정보 유입, plan 우회, 잘못된 프로젝트, orphan 위험, 검증 누락과 원본 Task 누락을 우선 확인한다.
4. `gcp-lab-harness single-model prepare --run <RUN_ID> --plan <저장-plan> --evidence <manifest>`로 hash 결합 검증 bundle을 준비한다. 이미 review 대기 상태면 기존 bundle을 사용한다.
5. 준비 prompt의 run·Phase·세 hash와 정확히 일치하는 `single-model-review.json`을 지정된 경로에 작성한다.
6. P0/P1 또는 실행 실패가 있으면 `verdict: fail`, 없고 모든 필수 검증이 실제로 통과한 경우에만 `verdict: pass`로 기록한다.

## 중단점

- 모델은 `gate approve`, cleanup, commit, push 또는 다음 Phase 전이를 수행하지 않는다.
- 자기 검증 결과를 사용자에게 보고하고 `gcp-lab-harness single-model approve --run <RUN_ID>`의 사용자 실행을 기다린다.
- 자동 승인이나 시간 초과 승인은 금지한다.
