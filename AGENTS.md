<!-- ballast session-start block — append to the project's CLAUDE.md -->

## Session start (ballast)

1. Before substantive work, read `memory/00-INDEX.md` and `memory/DECISIONS.md`. Standing decisions are followed without relitigating — to change one, use the supersede protocol (ballast decision-ledger skill).
2. Record decisions and important facts in `memory/` **in the same session they appear**. Unresolved items go to `memory/OPEN-QUESTIONS.md` — and so does any reading of a non-answer you are proceeding on, as `assumed`, never as a decision.
3. Claims carry labels: confirmed / observed / assumed / hearsay / unknown (ballast verify-gate skill).
4. External-facing product claims require evidence in `memory/PRODUCT-TRUTH.md` (ballast proof-standard skill).

## Repository rules

- 사용자 문서, 커밋 메시지, handoff 결과 요약은 한국어로 작성한다.
- `references/google-cloud-labs-ko/`는 원본 보존 영역이다. 자동화 설계가 원문을 대체하지 않으며 이 폴더를 직접 수정하지 않는다.
- 각 Phase는 `plan -> apply -> verify` 계약과 명시적으로 승인된 종료 시 `destroy` 경로를 구현한다. 실패 시 전체 destroy하지 않고 리소스·state·진단 로그를 보존하여 원인 분석·수정·변경 plan 승인·재apply·재검증으로 복구한다(D-036/D-037). 삭제·교체는 승인된 최소 범위에만 수행한다.
- 기존 자동 실패 destroy 경로는 Q-014에서 보존 복구 방식으로 이관하기 전 실행하지 않는다. 규칙 pin이 실제 자동화 코드 수정 완료를 의미하지는 않는다.
- Phase09는 전용 `recovery.sh`의 실패 보존·동일 state `replan` 경로를 사용한다. shared adapter의 기존 apply helper를 직접 호출하지 않는다. 다른 Phase의 자동 삭제 이관은 Q-014에 별도로 남아 있다.
- Google Cloud 변경은 허용 프로젝트 확인, 저장된 plan, 명시적 승인, 고유 run ID가 모두 있을 때만 수행한다.
- 서비스 계정 키, 사용자 자격 증명, CSEK, 데이터베이스 비밀번호, VPN PSK, Terraform state, 원시 실행 로그는 Git에 넣지 않는다.
- 장기 서비스 계정 키 대신 사용자 ADC 또는 서비스 계정 가장을 우선한다.
- 실행 오케스트레이터는 Ubuntu Bash의 Command Code CLI `cmd`다. `cmd`에 `--model`이나 `--effort`를 전달하지 않고 현재 계정 설정을 상속한다. 실행자는 commit과 push를 하지 않는다.
- verifier는 VS Code Codex Extension에서 저장소 검증 명령을 실행하고 diff와 증거를 판정하되, 사용자의 명시적 승인 전에는 approval·commit·push를 만들지 않는다.
- Phase 검증이 통과한 뒤 사용자가 stage한 변경만 한국어 메시지로 커밋한다. push는 별도 명시 명령으로 실행한다.
- 각 Phase 시작 전 clean working tree에서 `git pull --ff-only`로 원격을 동기화한다. 자동 merge·rebase·force push는 하지 않으며 분기되면 중단한다.
- 테스트는 변경 위험에 비례해 최소 범위로 실행하되, Bash 문법·Terraform 정적 검사·phase gate는 생략하지 않는다.
- 각 Phase 완료 보고에는 `python3 scripts/console-checks.py --phase NN`으로 해당 안내를 읽고 Task별 콘솔 경로·확인 대상·통과 기준·한계와 보조 증거를 함께 제시한다(D-043). 자동 검사 통과를 사용자의 콘솔 확인 완료로 쓰지 않는다. 이미 destroy했으면 현재 리소스 부재와 삭제 전 증거를 구분하고 확인을 위해 재생성하지 않는다.
- D-044: Task 요약만 제공하지 않고 원문 하위 항목별 상세 확인서 `docs/console/phase-NN.md`도 연결한다. 단일 Task는 `console-checks.py --phase NN --task N`으로 읽는다. Phase10–15는 `safe-adapter.sh`의 실패 보존·동일 state replan을 사용하며 legacy apply/destroy helper를 호출하지 않는다.
