#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "${1:-}" != "--confirm" || "$#" -ne 1 ]]; then
  printf '외부 push를 승인하려면 정확히 %s --confirm 을 실행하세요.\n' "$0" >&2
  exit 2
fi

git rev-parse --verify HEAD >/dev/null
git remote get-url origin >/dev/null 2>&1 || {
  printf 'origin remote가 없습니다. 먼저 GitHub 저장소를 연결하세요.\n' >&2
  exit 1
}

branch="$(git branch --show-current)"
if [[ -z "$branch" ]]; then
  printf 'detached HEAD에서는 push하지 않습니다.\n' >&2
  exit 1
fi

git push --set-upstream origin "$branch"
