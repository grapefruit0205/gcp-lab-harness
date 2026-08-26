# PRODUCT TRUTH — gcp-lab-harness

Rule: every entry carries evidence (code path, test, screenshot), a date, and the date it was last checked against the code. External claims may be sourced **only** from the Implemented section. Re-confirm any entry checked more than 90 days ago before using it in a claim. Code states are never blended: implemented / wired / operational / verified (see the ballast proof-standard skill).

## Implemented

<!-- ## <capability> — <state: implemented|wired|operational|verified> — 2026-08-25
Evidence: <code path / test / screenshot>
Checked: 2026-08-25 — re-confirm against the code once this is over 90 days old -->

## 15개 Phase 설계와 원본 Task coverage — state: verified — 2026-08-25

Evidence: `docs/phases/phase-01-*.md`부터 `phase-15-*.md`, `references/google-cloud-labs-ko/`, `scripts/validate-design.sh`의 PASS
Checked: 2026-08-25 — 원본별 Task 수와 Phase coverage 행 수 일치, Google Cloud 계정에는 실행하지 않음

## Command Code·Extension handoff 골격 — state: implemented — 2026-08-25

Evidence: `scripts/handoff-execute.sh`, `scripts/prepare-extension-review.sh`, `prompts/phase-execute.md`, `prompts/phase-review.md`, `schemas/`
Checked: 2026-08-25 — Bash·정적 정책 검사 통과, 실제 GCP Phase handoff는 미실행

## 단일 실행 dry-run — state: verified — 2026-08-25

Evidence: `bin/gcp-lab-harness`, `scripts/run-all.sh`; `./scripts/run-all.sh --dry-run`이 Phase 01–15 순서를 출력하고 외부 변경 없이 종료
Checked: 2026-08-25

## Foundation B 상태·승인 컨트롤러 — state: verified — 2026-08-25

Evidence: `lib/harness/`, `schemas/pipeline-state.schema.json`, `tests/offline-controller.sh`; offline test PASS
Checked: 2026-08-25 — 15개 Phase 초기화, 허용/금지 전이, stale approval 거부, 승인·반려, resume를 확인했으며 Cloud에는 실행하지 않음

## Foundation A 도구·GCP 계정 preflight — state: verified — 2026-08-25

Evidence: `scripts/install-toolchain.sh`, `config/toolchain.lock.env`, `scripts/gcp-auth-login.sh`, `scripts/configure-gcp-project.sh`, `scripts/preflight-gcp.sh`; 설치 재실행과 실제 계정 preflight PASS
Checked: 2026-08-25 — gcloud 581.0.0, Terraform 1.15.8, 사용자 로그인·ADC, 단일 project allowlist와 billing 연결을 로컬에서 확인함. 실제 계정 식별자는 Git에 저장하지 않음

## Terraform Google provider 계정 연결 — state: verified — 2026-08-25

Evidence: `foundation/terraform/account-check/`, provider lock, `scripts/verify-terraform-gcp.sh`; provider 7.45.0 refresh-only plan PASS
Checked: 2026-08-25 — ADC로 허용 프로젝트 data source 조회에 성공했으며 Cloud resource apply는 하지 않음

## Phase 시작 전 fast-forward-only 동기화 보호 — state: verified — 2026-08-25

Evidence: `scripts/sync-before-phase.sh`, `scripts/validate-design.sh`; dirty tree 거부와 실제 `origin/main`의 `Already up to date` 결과
Checked: 2026-08-25 — local/remote SHA `6f0ca8e2d83b428cf8a6fc469e4c670f75186704` 일치 후 실행

## 로컬 Git 초기 커밋 — state: verified — 2026-08-25

Evidence: `git log -1 --format='%h %s'`가 한국어 root commit을 반환하고 working tree가 clean함
Checked: 2026-08-25 — GitHub `origin/main`에 포함됨

## GitHub public 저장소 — state: verified — 2026-08-25

Evidence: `https://github.com/grapefruit0205/gcp-lab-harness` 설정의 `This repository is currently public`, read/write deploy key, `git push`, 무인증 HTTPS `git ls-remote`, `git pull --ff-only`
Checked: 2026-08-25 — GitHub 공개 전환 확인, 공개 clone과 local/remote SHA 확인

## Foundation canary 저장 plan — state: verified — 2026-08-25

Evidence: `foundation/terraform/apply-canary/`, `scripts/foundation-canary.sh`; run `canary001` plan이 `google_compute_network` create 1·change 0·destroy 0과 SHA256 `2ed0c69f7a2bc7526b3206af08d385637c614a867c728a49d3dfd5546382ecea`를 출력
Checked: 2026-08-25 — `kdt5-05` allowlist와 저장 plan 정책 통과, 실제 apply는 미실행

## clone 후 Bash 사용자 명령 — state: verified — 2026-08-25

Evidence: `bootstrap.sh`, `scripts/install-home-command.sh`, symlink-safe `bin/gcp-lab-harness`; `$HOME/.local/bin/gcp-lab-harness phase list`가 Phase 01·15를 저장소 밖에서 출력
Checked: 2026-08-25 — 사용자 명령 설치와 `$HOME` 실행 경로 확인

## WSL 없는 Windows PowerShell 진입점 — state: wired — 2026-08-25

Evidence: `bootstrap.ps1`, `harness.ps1`, `scripts/bootstrap-windows.sh`, `scripts/windows-bin/python3`, `lib/harness/state.sh`
Checked: 2026-08-25 — PowerShell이 Git for Windows Bash로 같은 controller를 호출하고 pipeline lock은 `flock` 없이 동작한다. 현재 Linux 환경에는 PowerShell/Windows 런타임이 없어 실제 Windows 실행은 미검증

## Command Code 대화형 start·Extension review·next handoff — state: wired — 2026-08-25

Evidence: `scripts/start-command-code.sh`, `scripts/handoff-review.sh`, `scripts/prepare-extension-review.sh`, `scripts/handoff-next.sh`, `bin/gcp-lab-harness`
Checked: 2026-08-25 — state controller와 이름 있는 Command Code session, hash 결합 Extension prompt, 승인 후 session resume를 연결했으며 실제 15개 Phase Cloud E2E는 미실행

## Command Code 단일 모델 구현·자기 검증 선택 경로 — state: wired — 2026-08-25

Evidence: `prompts/single-model-phase.md`, `schemas/single-model-review.schema.json`, `scripts/single-model-phase.sh`, `scripts/prepare-single-model-review.sh`, `scripts/single-model-approve.sh`, `bin/gcp-lab-harness`; 격리 상태 root의 `single-model run --dry-run` PASS, 활성 Phase 04의 저장 plan·diff·evidence 세 hash 재검증 PASS
Checked: 2026-08-25 — 같은 현재 모델의 구현·검증 prompt, hash 결합 result, 사용자 승인 검사를 CLI에 연결함. 실제 Command Code Phase 자기 검증과 Cloud E2E는 미실행

## Phase repo 쉘 실행 허용 목록 — state: verified — 2026-08-25

Evidence: `scripts/configure-command-code-permissions.sh`; Phase 01–15 `execute.sh`·`verify.sh`의 직접·bash 실행 패턴을 `.commandcode/settings.json`에 병합하고 `defaultMode`는 `default`로 유지
Checked: 2026-08-25 — Phase 01–15 패턴을 idempotent하게 추가하며 전체 command auto-accept는 사용하지 않음

## Phase 07–15 Cloud adapter — state: implemented, cloud validation required — 2026-08-25

Evidence: `phases/07/`부터 `phases/15/`, `lib/harness/phase-adapter.sh`, `scripts/phase-contract.py`, `scripts/sanitize-terraform-plan.jq`, `tests/offline-phases-07-15.sh`, `docs/audits/phase-07-15-coverage.md`; Google provider 7.45.0 init/validate와 offline suite PASS
Checked: 2026-08-25 — IAM·Storage·SQL·BigQuery·Monitoring·HA VPN·ALB·ILB·Terraform의 원본 Task 계약과 실제 상태 verifier가 구현됨. 실제 Cloud apply, metric/routing/autoscaling 수렴, Extension 승인은 실행하지 않음

## plan-bundle·민감 plan 정제·artifact 상태 전이 — state: verified offline — 2026-08-25

Evidence: `schemas/action-plan.schema.json`, `schemas/phase-manifest.schema.json`, `lib/harness/phase-adapter.sh`, `scripts/sanitize-terraform-plan.jq`, `bin/gcp-lab-harness`, `tests/offline-phases-07-15.sh`; synthetic secret redaction과 offline transition test PASS
Checked: 2026-08-25 — binary plan과 imperative action hash를 결합하고 민감 mask를 적용한 JSON만 handoff하며 applied/verified/destroyed artifact 없이는 상태 전이를 거부함

## 실제 `run-all --run` supervisor 연결 — state: wired — 2026-08-25

Evidence: `bin/gcp-lab-harness`, `scripts/start-command-code.sh`, `scripts/handoff-review.sh`, `scripts/handoff-next.sh`; `run-all --dry-run`과 전체 offline suite PASS
Checked: 2026-08-25 — 단일 Command Code session과 Phase별 Extension 승인 대기를 연결했으나 Cloud 15-Phase foreground E2E는 미실행

## Phase 02 (Infrastructure Preview - Marketplace Jenkins) adapter — state: implemented, cloud revalidation required — 2026-08-25

Evidence: `phases/02/terraform/main.tf`, `phases/02/execute.sh`, `phases/02/verify.sh`, `tests/offline-phases-01-06.sh`; offline 계약 PASS
Checked: 2026-08-25 — 기존 검증은 Jenkins HTTP와 service stop/start를 확인하지 않아 `verified` 근거로 부족했다. IAP-only ingress, Marketplace boot-disk provenance, HTTP readiness와 stop/start 전이를 추가했으며 실제 Cloud 재검증은 아직 하지 않았다.

## Phase 04 (Private Google Access 및 Cloud NAT) adapter — state: implemented, cloud revalidation required — 2026-08-25

Evidence: `phases/04/terraform/main.tf`, `phases/04/execute.sh`, `phases/04/verify.sh`, `tests/offline-phases-01-06.sh`; offline 계약 PASS
Checked: 2026-08-25 — 기존 검증은 PGA·NAT·Logging 설정 존재만 확인했다. disabled control과 enabled VM의 실제 Storage/egress 차이, NAT log 조회를 추가했으며 실제 Cloud 재검증은 아직 하지 않았다.

## Phase 05 (Creating Virtual Machines) adapter — state: implemented, cloud revalidation required — 2026-08-25

Evidence: `phases/05/terraform/main.tf`, `phases/05/execute.sh`, `phases/05/verify.sh`, `tests/offline-phases-01-06.sh`; 과거 리소스 create/destroy와 현재 offline 계약 PASS
Checked: 2026-08-25 — 과거 canary는 VM 사양과 cleanup은 확인했지만 Linux/custom SSH·guest 사양과 Windows guest agent/RDP readiness를 확인하지 않았다. IAP-only ingress와 guest evidence를 추가했으며 개정 adapter의 Cloud 재검증은 아직 하지 않았다.

## Phase 06 (Working with Virtual Machines) adapter — state: implemented, cloud revalidation required — 2026-08-25

Evidence: `phases/06/terraform/main.tf`, `phases/06/execute.sh`, `phases/06/verify.sh`, `tests/test-phase-06.sh`; 개정 offline 계약 PASS, 과거 run 리소스 destroy와 잔여 0 확인
Checked: 2026-08-25 — 과거 Cloud run은 리소스 존재만 확인해 guest mount·application·backup·maintenance 완료 증거로 무효다. 개정 verifier의 실제 Cloud 재검증은 아직 하지 않음

## Phase 07 실제 사용자 두 계정 경로 — state: implemented, verified offline — 2026-08-26

Evidence: `phases/07/auth.sh`, `auth.py`, `execute.sh`, `support.sh`, `iam-probe.py`, `verify.sh`, `terraform/main.tf`, `tests/test-phase-07.py`; Python 회귀 47개와 Terraform mock 8개 PASS. 실제 User1의 OAuth userinfo identity와 프로젝트 관리자/IAP 권한 확인 성공, User2 미로그인을 명시적으로 거부함.
Checked: 2026-08-26 — D-024에 따라 실제 User1/User2 계정과 VM workload SA 하나로 변경했다. 계정은 명시적 `--account`로 선택하고 실제 OAuth identity를 검사한다. 기존 User2 권한을 자동 회수하지 않으며 프로젝트 수준 Viewer/Object Viewer 전이와 workload Viewer→Creator를 코드에 연결했다. 계정2 브라우저 인증·새 plan·새 Cloud E2E는 미수행이다. 원문의 콘솔 UI/Qwiklabs 계정 lifecycle/가상 domain grant를 수행했다는 뜻이 아니다. 개인정보 설정은 `.gitignore`와 mode600으로 Git에서 제외한다.

## Phase 07 사용자별 계정 등록 진입점 — state: implemented, verified offline — 2026-08-26

Evidence: `phases/07/auth.py`, `auth.sh`, `execute.sh`, `bin/gcp-lab-harness`, `tests/test-phase-07.py`; Python 73 tests PASS (`artifacts/phase-07-account-setup-unit.log`).
Checked: 2026-08-26 — D-025에 따라 `accounts setup`에서 이메일 두 개를 입력·교체하고 원자적으로 로컬 설정을 저장한다. 기존 로그인 재사용, 필요한 사용자만 `gcloud auth login --no-activate`, 로그인 후 실제 OAuth identity 재검사를 연결했다. plan은 터미널이면 설정/로그인을 이어가고 비대화형이면 명시적 준비 안내로 중단한다. 입력 취소/잘못된 계정/손상 설정/저장 실패/인증 override를 회귀 검사했다. 격리된 복사본의 실제 CLI 등록·계정 교체·비대화형 중단과 Linux PTY Enter 기본값 재사용도 통과했다. OAuth 자체는 mock 범위의 검증이며 새 User2 실제 로그인·Cloud E2E와 Windows 실기동은 미수행이다. Google 계정 자체를 생성하거나 setup 단계에서 프로젝트 IAM을 바꾸지 않는다. apply 이후의 IAM 전이는 기존 승인된 action plan 흐름이다.

## Phase 07 Notion 본문·clone 사용자 기준 — state: implemented, verified offline — 2026-08-26

Evidence: `phases/07/execute.sh`, `verify.sh`, `support.sh`, `iam-probe.py`, `plan-guard.py`, `terraform/main.tf`, `tests/test-phase-07.py`; Python 84 tests와 Terraform mock 8 tests PASS (`artifacts/phase-07-notion-unit.log`, `phase-07-notion-mock.log`). 기준은 사용자 지정 Notion 페이지 `3c76d458853781ecbcf3d1c5e12f28dd`의 2026-08-26 본문이다.
Checked: 2026-08-26 — D-026에 따라 관리자 A의 VM 생성 대체 경로를 제거했다. Terraform 8개 baseline 이후 B의 workload-only actAs·project Compute Instance Admin을 임시 부여하고 B OAuth로 생성, operation actor와 RUNNING/private/workload identity를 검증한다. Viewer 회수 후 sample 읽기 거부, VM Creator 전환 후 쓰기 성공/읽기 거부, B의 4개 임시 역할 회수와 관리자 보존을 연결했다. `lab_completion.complete=false`로 최종 destroy 전에는 Notion 전체 종료 완료를 주장하지 않는다. D-027에 따라 개인 설정이 Git 추적 대상이 아닌지와 새 clone 사용자의 계정 입력/활성 계정 기본값을 회귀 검사했다. 마지막 읽기 전용 `accounts check`에서 실제 A/B OAuth userinfo identity 둘 다 verified=true를 확인했다(`artifacts/phase-07-notion-auth-check.log`). 브라우저 로그인 조작을 대신 수행한 것은 아니며 새 Cloud apply/E2E와 Windows 로그인은 미검증이다.

직전 구현의 추가 관측(2026-08-26): 실제 두 사용자 권한·정책 preflight 및 run `p07-260826-b53c` 저장 plan이 통과했다. Terraform create 8/change 0/destroy 0이며 `artifacts/phase-07-notion-plan.log`와 해당 run manifest가 근거다. 현재 planned이며 새 apply/Cloud E2E는 미수행이다.

## Phase 08 Cloud Storage 보완 — state: implemented, verified offline — 2026-08-26

Evidence: `phases/08/{execute.sh,verify.sh,support.sh,storage_lab.py,fixture.html}`, `phases/08/terraform/main.tf`, `tests/test-phase-08.py`, `tests/test-phase-08.sh`, Terraform `tests/storage.tftest.hcl`. 최초 Python40/Terraform mock4/provider mock JSON plan3/gate PASS. 실제 실행 후 non-JSON 오류 대응 회귀를 포함해 Python44 tests PASS.

Checked: 원본 Lab 08 Task 1–8을 보존하고 region bucket/ACL/CSEK rewrite/31일 lifecycle/3세대 로컬 복구/recursive rsync 경로를 보완했다. fake API 전체 흐름, 공개 grant 응답 유실 후 회수, CSEK 정확한 HTTP reason, 구키/신키 성공·거부 matrix와 metadata, 암호화 모든 세대 삭제, pagination 실패, 개별 sync hash, actor/input/code hash drift, 실제 Bash verify 실패→destroy 및 잔여 검사 실패→cleanup_required를 오프라인 검사했다. OAuth token/CSEK는 파일·argv에 기록하지 않고 HTTP 예외 원문을 출력하지 않는 구현이다. 실제 Google 응답·정책·CSEK 수렴/Cloud apply·verify·destroy·Windows 실기동은 미검증이다. 공개 ACL이 조직 PAP로 막히면 성공 실습을 했다고 주장하지 않고 policy-prevented 경계와 risk를 기록한다. 자동화에서는 공개 가능한 자체 고정 HTML fixture, 메모리 API 키, Terraform 선적용 정책, 전용 bucket soft-delete=0을 사용하며 원문 콘솔/외부 HTML/YAML 키 보관과의 차이를 문서화한다. 강제 프로세스 종료·OS swap·메모리 완전 소거까지 보장한다는 뜻은 아니다.

후속 observed(2026-08-26, n=1): D-030의 run `p08-260826-8c1d`는 실제 Terraform 1 added/0 changed/0 destroyed 및 bucket policy readback에 성공했다. verifier는 HTTP401로 실패했고 자동 destroy 1개·빈 state·활성/soft-deleted bucket0까지 확인했다. 근거는 ignored `artifacts/phase-08-cloud-{apply,verify}.log`, 해당 run의 `verification-cleanup.log`, `evidence/phase-08-destroyed.json`이다. 전체 실습 성공은 아니다. 원래 로그에 오류 body 형식/Task가 없어 해당401이 어느 요청의 응답인지는 단정하지 않는다. 읽기 전용 재현에서 alt=media의404가 일반 텍스트임을 관측해 JSON-only 오류 가정을 제거했다. 익명401/403은 같은 generation의 인증 GET 전후 성공과 함께만 인정하고, media CSEK400의 reason이 없으면 같은 generation·키의 checksum metadata가 정확한 CSEK reason으로 거부되는지 추가 검사한다. 수정 코드는 오프라인만 통과했으며 새 계획의 Cloud 재검증 대기다.

## Not implemented

<!-- Listed explicitly so absence is a fact, not a gap. Copy must not claim these.
Checked: 2026-08-25 — this section goes stale in the other direction: a line left here after the
capability shipped makes you claim less than you have earned. Sweep it on the same 90-day clock. -->

- 실제 canary Cloud apply·verify·destroy 성공
- Google Cloud 계정 통합 테스트
- 전체 15개 Lab E2E 실행
- 실제 Phase의 Command Code 단일 모델 구현·자기 검증 E2E
- Phase 07 실제 두 사용자 경로의 Cloud 통합 검증, Phase 08 전체 실습 성공(첫 apply/실패 cleanup만 관측), Phase 09–15 실제 Cloud apply·machine verify·destroy
- Monitoring·Logging MCP 실제 OAuth/IAM 연결과 Extension 교차 검증
- WSL 없는 Windows PowerShell wrapper 실제 Windows 실행 검증

## Permanently excluded

<!-- Decided against. Copy must never imply these. Link the ledger decision: D-### -->
