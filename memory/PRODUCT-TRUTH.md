# PRODUCT TRUTH — gcp-lab-harness

Rule: every entry carries evidence (code path, test, screenshot), a date, and the date it was last checked against the code. External claims may be sourced **only** from the Implemented section. Re-confirm any entry checked more than 90 days ago before using it in a claim. Code states are never blended: implemented / wired / operational / verified (see the ballast proof-standard skill).

## Implemented

## Phase10–15 재감사와 Task 하위 항목 안내 — state: implemented, verified offline (부분) — 2026-08-26

Evidence: `lib/harness/{safe-adapter.sh,advanced.py}`, `phases/10/billing.py`, `phases/11/monitoring.py`, `phases/12/vpn.py`, Phase10–15 execute/verify/Terraform, `tests/test-phases-10-15.py`, `docs/console/phase-01.md`~`15.md`, `scripts/console-checks.py`, `tests/test-console-checks.py`.

Checked(observed, 2026-08-26): 최종40개 로컬 회귀 검사와13개 상세 안내 검사가 통과했다. 새 보존 어댑터·동일 state replan·현재 계정/source/input/work/state/binary/action 결합, API pagination·403/404 구분, BigQuery job/전체 행 수/sample 조건, Monitoring 정확한 VM 조건·group·chart·최신 uptime true, VPN 단계 재개·manual-boundary 상태 전이, ALB 리전별 health·IPv6 분기·bounded unit, ILB NAT 의존성과 HTTP 실패/Client IP, Terraform managed/data 주소 분리를 검사했다. 최초31개/12개 검사에서 추가 회귀로 확장했으며, 하위 제목 수177은 Task 밖 제목 포함 집계였으므로 원문 Task 안의167개로 정정한다. 상세 안내는90개 Task·221개 확인 항목이다. 실제 Cloud apply/수렴/통신·새 Git 게시·콘솔 UI 클릭 성공은 이번 증거가 아니다.

현재한계(후속보완반영): Phase13 builder는동일state보존복구를위해중지유지하고삭제는미수행이다. reset자동기동·RATE50/UTILIZATION80·세번째region부하는아래후속보완으로구현했다. min1/max2는원문과같으며이전축소규모설명은오류였다. marker2개만으로두리전분산자체가입증되지는않는다. Phase11이메일/UI·Phase12 Task8최종destroy는수동경계다. Phase10은전체golden정답비교가아닌행수/schema·job통계/sample의미검사다. Phase01–09 Cloud코드는바꾸지않았으며자동비용중지는없다.

후속 최종 observed(2026-08-26, 로컬 작업1회): `make test-offline`·`tests/test-phases-10-15.sh`·Phase10–15 각 gate 모두exit0이다.40개 회귀/13개 안내/6개 TF mock, Phase09 기존70개 검사도 통과했다. ignored `artifacts/phase10-15-{full-offline,local-tests,gates}.log`, `phase09-regression-after-10-15.log`가 근거다. 독립 리허설2차는34문서107개 링크 누락0·차단0이었다. 비차단 네 문구를 수정하고 안내를 재검사했다. 원문·Phase08/09·기존 공통4개 lib에는 diff가 없으며 Cloud/Git 게시를 수행하지 않았다.

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

## Phase 08 Cloud Storage 보완 — state: implemented, verified offline + Cloud machine(n=1), 최종 destroy 대기 — 2026-08-26

Evidence: `phases/08/{execute.sh,verify.sh,support.sh,storage_lab.py,fixture.html}`, `phases/08/terraform/main.tf`, `tests/test-phase-08.py`, `tests/test-phase-08.sh`, Terraform `tests/storage.tftest.hcl`. 최초 Python40/Terraform mock4/provider mock JSON plan3/gate PASS. 실제 실행 후 non-JSON 오류 대응 회귀를 포함해 Python44 tests PASS.

최초 오프라인 Checked: 원본 Lab 08 Task 1–8을 보존하고 region bucket/ACL/CSEK rewrite/31일 lifecycle/3세대 로컬 복구/recursive rsync 경로를 보완했다. fake API 전체 흐름, 공개 grant 응답 유실 후 회수, CSEK 정확한 HTTP reason, 구키/신키 성공·거부 matrix와 metadata, 암호화 모든 세대 삭제, pagination 실패, 개별 sync hash, actor/input/code hash drift, 실제 Bash verify 실패→destroy 및 잔여 검사 실패→cleanup_required를 오프라인 검사했다. OAuth token/CSEK는 파일·argv에 기록하지 않고 HTTP 예외 원문을 출력하지 않는 구현이다. 최초에는 실제 Google 응답·Cloud 실행·Windows 실기동을 검증하지 않았으며 후속 Cloud 관측은 아래에 구분한다. 공개 ACL이 조직 PAP로 막히면 성공 실습을 했다고 주장하지 않고 policy-prevented 경계와 risk를 기록한다. 자동화에서는 공개 가능한 자체 고정 HTML fixture, 메모리 API 키, Terraform 선적용 정책, 전용 bucket soft-delete=0을 사용하며 원문 콘솔/외부 HTML/YAML 키 보관과의 차이를 문서화한다. 강제 프로세스 종료·OS swap·메모리 완전 소거까지 보장한다는 뜻은 아니다.

후속 observed(2026-08-26, n=1): D-030의 run `p08-260826-8c1d`는 실제 Terraform 1 added/0 changed/0 destroyed 및 bucket policy readback에 성공했다. verifier는 HTTP401로 실패했고 자동 destroy 1개·빈 state·활성/soft-deleted bucket0까지 확인했다. 근거는 ignored `artifacts/phase-08-cloud-{apply,verify}.log`, 해당 run의 `verification-cleanup.log`, `evidence/phase-08-destroyed.json`이다. 전체 실습 성공은 아니다. 원래 로그에 오류 body 형식/Task가 없어 해당401이 어느 요청의 응답인지는 단정하지 않는다. 읽기 전용 재현에서 alt=media의404가 일반 텍스트임을 관측해 JSON-only 오류 가정을 제거했다. 익명401/403은 같은 generation의 인증 GET 전후 성공과 함께만 인정하고, media CSEK400의 reason이 없으면 같은 generation·키의 checksum metadata가 정확한 CSEK reason으로 거부되는지 추가 검사한다. 수정 코드는 오프라인만 통과했으며 새 계획의 Cloud 재검증 대기다.

재실행 observed(2026-08-26 15:35 KST, 성공 n=1): D-031의 run `p08-260826-c924`는 승인 bundle SHA `1222d79e290b309f117390ff457b5da1aa2577fef1a30bec32aa770ef575450a`로 1 added/0 changed/0 destroyed 후 실제 Cloud machine verification을 통과했다. manifest verified, Task1–8 passed, public_acl=created-tested-revoked, 암호화 세대 잔여0, 원본 복구3세대·sync2개 hash 일치, risks0이다. 별도의 읽기 전용 gcloud 재조회에서도 총5개 객체 세대(setup3+sync2), 공개 객체 ACL0·공개 bucket IAM0, 암호화 객체0과 bucket 생성 identity/정책·Terraform bucket state1을 대조했다. gcloud와 JSON API의 생성 시각 문자열 표현 차이는 같은 UTC 시각으로 정규화해 비교했다. 증거: ignored `artifacts/phase-08-reapply-{local-tests,gate,cloud,verify}.log`, 해당 run의 `evidence/phase-08-machine.json`·`phase-08-postverify-audit.json`, `artifacts/phase-08-postverify-{objects,bucket,bucket-iam}.json`. 성공 후 bucket 전체 destroy는 승인 범위가 아니므로 수행하지 않았다. bucket1은 유지되며 lab_completion.complete=false/destroy_pending=true다. 실제31일 경과 삭제·Windows 실행·전체15Lab 성공은 이 결과에 포함하지 않는다.

## Phase 09 Cloud SQL 실행 보완 — state: implemented, verified offline, Cloud 실습 실패·일부 정리 대기 — 2026-08-26

Evidence: `phases/09/{execute.sh,verify.sh,support.sh,sql_lab.py,guest_install.py,assets.json}`, `phases/09/terraform/main.tf`, `tests/test-phase-09.py`, `tests/test-phase-09.sh`, `phases/09/terraform/tests/sql.tftest.hcl`. `artifacts/phase-09-local-tests.log`와 `artifacts/phase-09-recreate-local-tests.log`의 Python/TF validate/mock·JSON plan guard 결과.

Checked: 2026-08-26 — 원본 Task1–6에 맞춰 MySQL8 Enterprise 1vCPU/3.75GB·10GB SSD, 전용 VPC/PSA, e2-micro VM2와 API3개를 포함한 Terraform 16개 create-only 구성을 구현했다. 현재 실행자 OAuth·allowlist, client 공개 IPv4 /32, 공식 artifact 고정 URL/hash, 코드·입력·승인 bundle, Terraform state·Cloud identity guard를 추가했다. 원문 default network 대신 전용 VPC를 사용한다. `--quiet`와 비밀번호 프롬프트 충돌을 없애고 SQL users API의 비동기 operation 완료를 검사한다. apply 후 root 난수 초기화, verify 때 메모리 난수 재설정, guest stdin/0640 wp-config와 wp-cli 관리자 stdin 설치를 연결했다. SQL은 WordPress DB 연결의 wp eval로 질의하고 두 frontend의 HTTP200 본문·DB marker를 비교한다. redirects/권한 오류를 성공·부재로 처리하지 않는다.

관측 범위: Python33·Terraform mock3/JSON guard2·Phase09 gate·Phase07–15 suite가 통과했다. fake API 전체 경로·실제 격리 Bash 실패→cleanup·PSA 실패/조회 실패→cleanup_required·secret 전달·source/input drift를 검사했다. 실제 Cloud apply·게스트 PHP 실행·SQL/HTTP E2E·Windows 실행은 아직 미검증이다. SQL API 미활성 상태에서는 SQL inventory/quota를 미리 완전히 조회하지 못한다. 정상 verify 후 리소스를 유지하며 자동 만료/비용 중지는 없다. guest DB 비밀번호는 최종 VM/disk destroy까지 유지된다. 삭제 후 SQL producer의 PSA 해제가 최대4일 걸릴 수 있으며 실패를 숨기지 않고 state/cleanup_required를 보존한다. `sqladmin`, `servicenetworking`, `iap` API는 destroy 후에도 활성 상태로 유지하도록 설계했다.

실제 계획 observed(2026-08-26): run `p09-260826-5d82`의 계정·API/이름 충돌·IAM/Compute quota·artifact preflight와 Terraform plan을 통과했다. create16/change0/destroy0, SQL1/VM2, 제한 HTTP IPv4 /32이며 bundle SHA `d418a5b7ed219126889882f2e1e296b1e34dcea26b256dc329774119fb561cf4`다. source/input/action/bundle/binary hash·manifest/action schema를 별도 재검사했다. manifest는 planned이고 actual Cloud apply·API 활성화는 하지 않았다. 근거는 ignored `artifacts/phase-09-plan.log`와 해당 run의 plan·manifest다.

후속 apply observed(2026-08-26 16:13 KST, n=1): D-033의 동일 run/exact bundle로 Terraform16added/0changed/0destroyed 및 after-apply Cloud identity·SQL API root 초기화가 exit0으로 완료됐다. manifest applied, `database-initialized.json`의 root_password_initialized=true/password_persisted=false를 확인했다. 이어 machine verify를 실행 중이며 아직 SQL·WordPress E2E 성공 판정은 아니다. 근거는 ignored `artifacts/phase-09-cloud-apply.log`, 해당 run의 identity·초기화 기록이다. 정상 완료 뒤 전체 destroy는 별도다.

후속 실패/정리 observed(2026-08-26 16:21 KST, n=1): 실제 verify는 root 비밀번호 API 갱신 후 guest readiness/WordPress config 단계의 CLI 오류로 실패했다. 두 VM startup 정상 종료와 현재 사용자의 OS Login/Admin·IAP·actAs 권한을 읽기 전용 확인했으나 세부 guest stderr를 보관하지 않아 정확한 설치 실패 원인은 unknown이다. 자동 cleanup으로 VM2/boot disk2/SQL1·DB·subnet·firewall2·SA2/관련 IAM은 삭제됐다. PSA 삭제는 producer가 사용 중이라는 Error9로 거부됐다. 별도 실제 inventory/state/identity/IAM 재조회에서 VM/disk/SQL/subnet/firewall/SA와 run IAM은0, 전용 VPC1/PSA range1/ACTIVE connection1 잔여를 확인했다. 공통 API3개는 승인된 유지 대상이다. state6개(전용3+API3)를 보존하고 manifest cleanup_required/cleanup failed/remaining3으로 기록했다. 증거는 ignored `artifacts/phase-09-cloud-verify.log`, run의 `verification-cleanup.log`, `evidence/phase-09-postfailure-audit.json`이다. 전체 실습 성공·정리 완료·비용0이 아니며 실패 원인을 추정 수정하거나 새 Cloud 생성은 하지 않았다.

재생성 준비 observed/implemented(2026-08-26): D-034에 따라 기존 승인 소스를 ignored `artifacts/approved-code/phase09-5d82`에 보존하고 원래 state/lock을 공유하도록 했다. source hash 검증 후 같은 승인 범위 destroy를 재시도했으나 PSA Error9가 지속됐다. 기존 PHP CLI 누락 가설은 startup 로그의 php8.2-cli 설치·mysqli 로드로 반증됐다. 새 guest installer는 PHP·설정 lint·실제 mysqli SELECT1 readiness(120초 한도)·WP-CLI·core install/is-installed를 구분하고 허용된 stage/reason/exit_code만 로컬 evidence에 남긴다. PHP DB 검사 비밀번호와 관리자 비밀번호는 child stdin으로 전달한다. 실패 원문/예외/추가 필드를 진단 파일로 전달하지 않는 테스트, 임시 경로 실제 config 생성·권한·덮어쓰기 거부, child 실행 mock·DB 재시도·deadline·installer 소스 hash를 포함한 Python44와 Terraform validate/mock3·JSON guard2가 통과했다. 실제 PHP/Cloud 재현 성공은 아직 없으며 원인을 해결했다고 주장하지 않는다.

새 계획 observed(2026-08-26 16:34 KST): run `p09-260826-eb03`의 현재 사용자 OAuth·설정 allowlist·artifact/IP·IAM/일부 quota·이름 충돌 preflight 및 저장 Terraform plan이 통과했다. 신규16개/변경0/삭제0, bundle SHA `bc763bc4bec0092bdbd0a1fd8efc3e564df8a2ed6c0952bb43762fce102fb7ab`이며 source/input/action/binary/bundle hash와 schema를 재대조했다. Phase09 gate·Phase07–15 offline suite도 통과했다. manifest planned이고 새 Cloud apply는 아직 없다. 이전 run 정리 snapshot의 승인 hash도 새 소스 수정 후 별도로 일치했다. Phase08/shared lib/원문 변경 없음. 근거: ignored `artifacts/phase-09-recreate-{plan,local-tests,gate,suite}.log`, 새 run manifest/plan과 이전 snapshot. 문서 로컬3명령은 새 독자 리허설에서 exit0/막힘0이었고 `/tmp/phase09-rehearsal.1e31Wf/`에 기록했다.

재생성 apply observed(2026-08-26 16:44 KST, n=1): D-035의 run `p09-260826-eb03` exact 저장 plan이16added/0changed/0destroyed로 완료됐고 Cloud resource identity·SQL root API 초기화까지 exit0이다. manifest applied·database-initialized.json의 root_password_initialized=true/password_persisted=false를 확인했다. 곧바로 실제 verifier를 시작했으며 아직 SQL/WordPress E2E 성공은 아니다. 근거는 ignored `artifacts/phase-09-recreate-cloud-apply.log`와 해당 run의 초기화/identity/manifest 기록이다.

## Phase09 실패 보존·동일 state 복구 — state: implemented, verified offline — 2026-08-26

Evidence: `phases/09/{execute.sh,verify.sh,support.sh,recovery.sh,recovery.py,sql_lab.py,guest_install.py}`, Terraform startup, `tests/test-phase-09.py`, ignored `artifacts/phase-09-preserve-local-tests.log`.
Checked: 2026-08-26 — Python58 tests·Terraform validate/mock3·JSON plan guard2 통과. Phase09 apply는 shared auto-destroy helper 대신 전용 경로를 사용하며 apply/초기화/verify 실패·timeout/중단 code에서 state·plan·로그를 보존한다. 같은 work/state의 replan은 이전 계획 메타데이터를 archive하고 create/update/no-op만 허용하며 delete/replace를 거부한다. 새 baseline(state hash·Cloud 생존 identity·create 범위)와 source/input/action/binary/bundle을 승인에 결합했다. 새로 만든 같은 이름 리소스는 승인 create+TF state 기록으로만 새 identity를 인정한다. managed config의 run/hash 일치만 갱신하고 unmanaged/symlink/drift를 거부하며 MySQL errno 숫자만 진단에 추가했다. WordPress 기존 설치를 재사용하고 marker upsert·probe 내용 확인 회수·verification attempt 보존을 구현했다. startup에서 전체 html 삭제를 제거했다. 실제 Linux PHP/SQL/HTTP Cloud 재검증은 미수행이며 기존 DB 연결 장애 원인은 미확정이다. shared adapter와 Phase08 소스는 그대로여서 다른 Phase 자동 실패 삭제 이관(Q-014)은 별도로 남는다.

직전 실행 실패 observed(2026-08-26): `p09-260826-eb03`도 proxy `db-ready/db-connect/exit31`로 실패했다. 기존 cleanup 중 사용자 정책 변경으로 정상 중단했지만 이미 제출된 SQL 삭제는 완료돼 VM/SQL0, 전용 network/range/connection3개+API3개 state가 남았다. 이번 읽기 전용 재조회에서 peering ACTIVE와 SQL0을 확인했다(`artifacts/phase-09-repair-{network,address,sql}.json`). 복구 준비는 이 state를 재사용하며 이전 run과 Phase08을 삭제하지 않는다. 이 관측은 성공한 실습이 아니고 기존 cleanup 승인도 D-036/D-037로 앞으로 폐기됐다.

복구 계획 observed(2026-08-26 17:16 KST): 새 Phase09 `diagnose`가 VM/disk/SQL/subnet/firewall/SA0, VPC1/PSA range1의 기존 identity를 확인했다. 같은 run/work/state의 `replan`은10create/0update/0delete/6no-op이며 bundle SHA `3d8e72d72c34a5b2b97097490959b0ed9d4b2a55d42ddcdbb5020d170f9483e2`다. state SHA는 실행 전후 `70c8146655a4f64b43b74a258fb7f7d589d4efc60fcd132e503d00f7865e52d6`로 동일하다. Cloud apply·실습 성공은 아니며 Q-016 승인 대기다. 근거: ignored `artifacts/phase-09-preserve-{diagnosis,replan,local-tests,suite}.log`, run manifest/baseline/plan. 새 독자 문서 로컬3명령(Python58/TF/gate/help)도 exit0/막힘0, Cloud/auth/Git 쓰기 없음으로 통과했다. 실제 Cloud·PHP E2E와 다른 Phase 복구 코드 이관은 포함하지 않는다.

보존 복구 apply observed(2026-08-26 17:25 KST, n=1): D-039 exact bundle로 동일 run의10개 생성/변경0/삭제0 및 root 비밀번호 API 초기화가 exit0으로 완료됐다. VPC/PSA/API6개는 재사용했고 manifest applied·current bundle apply receipt·root 초기화 파일을 대조했다. 새 identity는 기존 생존 identity를 유지하며 승인 create+TF state 기록에 맞춰 갱신됐다. 근거는 ignored `artifacts/phase-09-preserve-cloud-apply.log`와 run의 resource-identities/database-initialized/apply-completed/manifest다. 현재 실제 verifier 진행 중으로 SQL/WordPress E2E 성공은 아직 아니다. 새 Cloud 생성과 API 초기화만 검증한 관측이다.

## Phase09 root DB 권한 보완 — state: implemented, verified offline, Cloud 적용 대기 — 2026-08-26

Evidence: `phases/09/sql_lab.py`, `guest_install.py`, `execute.sh`, `tests/test-phase-09.py`; ignored `artifacts/phase-09-root-role-local-tests.log`, `phase-09-preserve-cloud-verify.log`, run의 `evidence/read-only-db-privileges.json`, `evidence/diagnosis.json`, `recovery.json`.
Checked: 2026-08-26 17:35 KST — 이전 17:25의 진행 중 상태를 갱신한다. 실제 verify는 MySQL1044로 exit1이었고 Phase09 전용 실패 경로는 자동 destroy 없이 VM2/SQL1·state·로그를 유지했다. 읽기 전용 진단에서 동일 Proxy VM의 Auth Proxy/SQL private 두 연결 모두 root@% 인증 성공, CURRENT_ROLE=NONE, SHOW GRANTS=USAGE뿐, wordpress 선택1044를 관측했다(n=1 SQL,2경로). 따라서 현재 DB readiness 실패의 직접 원인은 root DB 접근 권한 누락이며 전체 WordPress/SQL/HTTP 성공은 아니다. 과거 두 실행의 미보관 errno까지 같은 원인으로 확정하지 않는다.

보완 구현은 정확한 root@%의 목록/type를 확인해 없으면 users.insert, 있으면 users.update의 databaseRoles query로 cloudsqlsuperuser를 추가하고 기존 역할은 회수하지 않는다. 난수 비밀번호는 기존 메모리/API body 경로로만 전달한다. 1044는 db-privilege-denied로 분류해 transient 연결 실패처럼 재시도하지 않는다. action-plan에 실습 전용 root DB 관리자 역할 변경을 명시했다. Python64·Terraform validate/mock3/JSON guard2가 통과했으나 실제 권한 보완·SQL/WordPress 재검증은 새 exact bundle 승인 전이며, 새 Cloud 성공을 주장하지 않는다. GCP IAM·방화벽·다른 계정/Phase08은 이 보완에서 변경하지 않는다.

근거: [Provider7.45.0 기본 root 삭제 소스](https://github.com/hashicorp/terraform-provider-google/blob/v7.45.0/google/services/sql/resource_sql_database_instance.go#L1782), [users.insert](https://docs.cloud.google.com/sql/docs/mysql/admin-api/rest/v1/users/insert), [users.update](https://docs.cloud.google.com/sql/docs/mysql/admin-api/rest/v1/users/update), [MySQL 사용자 권한](https://docs.cloud.google.com/sql/docs/mysql/users). 역할은 이 실습 DB 관리용이며 운영 애플리케이션 최소권한 예시가 아니다. API operation 완료와 실제 DB 접근 성공을 구분한다.

권한 보완 계획 observed(2026-08-26 17:39 KST): 동일 run/state의 실제 replan은16개 no-op, 추가/변경/삭제/교체0이다. bundle SHA `7ce28fea77bfd9f4e1eb8076c848c489411a9494bed7208a4f7e44345d6d758d`; state SHA는 apply 직후 값과 같은 `0b745001ff3e0f4a9904773fe59d6b9afcb25e4da890dc3e9dffab7621b7cd1a`다. 실제 source/input/baseline/state/Cloud identity/plan/action/bundle hash·schema·파일0600을 읽기 전용 재검사했다. manifest planned이며 새 apply/역할 변경은 하지 않았다(Q-017). 근거: ignored `artifacts/phase-09-root-role-{replan,before-apply-check,local-tests,suite}.log`, 현재 plan/baseline/action/manifest. Phase07–15 suite PASS이며 새 독자가 Phase09 안내만으로 로컬3명령을 모두 exit0/막힘0으로 실행했다(64tests/TF/gate/help). 리허설은 Cloud/auth/Git 변경·실제 SQL 성공 증거가 아니다. 이 결과가 기존 SQL 권한1044를 해결했다는 의미는 아니다.

## Phase09 DB 역할 요청 분리 — state: implemented, Cloud 미검증 — 2026-08-26

Observed 17:50 KST: D-040 승인7ce28… 계획의 Terraform은0added/0changed/0destroyed로 성공했으나 initialization의 API 요청이HTTP400으로 실패했다. SQL operation에는 UPDATE_USER/DONE/INTERNAL_ERROR만 남았고 API 원문은 앞선 비밀 보호 코드가 폐기해 세부 사유는 미확정이다. 같은 run diagnose는 VM2 RUNNING·SQL1 RUNNABLE·disk2와 모든 identity 보존, 실패 automatic_destroy=false/state_preserved=true를 확인했다. 읽기 전용 SQL 재조회에서 root@%는 여전히 USAGE뿐이며 양쪽 경로의wordpress 선택1044다. 따라서 D-040의 역할 보완·실제 실습 검증은 성공하지 않았다. 근거: ignored `artifacts/phase-09-root-role-cloud-apply.log`, `phase-09-root-role-api-operations.json`, `phase-09-root-role-postfailure-{diagnosis,db}.log`, run의 recovery/evidence.

Implemented: 기존 root의 역할 요청에는 BUILT_IN을 명시하고 password를 넣지 않는다. 역할 operation 완료를 확인한 뒤 별도 요청으로 비밀번호만 갱신하며 총600초 deadline을 공유한다. 역할 실패 시 비밀번호 변경을 시작하지 않고, 비밀번호 실패 시 역할 회수·계정 삭제를 하지 않는다. 신규 root insert와 기존 계정 덮어쓰기 금지는 유지한다. HTTP 오류는 고정 status/reason/category 허용 목록만 남기고 원문·비밀을 출력하지 않는다. 오류 분류 전에 실제 비밀 값을 제거해 secret 내용에 따른 오분류를 방지한다.

Evidence: `phases/09/sql_lab.py`, `execute.sh`, `tests/test-phase-09.py`; 로컬70개·TF validate/mock3/JSON guard2 통과(`artifacts/phase-09-separated-role-local-tests.log`). [공식 MySQL 역할 추가 안내](https://docs.cloud.google.com/sql/docs/mysql/create-manage-users#add-database-roles)와 로컬 공식gcloud581.0.0 `surface/sql/users/assign_roles.py`는 type을 명시한 비밀번호 없는 역할 요청을 사용한다. 기존 코드와 이 요청 차이는 관측했으나 이것만으로HTTP400의 유일한 원인이라고 단정하지 않는다. 새 소스 계획 승인 전 Cloud 적용·SQL/WordPress E2E 성공은 미검증이다.

분리 요청 계획 observed(2026-08-26 17:57 KST): 같은 state의 최종 plan은16개 no-op, bundle SHA `e701120a9f6d8ef03a5df23bf41f8d0e056d6238cd7d7ca3dee37ce14658e707`다. source/input/action/baseline/state/Cloud identity/plan/bundle·schema·0600을 읽기 전용 재검사했고 현재 state SHA는`d1e523baadbd1945e1f3d34b2f6633226542119341c70b65c417cf9b71d571e6`로 plan 전후 동일하다. Phase07–15 suite와 새 독자의 안내서 로컬3명령(70tests/TF/phase gate/help)도 모두exit0·막힘0이다. 근거는 ignored `artifacts/phase-09-separated-role-{final-replan,before-apply-check,local-tests,suite}.log`, plan/manifest와 로컬 리허설 transcript다. Q-018 새 승인 전이므로 분리 요청의 Cloud 적용/실제 WordPress 검증은 미실행이다.

분리 요청 apply observed(2026-08-26 18:02 KST, n=1): D-041 exact e701… bundle 적용은exit0,Terraform0added/0changed/0destroyed와 기존root의역할/비밀번호 API operation 완료를 확인했다.400 오류가 이번 적용에서 재발하지 않았으며 manifest applied·root_user_mode=updated·requested_database_role=cloudsqlsuperuser·현재bundle apply receipt/state SHA `4b4cbeebaaa1c51c4a9e55126f9d6f7f91749b67cf53613a54ae0f247dc0379b` 일치를 확인했다. 기존70tests/TF/gate 재검사도PASS다. 근거는 ignored `artifacts/phase-09-separated-role-cloud-apply.log`, run의 database-initialized/apply-completed/manifest다. 실제WordPress/SQL verifier는 시작했지만 아직 결과가 없어 전체E2E성공·모든400재발방지를 주장하지 않는다.

## Phase09 SQL·WordPress 실제 검증 성공 — state: verified, 리소스 유지 — 2026-08-26

Observed 18:05 KST, n=1 run: D-041의 분리 요청 apply와 실제 verifier가 모두exit0이다. Terraform은0added/0changed/0destroyed였고 DB 역할·비밀번호 API를 apply/verify에서 성공적으로 처리해 이번 실행에서HTTP400이 재발하지 않았다. Proxy/private 양쪽 guest의DB readiness·WordPress 설치가complete/ok/0이고, Proxy에서 SQL marker를 생성·갱신한 뒤 private VM의 직접SQL에서 동일값을 읽었다. 두 WordPress의HTTP200/본문과 각각SQL-backed HTTP probe의marker 일치·검증용probe 회수도 통과했다. manifest verified·Task1–6 모두passed·command-code-result waiting_extension_review다.

Evidence: ignored `artifacts/phase-09-separated-role-cloud-{apply,verify}.log`; run `p09-260826-eb03`의 `evidence/phase-09-machine.json`, `evidence/guest-install-{proxy,private}.json`, `manifest.json`, `command-code-result.json`, current bundle의 `apply-completed.json`. 현재 소스70tests·TF validate/mock/JSON guard·Phase09 gate도PASS다. 이번 관측으로 현재1044/400 실패 경로가 수정됐음을 확인했으며 이전400의type 누락/요청 결합 중 어느 하나만이 유일한 원인이었다고 분리 입증한 것은 아니다. 없는root 신규insert·다른버전/계정/환경·Windows·장기간 운영·모든향후400을 보장하지 않는다.

종료 경계: 사용자가 리소스 삭제를 금지했으므로VM2/SQL1 등 기존 환경을 유지한다. `lab_completion.complete=false/destroy_pending=true`는 최종destroy를 수행하지 않았다는 뜻이며 Task1–6 실습 실패가 아니다. 과금·guest DB 비밀번호 보유·이전별도run PSA 잔여는 유지된다. 추가commit/push·Phase08/shared lib/원문 변경 없음.

사후 재확인 observed(18:08 KST): 읽기 전용 diagnose에서VM2 RUNNING·SQL1 RUNNABLE·disk2와 승인 baseline의모든생존identity 일치를 확인했다. 기존guest설정으로다시연결한두SQL경로에서CURRENT_ROLE=cloudsqlsuperuser, wordpress 선택true/errno0을 확인했다. 두frontend의별도curl 재조회도HTTP200이었다. 근거는 ignored `artifacts/phase-09-separated-role-final-diagnosis.log`, `artifacts/phase-09-separated-role-final-db.log`, `artifacts/phase-09-separated-role-final-vms.json`, `artifacts/phase-09-separated-role-final-users.json`과 run `evidence/diagnosis.json`, `evidence/read-only-db-privileges.json`이다. users.list의역할필드생략을권한없음으로해석하지않고실제SHOW GRANTS/SQL결과로판정했다. 재사용절차 `.claude/skills/phase09-mysql-repair/SKILL.md`를프로젝트에만저장하고skill validator를통과했다. 전역스킬설치나자동Cloud실행권한을추가하지않았다.

## Phase09 명시적 종료 정리 — state: observed, PSA 잔여 — 2026-08-26

D-042 요청으로 현재 run `p09-260826-eb03`을 destroy했다. 삭제 전 소유권/identity를 조회하고 저장 삭제 계획의16개 delete·공통 API 유지 설정을 확인한 뒤 승인 소스의 종료 경로를 실행했다. SQL/WordPress VM2/디스크2/subnet/방화벽2/서비스 계정2와 전용 IAM은 제거됐고 새 백업은 만들지 않았다. SQL 삭제 후 PSA 삭제가 producer 사용 중 Error9로 실패해 VPC·할당 범위·서비스 연결3개가 남았다. manifest는 cleanup_required, state는 잔여3개와 유지 API3개를 보존한다. 전체 destroy·비용0을 주장하지 않는다. Phase08 bucket과 공통 API3개의 유지도 조회했다.

Evidence: ignored `artifacts/phase-09-user-destroy{,-before,-after,-plan}.log`, run의 `phase-09-user-destroy-plan.json`, `manifest.json`, 현재 `evidence/diagnosis.json`, `artifacts/phase-09-user-destroy-peerings.json`, `phase-09-user-destroy-enabled-apis.txt`, `phase-09-user-destroy-phase08-bucket.txt`. 기존18:05의 SQL/HTTP 실습 성공 증거는 삭제 전 기록으로 남는다. 같은 SQL의 producer 해제 시점은 unknown이며 Q-020에서 추적한다. 기존 다른 run의 Q-012와 구분한다.

## Task별 콘솔 확인 안내 — state: verified offline / handoff wired — 2026-08-26

Evidence: `docs/console-checks.md`, 15개 Phase의 Task별 콘솔 표, `scripts/console-checks.py`, `tests/test-console-checks.py`, `scripts/validate-design.sh`, `Makefile`, AGENTS·실행/Extension/단일 모델 prompts와 review 출력 경로. 직접 실행과 독립 독자의 로컬 리허설에서15개 Phase·원본90개 Task coverage/출력/8개 회귀 테스트가 exit0였다. 각 경로/통과 기준/보조 확인을 필수로 검사하고 Task 누락·중복·빈칸을 거부한다. 기존 Phase09 70tests·TF validate/mock/gate·controller·Phase01–15 offline suite도 통과했다.

Checked: 2026-08-26. 로컬 Markdown 출력과 보고 경로 연결의 구현·로컬 증거다. 실제15개 Cloud 재실행·전체 콘솔 클릭·Windows·사용자의 콘솔 확인 완료는 검증하지 않았다. 리허설 독자는 Task별 과거 전이·회수된 CSEK/probe·destroy 후 부재의 차이를 문서만으로 설명했고 막힘0이었다. D-043은 AGENTS와 문서에 반영됐으며 새 ballast catalog entry의 exact 확인(Q-019)은 별도 대기다.

게시 observed(18:28 KST): 관련 변경75개를 한국어 commit `eb9aad9f043ebd749e67c695c0e447755c2fafda`로 main에 push했고 무인증 원격 SHA·fast-forward pull·clean tree를 대조했다. state/개인 설정/원시 로그는 제외했다. 기존 저장소 전용 SSH alias를 사용했으며 공개 origin URL이나 전역 Git 설정을 변경하지 않았다. 사후 run IAM binding0도 확인했다. 현재 run의 PSA3개 잔여·Q-019 catalog 대기는 그대로다.

## Phase10–15 게시·Phase10 실제 저장 계획 — state: observed, apply 미실행 — 2026-08-26

D-045에 따라82개 파일을 `b67ce8c91542a9738870af80a19db1f8073392fc`로 main에 push했다. 원격 SHA 일치·FF pull·당시 clean tree를 대조했다. 게시 전40개 Phase 회귀·13개 안내·Terraform mock6개/fmt/init/validate·6개 Phase gate가 통과했다. evidence: ignored `artifacts/phase10-15-prepublish-{tests,gates}.log`, `phase10-15-publish-{commit,push}.log`, Git commit/remote.

Observed 21:11 KST: 현재 실행 계정/allowlist/billing preflight와 필요한 활성 API를 읽기 확인한 뒤 run `p10-260826-2106`의 최초 plan이exit0이었다. US dataset `billing_p10_260826_2106`1create·update/delete/replace0, 기본 table TTL86400000ms다. action plan은 원문 AVRO fixture generation1600686329144010/CRC32C bTzWyg==의 적재와8개 쿼리다. bundle SHA `da21cf4a35d39146664507e7b2545b07945f3389fb0a04a8d818a844c4efd5d9`의 binary/action/binding/manifest 해시와 source/work/input/config/account/state·소유권 guard·manifest/action schema·파일0600을 읽기 전용 재검사했다. state=absent, manifest=planned. plan은 생성/적재/쿼리 성공 증거가 아니며 Q-022 승인 전 apply/verify하지 않았다.

조건부 비용 추정: 코드의 쿼리8개×maximumBytesBilled1GiB와 [BigQuery 공식 온디맨드 가격](https://cloud.google.com/bigquery/pricing?authuser=1)의$6.25/TiB를 곱하면1회 약$0.04883이다. 무료 할당량은 남아 있다고 가정하지 않았다. 이 값은 쿼리 분석 비용만의 추정이며 저장·전송·예약용량·세금이나 반복 실행을 포함한 전체 청구 상한이 아니다. 적재 이후 저장 비용이 따로 발생할 수 있다. 기본 table 만료1일은 dataset/모든 Cloud 리소스의 자동 destroy가 아니다. 가격은2026-08-26 공식 페이지 검색 결과에서 확인했으며 실행 시점·계정 계약에 따라 재확인한다.

근거: ignored `artifacts/phase10-preflight.log`, `phase10-initial-plan.log`, 해당 run의 `phase-10-plan.json`, `action-plan.json`, `binding.json`, `plan-bundle.json`, `manifest.json` 및 실제 무결성 검사 exit0. 기존 Phase08/09 리소스·state를 변경하지 않았다. Phase11–15 실제 plan/apply/verify는 아직 미실행이다.

## Phase10 실제 적재 후 Avro 시간 타입 오류 — state: observed / 수정은 verified offline — 2026-08-26

D-046의 승인된 최초 apply는21:44 KST exit0, dataset1개 생성과 applied binding 일치를 확인했다. 실제 verifier는 load DONE 뒤 schema 검사에서exit1이었다. 실제 API 재조회는415602행·badRecords0이지만 usage_start_time/usage_end_time/export_time이INTEGER였고 load job에useAvroLogicalTypes가 없었다. 승인 generation의 원본 Avro header를64KiB 범위만 읽어 세 필드가long + logicalType=timestamp-micros인 것을 확인했다(n=1 run/fixture). [공식 Avro 변환 규칙](https://docs.cloud.google.com/bigquery/docs/loading-data-cloud-storage-avro#logical_types)의 기본INTEGER/옵션true일 때TIMESTAMP 설명과 일치한다. 행 수 부족이나 load job 실패는 관측되지 않았고 최초 query는0개다.

실제 실패 경로는 dataset/table·Terraform state·load job receipt·진단 로그를 보존했고 자동 destroy하지 않았다. 보완 코드는 load에useAvroLogicalTypes=true를 명시하고 같은 run sampleinfotable의WRITE_TRUNCATE 재적재(data/schema)를 action plan에 표시한다. 검증 오류에필드명/기대/실제 타입을 남기며INTEGER를정상으로완화하지 않았다.42개 회귀·Phase10 TF fmt/validate/mock1개·Bash·gate PASS. 신규 회귀는 실제load POST의옵션/대상·WRITE_TRUNCATE와잘못된스키마뒤query0을검사한다. 보완 Cloud 재적용·8쿼리 성공은 새 exact plan 승인 전 미검증이다.

Evidence: ignored `artifacts/phase10-approved-cloud-{apply,verify}.log`, `phase10-logical-types-local-tests.log`; run `p10-260826-2106`의apply/verify attempt 로그·diagnosis·state-addresses·`evidence/billing-jobs-046421e146b1.json`, `table-readback.json`, `load-readback.json`, `fixture-header-readback.json`. state SHA는진단후`2e1a4222d88e38937aaff5a595ad9e25d6e3623b11e357167a1083d7e263c529`다. 근거는 원본/현재실제Job/API1건과 공식문서이며 모든다른Avro파일이나수정후성공을보장하지 않는다.

수정 계획 observed 21:49 KST: 같은run/state의replan은dataset1no-op·create/update/delete/replace0이다. bundle SHA `eb50a9f987064e100984e7b79e2b9f552ade151eeba51451423f1d9784dbf106`의source/work/input/config/account/state와binary/action/binding 해시·schema·0600을재검사해PASS였다. plan 전후state SHA는위진단값과동일하다. 원래plan/manifest는plan-history에보존하고현재manifest는planned다. Q-023의새SHA승인전보완재적용은하지않았다. 진단지식은`memory/knowledge/gcp-bigquery-avro.md`에관측표본/한계와함께기록했다.

## Phase10 보완 후 실제 Task1–5 통과 — state: verified, 리소스 유지 — 2026-08-26

D-047의명시범위위임에따라수정eb50…bundle을재apply했다. Terraform dataset1no-op·리소스삭제없음, 실제verify exit0/manifest verified/Task1–5 passed다. 샘플415602행과필수schema검사·8개query DONE/실제결과총행수/필터·집계순서/비용상한을통과했다. 전체결과행수는query1~8 순서로70765/415602/100/29/8/3/4/8이며총billed bytes349175808(333MiB)이다. 무료할당량/계약/저장·전송까지반영한실제청구서금액은아니다.

근거: ignored `artifacts/phase10-logical-types-cloud-{apply,verify}.log`, run `p10-260826-2106`의`manifest.json`, `command-code-result.json`, `evidence/phase-10-machine.json` 및두번째billing job receipt. 사후GET table의`table-after-repair.json`에서도시간3개필드TIMESTAMP와415602행을확인했다. n=1실기,전체golden정답/UI클릭/실제Billing export연결은검증범위밖이다. dataset/table·과거실패증거와state는보존하며최종destroy/종료완료를뜻하지않는다.

Phase11 실행 전 추가보완: dashboard GET은공식Monitoring v1 경로, alert/group/uptime은v3를사용하도록분리했다. 기존모든리소스v3조회는dashboard와API계약이달랐다. `tests/test-phases-10-15.py`43개·Phase11 TF mock/gate가통과했다. 실제Phase11는아직실행전이다. [공식 dashboard GET](https://docs.cloud.google.com/monitoring/api/ref_v3/rest/v1/projects.dashboards/get).

## Phase11 그룹400 보완·Phase12 zone 원문 정합성 — state: observed / verified offline — 2026-08-26

Phase11 p11-260826-2224 초기계획은12create였고그룹필터HTTP400으로10개생성후실패했다. 기존VM3/네트워크/dashboard/alert/state/로그를보존하고공식`metadata.user_labels.run`으로수정했다. replan fecc81639ab7b0344faf1ba0f8efc2a78968c610117d992c1dd447e6e8051507은10no-op/2create/삭제교체0, D047범위재apply exit0이다. machine verify는진행중이며완료주장하지않는다. 근거: ignored `artifacts/phase11-group-filter-{replan,cloud-apply,cloud-verify}.log`, 해당run plan-history/attempt/manifest.

Phase12새run입력은같은primary region의다른UP zone을조회·선택하고tfvars에고정한다. Terraform검증과선택함수의동일zone/타region/DOWN거부회귀를추가했다. Python45개·Phase11 TF mock1개/gate, Phase12 TF mock2개/gate가통과했다. 아직Phase12Cloud실기는없다. 원문소스/공통승인lib/다른run은변경하지않았다.

## Phase11 실제 Task1–7 통과 — state: observed, 리소스 유지 — 2026-08-26

그룹 필터 수정 후 검증은 CPU metadata의aligned query누락으로한번더400이었다. 설정4개GET/멤버3개는정상임을분리진단했고CPU만60초ALIGN_MEAN으로보완했다. 새bundle `3f5eb9f7b0d7339ea38f09a0615d897ed26e754f439847636120cebdf7e412af`는12no-op·추가변경삭제0이었다. D047재apply/verify exit0, manifest verified/Task1–7 passed다.

실측: 같은VM3개의CPU point/group exact membership, uptime15시계열의모든최근값true, VM1/2 20%·60초AND조건, enabled true→false 전이를확인했다(n=1). 근거: ignored `artifacts/phase11-aligned-metric-cloud-{apply,verify}.log`, run `p11-260826-2224`의configuration/cpu-series/uptime-series/monitoring-poll/alert-before-disable/phase-11-machine/manifest다. 이메일채널/메일수신/MCP/사용자UI조작/최종destroy는검증하지않았다. 기존12개리소스·실패기록보존,일반400전체무오류를보장하지않는다.

## Phase13 원문 정합성 후속 보완 — state: verified offline — 2026-08-26

원문과대조해primary RATE50/secondary UTILIZATION80, 세번째region의customimage loadgen/NAT, builder reset 전후서로다른boot의Apache 자동기동검증을추가했다. 재부팅startup은설치완료marker가있으면서비스를재시작하지않고활성/HTTP를검사한다. builder 삭제는보존복구를위해수행하지않는다. 회귀48개(이전boot marker만으로reset통과불가·loadgen customimage 포함),Phase13 TF mock2개/validate/fmt/Bash/gate와안내13개PASS. 실제Phase13 Cloud성공은아직아니다.

## Not implemented

<!-- Listed explicitly so absence is a fact, not a gap. Copy must not claim these.
Checked: 2026-08-25 — this section goes stale in the other direction: a line left here after the
capability shipped makes you claim less than you have earned. Sweep it on the same 90-day clock. -->

- 실제 canary Cloud apply·verify·destroy 성공
- Google Cloud 계정 통합 테스트
- 전체 15개 Lab E2E 실행
- 실제 Phase의 Command Code 단일 모델 구현·자기 검증 E2E
- Phase 07 실제 두 사용자 경로의 Cloud 통합 검증, Phase 08 성공 run의 최종 destroy·전체 종료 확인, Phase 09 최종destroy·이전run 잔여PSA 정리 완료, Phase10/11 최종destroy, Phase12–15 실제 Cloud machine verify·최종destroy (Phase10/11 실제apply/machine verify는위관측과구분)
- Monitoring·Logging MCP 실제 OAuth/IAM 연결과 Extension 교차 검증
- WSL 없는 Windows PowerShell wrapper 실제 Windows 실행 검증

## Permanently excluded

<!-- Decided against. Copy must never imply these. Link the ledger decision: D-### -->
