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

사용자는 앞서 제안한 저장소 이름 `gcp-lab-harness`와 private 공개 범위로 원격 저장소를 생성하는 것을 승인했다. GitHub 계정 `grapefruit0205` 아래 빈 저장소로 생성하고 로컬 `main`을 연결한다.

sweep: GitHub private 저장소 생성, repo 전용 Read/write deploy key, origin/main push, SHA 대조, fast-forward-only pull 및 README·Foundation 상태에 반영함 (2026-08-25)
