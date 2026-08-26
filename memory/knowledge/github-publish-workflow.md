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

## 현재 저장소의 HTTPS/SSH 게시 경로 — observed 2026-08-26

- Claim: 이 checkout의 origin은 공개 HTTPS이며 read-only fetch/ls-remote는 성공하지만 HTTPS push는 username credential 부재로 실패했다. 기존 repo 전용 SSH host alias를 이용해 동일 소유자/저장소의 main에 일반 push가 성공했다. 원격 URL이나 전역 설정을 바꿀 필요가 없었다.
- Sources: ignored `artifacts/phase-09-console-push.log`, `phase-09-console-push-ssh.log`, `phase-09-console-pull.log`; 실제 commit `eb9aad9f043ebd749e67c695c0e447755c2fafda`의 로컬/무인증 HTTPS 원격 SHA 일치.
- Sample/limits: 현재 저장소/호스트1개. 기존 SSH 설정의 HostName/User/IdentityFile 참조만 확인했고 개인 키 내용은 열람하지 않았다. 다른 clone 사용자는 자기 인증을 준비해야 하며 이 host alias/키를 배포 기본값에 넣지 않는다. 위의 최초 준비 당시 미게시 상태를 현재 checkout에 한해 갱신한다.
