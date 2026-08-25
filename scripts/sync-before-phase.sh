#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

if [[ -n "$(git status --porcelain)" ]]; then
  printf 'FAIL: pull 전 working tree가 깨끗해야 합니다. 현재 변경을 먼저 검증·커밋하세요.\n' >&2
  exit 1
fi

git remote get-url origin >/dev/null 2>&1 || {
  printf 'FAIL: origin remote가 없습니다. 먼저 GitHub 저장소를 연결하세요.\n' >&2
  exit 1
}

branch="$(git branch --show-current)"
if [[ -z "$branch" ]]; then
  printf 'FAIL: detached HEAD에서는 원격 동기화를 수행하지 않습니다.\n' >&2
  exit 1
fi

git fetch --prune origin "$branch"
git pull --ff-only origin "$branch"

printf 'PASS: origin/%s와 fast-forward-only 동기화를 완료했습니다.\n' "$branch"
