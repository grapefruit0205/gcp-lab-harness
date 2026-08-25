# Checkpoint — Google Cloud 실습 자동화 하네스 설계 — 2026-08-25 11:18

## The story so far

한국어 Google Cloud 실습 15개를 Ubuntu Bash와 Codex CLI로 실행하고 VS Code의 Codex 환경에서 검증하는 자동화 하네스를 설계 중이다. 로컬 Git 저장소와 ballast 메모리 구조를 만들었고, 사용자 확정 사항 D-002~D-004와 미정 사항 Q-001~Q-003을 기록했다. 공식 Codex·Google Cloud·GitHub 문서를 바탕으로 Phase 문서, handoff 프로토콜, 안전 가드레일을 작성하는 단계다.

## Decided

- D-002: 15개 Google Cloud 실습을 Phase별 CLI 자동화 하네스로 만든다.
- D-003: Ubuntu Bash/Codex 실행과 VS Code Codex 검증을 분리한다.
- D-004: Phase 완료마다 한국어 커밋과 GitHub 푸시를 남긴다.

## Waiting on the user

- Q-001: GitHub 저장소 이름과 공개 범위가 필요하다.
- Q-002: 실행 대상 Google Cloud 프로젝트·결제 계정·예산 한도가 필요하다.
- Q-003: 저장소 라이선스가 필요하다.
- A-001: 확정 전까지 로컬 저장소 이름을 `gcp-lab-harness`로 가정한다.

## Next first action

로컬 Codex·gcloud·Terraform·GitHub CLI 버전을 확인하고 공식 문서 근거를 `memory/knowledge/`에 기록한다.

## Tried

- 실패한 접근 없음.
