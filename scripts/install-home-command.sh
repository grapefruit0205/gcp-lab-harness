#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
install_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
launcher="$install_dir/gcp-lab-harness"

mkdir -p "$install_dir"
ln -sfn "$repo_root/bin/gcp-lab-harness" "$launcher"

printf 'PASS: 사용자 명령을 설치했습니다: %s\n' "$launcher"
case ":$PATH:" in
  *":$install_dir:"*) ;;
  *)
    printf '현재 shell에서 바로 사용하려면 다음을 한 번 실행하세요.\n'
    printf '  export PATH="%s:$PATH"\n' "$install_dir"
    ;;
esac
