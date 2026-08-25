# Command Code CLI 실행 계약

Checked: 2026-08-25

## Observed

- `cmd`는 `/home/grapefruit/.nvm/versions/node/v22.23.2/bin/cmd`에 설치된 Command Code CLI 1.32.2다.
- `cmd status`에서 Command Code provider 계정 인증이 확인됐다.
- non-interactive 실행은 `cmd -p`, NDJSON 출력은 `--output-format json`, session 재개는 `--session` 또는 `--continue`를 지원한다.
- `--model`과 `--effort`를 생략하면 현재 Command Code 설정을 사용한다. 이 프로젝트에서는 두 flag를 전달하지 않는다.

## Evidence

- Local primary source: `cmd --help`, `cmd status`, `cmd info` on 2026-08-25
- Package: `command-code@1.32.2` in the active Node 22 global modules

## Limits

- 실제 GCP Phase 실행은 아직 하지 않았다.
- `--permission-mode auto-accept`는 Foundation의 project allowlist·plan gate·resource ownership guard가 구현된 뒤에만 운영한다.
