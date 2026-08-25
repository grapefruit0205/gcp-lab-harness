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
- 사용자 승인과 GitHub 이메일 sudo 인증 후 repo 전용 deploy key를 Read/write로 등록했다.
- 로컬 `main` 두 커밋을 `origin/main`에 최초 push하고 local/remote SHA 일치 및 실제 `git pull --ff-only` 성공을 확인했다.
- Foundation B 상태·승인 컨트롤러를 구현했다. 15개 Phase cursor, 허용 상태 전이, atomic JSON, Extension 승인 hash 결합, 반려와 resume next-action을 포함한다.
- 로컬 offline fixture에서 금지 전이와 stale approval이 거부되고 승인·반려·재개가 동작하는 것을 관찰했다. 설계 검사와 15단계 dry-run도 다시 통과했다.
- 실제 Cloud adapter, foreground `run-all` 자동 연결, GCP 계정 통합은 계속 미구현이며 Cloud 명령은 실행하지 않았다.
- D-012에 따라 예산 한도를 필수 gate에서 제거하고 프로젝트 allowlist·plan 승인·수량·timeout·cleanup 보호를 유지했다.
- 공식 archive와 SHA lock으로 사용자 영역에 gcloud 581.0.0과 Terraform 1.15.8을 설치하고, Google 사용자 로그인과 Terraform ADC를 연동했다.
- 유일하게 조회된 ACTIVE 프로젝트를 로컬 exact allowlist로 구성하고 billing preflight를 통과했다. 실제 apply 대상으로 사용하는 해석은 A-003으로 등록했다.
- `hashicorp/google` 7.45.0으로 실제 프로젝트 data source를 읽는 refresh-only plan을 통과했다. 첫 schema 가정 실패를 수정했으며 Cloud resource apply는 아직 하지 않았다.
- D-013에 따라 `kdt5-05`용 단일 custom-mode VPC canary adapter를 만들고 `canary001` 저장 plan을 생성했다. 결과는 create 1·change 0·destroy 0이며 실제 apply는 승인 전이라 실행하지 않았다.
- D-014에 따라 공개 clone 후 도구 설치·GCP 인증·preflight·Terraform 연결을 실행하는 bootstrap 스크립트와 README 명령을 추가했다.
- D-015에 따라 GitHub 저장소를 public으로 전환했고 코드와 커밋 이력을 누구나 열람·clone할 수 있는 상태를 확인했다.
