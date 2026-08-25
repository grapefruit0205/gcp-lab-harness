# SESSION LOG — append, dated

One short section per working session: what was worked on, what was decided (with D-### links), what's pending. When context resets, this file is the recovery path — write it for the next session's reader.

---

## 2026-08-25

- Project initialized with the ballast memory structure (D-001)
- D-002~D-004에 따라 15개 실습 자동화, Ubuntu/VS Code Codex 역할 분리, Phase별 한국어 Git 이력을 설계했다.
- 로컬 CLI를 확인했다: Codex·Git·jq·Bash는 설치, gcloud·Terraform·GitHub CLI는 미설치 상태다.
- 공식 Codex·Google Cloud·GitHub 문서로 실행 계약, 인증, Terraform, Marketplace, Billing, push 가드레일을 확인했다.
- 12개 Phase 구조, 아키텍처, handoff prompt와 공통 보호 스크립트를 작성 중이다.
- D-005: 검증 환경을 VS Code 통합 터미널 CLI가 아니라 VS Code Codex Extension으로 정정했다. CLI review는 보조 gate로 내렸다.
- D-006: 실습용 Google Cloud 계정·프로젝트 연동을 설계 범위에 포함했다.
- D-007: 검증은 VS Code Codex Extension에서만 수행하도록 재확정하고 별도 CLI reviewer 경로를 제거했다.
- D-008: 단일 run-all이 Lab 01–15를 순차 실행하고 각 단계에서 Extension 사용자 승인 후 cleanup·commit·push·다음 단계로 진행하도록 확정했다.
- 공식 Google Cloud Monitoring/Logging remote MCP endpoint와 Codex의 remote MCP 지원을 확인하고 read-only verifier 설계를 추가했다.
- 로컬 `code` CLI 1.134.0을 확인해 Extension handoff에서 workspace와 review prompt를 열도록 반영했다.
- D-009: 실행 도구를 Codex CLI/`code`가 아니라 Command Code CLI `cmd` 1.32.2로 정정했다. `cmd status`에서 사용자 계정 인증을 확인했고 모델 override를 금지했다.
- 원본 Lab 01–15를 실행 Phase 01–15와 1:1로 정리하고 원본의 모든 Task를 각 Phase coverage 표에 매핑했다.
- `bin/gcp-lab-harness`와 `scripts/run-all.sh`의 안전한 단일 진입점, Command Code handoff, Extension 승인 gate, cleanup·한국어 commit·push 상태 계약을 문서화했다.
- 정리된 원본 Markdown·이미지 28개를 `references/google-cloud-labs-ko/`에 보존했다.
- 최소 검사에서 Phase 15개·연속 번호·필수 heading·모델 override 부재·JSON·Bash·whitespace와 `run-all --dry-run`을 확인했다.
- 실제 GCP adapter, account 통합 실행, GitHub remote/push는 수행하지 않았다.
- D-010: GitHub 저장소 생성과 Phase 시작 전 pull 동기화를 추가했다. 안전한 구현은 clean working tree에서 `git pull --ff-only`만 허용한다.
- 사용자 소유 기존 로컬 저장소 세 곳에서 동일한 Git 작성자 설정을 확인해 이 저장소의 local author 설정 근거로 사용한다.
- 설계 전체를 로컬 `main`의 한국어 root commit `설계: Google Cloud 15단계 자동화 하네스 구성`으로 기록했다.
- D-011: `grapefruit0205/gcp-lab-harness` private GitHub 저장소를 빈 상태로 생성하고 로컬 `origin`을 연결했다.
- 기존 Mywiki key와 충돌하지 않는 repo 전용 ed25519 deploy key와 SSH host alias를 로컬에 준비했다. write 권한 등록은 사용자 action-time 승인 대기다.
