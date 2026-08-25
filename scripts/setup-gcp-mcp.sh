#!/usr/bin/env bash
set -Eeuo pipefail

mode="${1:-setup}"
[[ "$mode" == setup || "$mode" == check ]] || { printf '사용법: %s [setup|check]\n' "$0" >&2; exit 2; }
command -v codex >/dev/null 2>&1 || { printf 'FAIL: codex CLI가 없습니다.\n' >&2; exit 1; }
current="$(codex mcp list --json 2>/dev/null || printf '[]')"
has_monitoring=false; has_logging=false
rg -q 'https://monitoring.googleapis.com/mcp|gcp-monitoring' <<<"$current" && has_monitoring=true
rg -q 'https://logging.googleapis.com/mcp|gcp-logging' <<<"$current" && has_logging=true
if [[ "$mode" == setup ]]; then
  [[ "$has_monitoring" == true ]] || codex mcp add gcp-monitoring --url https://monitoring.googleapis.com/mcp
  [[ "$has_logging" == true ]] || codex mcp add gcp-logging --url https://logging.googleapis.com/mcp
  current="$(codex mcp list --json)"
  rg -q 'https://monitoring.googleapis.com/mcp|gcp-monitoring' <<<"$current" || { printf 'FAIL: Monitoring MCP 등록 실패\n' >&2; exit 1; }
  rg -q 'https://logging.googleapis.com/mcp|gcp-logging' <<<"$current" || { printf 'FAIL: Logging MCP 등록 실패\n' >&2; exit 1; }
  printf 'PASS: Monitoring·Logging MCP endpoint 등록 완료. VS Code Extension /mcp에서 OAuth 연결을 확인하세요.\n'
else
  [[ "$has_monitoring" == true && "$has_logging" == true ]] || { printf 'FAIL: Monitoring·Logging MCP endpoint를 먼저 등록하세요.\n' >&2; exit 1; }
  printf 'PASS: Monitoring·Logging MCP endpoint 등록 확인\n'
fi
