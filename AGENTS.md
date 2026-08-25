<!-- ballast session-start block — append to the project's CLAUDE.md -->

## Session start (ballast)

1. Before substantive work, read `memory/00-INDEX.md` and `memory/DECISIONS.md`. Standing decisions are followed without relitigating — to change one, use the supersede protocol (ballast decision-ledger skill).
2. Record decisions and important facts in `memory/` **in the same session they appear**. Unresolved items go to `memory/OPEN-QUESTIONS.md` — and so does any reading of a non-answer you are proceeding on, as `assumed`, never as a decision.
3. Claims carry labels: confirmed / observed / assumed / hearsay / unknown (ballast verify-gate skill).
4. External-facing product claims require evidence in `memory/PRODUCT-TRUTH.md` (ballast proof-standard skill).

## Repository rules

- 사용자 문서, 커밋 메시지, handoff 결과 요약은 한국어로 작성한다.
- `references/google-cloud-labs-ko/`는 원본 보존 영역이다. 자동화 설계가 원문을 대체하지 않으며 이 폴더를 직접 수정하지 않는다.
- 각 Phase는 `plan -> apply -> verify -> destroy` 계약과 실패 시 정리 경로를 함께 구현한다.
- Google Cloud 변경은 허용 프로젝트 확인, 저장된 plan, 명시적 승인, 고유 run ID가 모두 있을 때만 수행한다.
- 서비스 계정 키, 사용자 자격 증명, CSEK, 데이터베이스 비밀번호, VPN PSK, Terraform state, 원시 실행 로그는 Git에 넣지 않는다.
- 장기 서비스 계정 키 대신 사용자 ADC 또는 서비스 계정 가장을 우선한다.
- 실행 오케스트레이터는 Ubuntu Bash의 Command Code CLI `cmd`다. `cmd`에 `--model`이나 `--effort`를 전달하지 않고 현재 계정 설정을 상속한다. 실행자는 commit과 push를 하지 않는다.
- verifier는 VS Code Codex Extension에서 저장소 검증 명령을 실행하고 diff와 증거를 판정하되, 사용자의 명시적 승인 전에는 approval·commit·push를 만들지 않는다.
- Phase 검증이 통과한 뒤 사용자가 stage한 변경만 한국어 메시지로 커밋한다. push는 별도 명시 명령으로 실행한다.
- 각 Phase 시작 전 clean working tree에서 `git pull --ff-only`로 원격을 동기화한다. 자동 merge·rebase·force push는 하지 않으며 분기되면 중단한다.
- 테스트는 변경 위험에 비례해 최소 범위로 실행하되, Bash 문법·Terraform 정적 검사·phase gate는 생략하지 않는다.
