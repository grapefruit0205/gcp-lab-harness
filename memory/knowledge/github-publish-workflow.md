# GitHub 게시 워크플로

Checked: 2026-08-25

## Confirmed

- 로컬 저장소는 먼저 비밀정보를 제외하고 commit한 뒤 `gh repo create --source=. --public|--private --remote=origin --push`로 새 GitHub 저장소를 만들고 push할 수 있다.
- 현재 로컬에는 Git 2.43.0이 있지만 GitHub CLI는 설치되어 있지 않다.

## Evidence

- Official GitHub Docs: https://docs.github.com/en/migrations/importing-source-code/using-the-command-line-to-import-source-code/adding-locally-hosted-code-to-github
- Observed locally: `git --version` succeeded and `gh --version` returned command not found on 2026-08-25

## Limits

저장소 이름, 공개 범위, 로그인 계정이 확정되지 않아 GitHub 생성과 push는 실행하지 않았다.
