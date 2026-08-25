# OPEN QUESTIONS — registered, not remembered

Rule: anything unresolved gets a row here the moment it surfaces. A question is closed only by linking the decision (or finding) that resolved it — never by silently disappearing.

| ID | Question | Opened | Status |
|---|---|---|---|
| Q-001 | GitHub 저장소 이름과 공개 범위(public/private)는 무엇으로 할까? | 2026-08-25 | closed — D-015 |
| Q-002 | 자동화 실행에 사용할 Google Cloud 프로젝트와 연결된 결제 계정은 무엇인가? | 2026-08-25 | observed — 유일한 ACTIVE project와 billing 연결 확인, 실제 apply 대상 확정은 A-003 |
| Q-003 | 공유 저장소에 적용할 라이선스는 무엇인가? | 2026-08-25 | open |
| Q-004 | 제안한 `codex-extension-verifier` 프로젝트 pin을 ballast 규칙 카탈로그에 기록할까? | 2026-08-25 | closed — D-007 및 `.claude/ballast.rules.json` |
| Q-005 | 제안한 `command-code-runner-fixed-model` 프로젝트 pin을 ballast 규칙 카탈로그에 기록할까? | 2026-08-25 | open |
| Q-006 | 로컬·GitHub 커밋에 사용할 Git 작성자 이름과 이메일은 무엇인가? | 2026-08-25 | closed — 사용자 소유 기존 로컬 저장소 3곳의 일치 설정 사용 |

## Readings in force — assumed, not decided

Rule: when work proceeds on a reading the user never confirmed (silence, a subject change, an "ok" that could mean anything), it is registered here with the user's words quoted — never in DECISIONS.md. One-way-door actions wait while a row is open. A row closes into a `D-` entry on confirmation, or is dropped — and what was built on it swept — on contradiction. (Protocol: ballast decision-ledger skill, *Provisional readings*.)

| ID | User's words (verbatim) | Our reading (`assumed`) | Breaks if wrong | Ends when | Relied on in |
|---|---|---|---|---|---|
| A-001 | "repo 를 만들고 git 에 각 과정이 완료될때마다 commit" — 2026-08-25 | 로컬 저장소 이름은 임시로 `gcp-lab-harness`를 사용한다 | 사용자가 원하는 최종 GitHub 저장소명과 다를 수 있다 | closed — D-011 | 로컬 저장소 및 설계 문서 |
| A-002 | "gcp monitoring이랑 logging mcp 도 필요하지?" — 2026-08-25 | 공식 Cloud Monitoring·Logging remote MCP를 VS Code Codex Extension의 read-only 보조 검증 계층으로 포함한다 | 사용자가 local observability MCP 또는 MCP 미사용을 원할 수 있다 | MCP 실제 등록 직전 | MCP 연동 설계와 Phase 04·07·11·13 검증 |
| A-003 | "gcp 계정 연동으로 cloud apply 하는 것이 목적이야" — 2026-08-25 | 로그인 후 유일하게 조회된 ACTIVE 프로젝트 `kdt5-05`를 실습 apply 대상으로 사용한다 | 다른 프로젝트를 원하면 실제 Cloud 리소스를 잘못된 프로젝트에 만들 수 있다 | closed — D-013 | 전용 gcloud configuration, local allowlist, Terraform account-check |
