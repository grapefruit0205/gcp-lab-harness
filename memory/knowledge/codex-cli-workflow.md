# Codex CLI 기능 기록 — 현재 실행·검증 경로에서 제외

Checked: 2026-08-25

## Confirmed

- `codex exec`는 비대화형 실행을 제공하며 prompt를 stdin에서 받을 수 있고 `--sandbox workspace-write`, `-C`, `--json`, `--output-schema`, `--output-last-message`를 지원한다.
- `codex review --uncommitted`는 staged·unstaged·untracked 변경을 대상으로 비대화형 review를 실행한다.
- Codex는 저장소의 `AGENTS.md`를 지속 지침으로 사용한다.

## Evidence

- Official Codex command manual: https://learn.chatgpt.com/docs/developer-commands.md?surface=cli
- Official Codex non-interactive guide: https://learn.chatgpt.com/docs/non-interactive-mode.md
- Observed locally: `codex-cli 0.149.1`, `codex exec --help`, `codex review --help` on 2026-08-25

## Limits

이 기록은 D-009 이전에 조사한 기능 메모다. 현재 Phase runner는 Command Code `cmd`, verifier는 VS Code Codex Extension이며 `codex exec`·`codex review`를 별도 실행·검증 경로로 사용하지 않는다. `codex` CLI는 Extension과 공유하는 MCP 구성 확인에만 쓸 수 있다.
