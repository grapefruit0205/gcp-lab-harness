# Phase 07 — IAM 탐색

- 원본: `references/google-cloud-labs-ko/labs/07.Exploring IAM_KR.md`
- 우선 기준: [사용자 지정 Notion 본문 — 07. Exploring IAM](https://app.notion.com/p/3c76d458853781ecbcf3d1c5e12f28dd), 2026-08-26 확인. 첨부된 과거 Qwiklabs 문서와 구분한다.
- 비용 위험: 중간
- 주요 서비스: IAM, Service Accounts, Cloud Storage, Compute Engine

## 목적

Notion 본문처럼 서로 다른 **실제 Google 사용자 두 계정**으로 권한 부여·회수와 Storage 접근을 검증한다. User1은 계정 A(관리자), User2는 계정 B(확인용 사용자)다. **Task 6의 VM 생성은 계정 B로**, SSH·IAM 변경·정리는 계정 A로 수행한다. 서비스 계정은 VM workload용 하나만 생성하며, 사용자 둘을 서비스 계정 가장으로 대체하지 않는다(D-024/D-026).

일반 창 A/시크릿 창 B의 콘솔 조작과 인증된 브라우저 파일 다운로드는 각 실제 사용자의 OAuth API 호출로 옮긴 경로다. 브라우저 UI 자동 조작이나 Qwiklabs 임시 계정 수명주기를 재현했다고 주장하지 않는다. Notion 페이지와 보존 원본은 수정하지 않으며 [Notion 대조표](../audits/phase-07-notion-coverage.md)에 차이를 기록한다.

## 범위와 원본 매핑

| 원본 Task | 분류 | 자동화·증거 |
|---|---|---|
| Task 1. 두 사용자를 위한 설정하기 | cli-equivalent | 실제 User1/User2 OAuth 로그인과 verified userinfo 일치; 가장/동일 계정/인증 override 거부 |
| Task 2. IAM 콘솔 살펴보기 | cli-equivalent | User1의 IAM·역할 조회; Viewer User2의 IAM 조회 성공 및 setIamPolicy 권한 부재. 콘솔 화면 조작은 별도 |
| Task 3. 액세스 테스트를 위한 리소스 준비하기 | automated | User1이 private bucket·sample.txt 생성; User2 프로젝트 Viewer의 프로젝트/버킷 조회 |
| Task 4. 프로젝트 액세스 제거하기 | automated | User1이 User2의 임시 프로젝트 Viewer를 회수하고 프로젝트/버킷 목록과 존재하는 sample.txt 읽기 거부 확인 |
| Task 5. 스토리지 액세스 추가하기 | automated | 원문과 같은 프로젝트 수준 Object Viewer 부여; User2 객체 목록/읽기 성공, 쓰기·Compute·IAM 변경 거부 |
| Task 6. Service Account User 설정하기 | cli-equivalent | A가 B에 workload-only actAs와 project Compute Instance Admin을 부여, **B OAuth로** private VM 생성 및 operation actor/RUNNING/SA 확인. A가 SSH |
| Task 7. Service Account User 역할 살펴보기 | automated | VM metadata SA로 Compute 거부/read 성공/write 거부, project Viewer→Creator 교체 후 업로드 성공/**기존 파일 읽기 거부** |
| Task 8. Review | cli-equivalent | B의 Viewer/Object Viewer/Compute/actAs 회수·baseline 및 A 보존 확인. 최종 리소스 삭제는 승인된 destroy 뒤이며 그전에는 전체 종료 완료가 아님 |

## Task별 콘솔 확인

[공통 확인법](../console-checks.md)을 먼저 읽고 자신의 프로젝트·해당 run만 선택한다. 아래는 **확인 기준**이지 이번 실행의 성공 기록이 아니다. 원본 Task 이름은 위 매핑과 대응한다.

| Task | 콘솔 경로·대상 | 통과 기준 | 한계·보조 확인 |
|---|---|---|---|
| 1 | 일반 브라우저 A·시크릿/별도 프로필 B → 우측 계정 메뉴 | 서로 다른 본인 계정이며 A는 허용 프로젝트 관리자 | Qwiklabs 임시 계정은 필요 없음. 이메일/토큰을 문서 기본값에 저장하지 않음 |
| 2 | IAM 및 관리자 → IAM; B의 프로젝트 선택 | 해당 단계의 Viewer B는 조회 가능하고 IAM 변경 권한은 없음 | 자동 검증 종료 후 임시 역할은 회수되므로 B의 접근 거부가 정상일 수 있음 |
| 3 | Cloud Storage → run private 버킷 → sample.txt | A가 객체를 확인하고 승인 단계의 B 조회 증거가 있음 | 후속 회수 후에는 B로 재조회가 안 될 수 있음. 단계별 evidence 대조 |
| 4 | A: IAM 및 관리자 → IAM에서 B 검색 | 임시 프로젝트 Viewer가 제거되고 단계별 B 읽기 거부 증거가 있음 | 현재 콘솔만으로 과거 거부를 입증하지 않음. 재현하려고 역할을 임의 부여하지 않음 |
| 5 | IAM 및 관리자 → IAM 및 Storage 객체 상세 | Object Viewer 단계의 B 목록/읽기 성공·쓰기/Compute/IAM 거부 evidence | 최종 rollback 후 Object Viewer가 없는 것이 정상. 단계 종료와 현재 권한을 구분 |
| 6 | Compute Engine → run VM 상세 → 서비스 계정; Logging → 로그 탐색기 | VM의 workload SA가 일치하고 VM 생성 operation/audit actor가 B | A의 SSH와 B의 VM 생성을 구분. IAM 부여는 이미 회수될 수 있으며 별도 재부여 금지 |
| 7 | IAM 및 관리자 → IAM에서 workload SA 검색; VM workload evidence | Viewer→Creator 전이에서 읽기/쓰기 허용·거부가 계약대로 기록됨 | 사용자 B 권한과 VM SA 권한은 별개. 콘솔 목록만으로 metadata 인증 결과는 입증 불가 |
| 8 | IAM 페이지 + 해당 run VM/버킷 | B의 임시 Viewer/Object Viewer/Compute/actAs 회수와 기존 A/baseline 유지 | 리소스는 destroy 전 남을 수 있음. 현재 IAM과 단계별8개 evidence를 함께 확인 |

메뉴 확인 근거(2026-08-26): [현재 IAM 접근 권한 보기](https://docs.cloud.google.com/iam/docs/granting-changing-revoking-access). 화면 언어/버전에 따라 상단 검색으로 같은 서비스에 접근한다. 실제 UI 클릭 전 과정 검증은 별도다.

## 구현 작업

두 실제 사용자 인증, project-level 역할 전이, **User2의 VM 생성**, User1의 SSH, workload 역할 전환과 정확한 rollback을 연결한다. 프로젝트 권한은 프로젝트에서, 객체 권한은 생성된 실습 버킷에서 검사한다. 기존/그룹 상속 Object·actAs 권한이 있으면 실습 성공으로 처리하지 않으며 다른 사용자 권한은 제거하지 않는다.

### 준비와 인증

저장소 bootstrap으로 gcloud·Terraform·Python·jq와 허용 실습 프로젝트/ADC를 준비한 Linux Bash 또는 Git for Windows Bash에서 실행한다. 아래 명령은 저장소 루트 기준이다.

User1은 허용 프로젝트에서 IAM 변경·VM 생성·API 활성화·IAP/OS Login이 가능한 관리자여야 한다. User2는 이 프로젝트에 기존/그룹 상속 권한이 없는 별도의 실제 Google 계정을 사용한다. 자동 실습에서는 **IAM 콘솔에서 User2를 미리 추가할 필요가 없다.** 프로젝트 계정 추가와 Viewer/Object Viewer 역할 전이는 새 plan 승인 뒤 자동으로 수행한다. 기존 권한을 자동 삭제해 실습에 맞추지는 않는다.

사용하는 사람마다 아래 명령으로 **자신의 두 계정**을 등록한다. 원 작성자의 이메일/프로젝트/로그인 상태는 clone되지 않는다. `config/phase-07-users.json`과 `config/harness.env`는 Git 제외 파일이고 예시에는 placeholder만 있다. 최초 관리자 제안값도 clone한 사람의 현재 gcloud 사용자에서 가져오며 직접 변경할 수 있다. JSON을 직접 복사하거나 수정할 필요 없다(D-027).

```bash
./bin/gcp-lab-harness accounts setup
```

1. **User1 관리자 이메일**, **User2 실습 이메일**을 입력한다. 기존 설정이 있으면 Enter로 유지하거나 새 이메일로 교체할 수 있다. 첫 설정의 User1 기본값은 현재 gcloud의 실제 사용자 계정이다.
2. 스크립트가 서로 다른 실제 사용자 형식을 검사하고, 소문자로 정규화해 Git 제외 `config/phase-07-users.json`에 저장한다(Linux mode600, 원자적 교체). 잘못된 입력이나 입력 취소는 기존 설정을 덮어쓰지 않는다.
3. 이미 인증된 계정은 재사용하고, 미인증 계정만 Google 브라우저 로그인으로 연결한다. 해당 계정 소유자가 직접 로그인·동의한다. 비밀번호나 인증 코드를 AI에 전달하지 않는다.
4. 로그인 후 OAuth identity가 입력한 이메일과 일치하는지 두 계정 모두 확인한다. 취소/실패하면 같은 명령을 다시 실행해 이어간다. 이메일 설정은 남아 있으므로 재입력하지 않아도 된다.

Windows PowerShell에서는 같은 진입점을 `./harness.ps1 accounts setup`으로 실행한다(Windows wrapper 연결, 실제 Windows 로그인은 미검증). Bash 직접 호출 `./phases/07/auth.sh --setup`도 동일하다. 새 Google 계정 자체의 가입, Qwiklabs 임시 사용자 발급, 새 프로젝트 생성은 수행하지 않는다.

이메일을 명시적으로 지정할 수도 있다. 아래 주소는 예시이므로 자신의 계정으로 바꾼다.

```bash
./bin/gcp-lab-harness accounts setup --user1 administrator@example.com --user2 lab-user@example.com
./bin/gcp-lab-harness accounts check
```

설정 파일만 만들고 로그인을 나중에 할 때는 `setup` 명령에 `--no-login`을 붙인다. 이 경우 인증 완료가 아니며 나중에 터미널에서 `accounts setup`을 다시 실행해야 한다. `accounts check`는 읽기 전용이다. 특정 계정만 재로그인하려면 `./phases/07/auth.sh --login-user1` 또는 `--login-user2`를 사용한다.

로그인은 `gcloud auth login --no-activate`를 사용하여 활성 계정과 ADC를 바꾸지 않는다. OAuth 자격 증명은 gcloud가 관리하고, 하네스 계정 설정에는 이메일만 저장한다. 각 API 요청은 `--account`와 OAuth userinfo로 실제 사용자를 확인한다. Terraform은 User1의 단기 access token을 프로세스 환경에서만 사용한다. 가장 설정이나 외부 token/credential override가 있으면 중단한다.

`plan`도 실제 터미널에서 실행하면 누락된 계정 설정/로그인으로 연결한 후 계속한다. AI/CI처럼 비대화형이면 브라우저를 임의 실행하지 않고 `accounts setup` 안내와 함께 중단한다. `apply/verify/destroy`는 로컬 설정을 새로 선택하지 않고 승인 당시 saved inputs의 계정으로 고정한다. 계정 변경을 반영하려면 새 run/plan을 만든다.

## 실행 계약

```bash
./phases/07/verify.sh --offline
./phases/07/execute.sh plan --run <새로운-run-id>
# 출력된 plan과 action scope를 검토하고 정확한 bundle SHA를 승인한 다음:
./phases/07/execute.sh apply --run <같은-run-id> --confirm-plan-sha <승인한-bundle-SHA>
./phases/07/verify.sh --applied --run <같은-run-id>
./phases/07/execute.sh verify --run <같은-run-id>
# 결과 검토 후 최종 정리를 승인한 경우에만:
./phases/07/execute.sh destroy --run <같은-run-id>
```

꺾쇠 자리표시는 실제 값으로 바꾼다. run ID는 소문자·숫자·하이픈 8–20자이며, 예시는 `p07-users-001`이다. 재사용하지 않는다. `.sh` 실행을 매번 묻지는 않지만 saved plan SHA 승인과 최종 cleanup/commit/push gate는 유지한다. 같은 프로젝트·User2로 동시에 여러 실습을 실행하지 않는다.

Terraform은 8개 항목(API 관리, VPC, PGA subnet, IAP SSH firewall, private bucket, fixture, workload SA, workload project Object Viewer)을 관리한다. B의 프로젝트 Viewer/Object Viewer/Compute Instance Admin과 workload-only Service Account User는 action plan에 열거한 임시 변경이며 성공·실패 모두 회수한다. 사용자 계정을 생성·삭제하거나 A의 프로젝트 관리자 권한을 회수하지 않는다.

**범위 주의:** 원문처럼 프로젝트 수준으로 부여하는 Storage 역할은 이 실습 버킷뿐 아니라 **같은 프로젝트의 기존 버킷 객체에도 적용**된다. 특히 workload Creator는 검증 동안 프로젝트의 다른 버킷에도 객체 생성 권한을 가진다. 승인 화면에 이 범위를 포함하고, 스크립트의 실제 객체 요청은 고정된 run fixture로 제한한다. 실습 전용 프로젝트가 적합하다. 원치 않는다면 승인하지 말고 범위를 먼저 변경해야 한다.

**VM 권한 범위:** B의 임시 `roles/compute.instanceAdmin.v1`도 **프로젝트의 기존 VM에 적용**된다. 현재 자동화는 run 소유 VM만 생성/삭제하지만 역할 자체가 그 VM에만 한정되는 것은 아니다. 기존 서버가 있는 프로젝트라면 이 범위를 별도로 검토해야 한다. 프로젝트 수준 actAs나 Owner/Editor는 B에게 부여하지 않는다.

## 검증 게이트

- 실제 사용자 두 인증을 확인하고 User2의 기존 direct/상속 권한이 발견되면 중단한다. User1의 관리자 권한은 제거 대상이 아니다.
- role과 resource scope를 함께 검사한다. **관측 2026-08-26:** 현재 `roles/storage.objectViewer`에는 `resourcemanager.projects.get/list`도 포함돼 있다. 원문의 프로젝트 화면 비표시 설명을 그대로 HTTP project 조회 거부로 가정하지 않고 실제 role permission과 응답을 대조한다.
- 인증 실패·API 비활성·OAuth scope 부족·네트워크 오류를 IAM 거부로 처리하지 않는다. HTTP403의 구체 permission을 검사하며 일반적인 Resource Manager/Storage 403은 같은 인증 사용자의 `testIamPermissions`로 보강한다. fixture 존재·내용은 관리자 계정으로 별도 확인한다.
- VM 생성 HTTP2xx는 접수일 뿐이다. 정확한 **B actor**/zone/VM/insert operation의 `DONE`과 최종 오류, 이후 실제 VM의 `RUNNING`·private subnet·workload SA를 확인한다. 관리자 A의 성공을 B의 성공으로 대체하지 않는다.
- guest는 metadata의 workload identity와 cloud-platform scope를 확인한다. 사용자 token/키를 VM에 복사하지 않는다. guest API 검사는 Python 표준 라이브러리를 사용하며 원문 gcloud 명령의 권한 효과를 검사한다.
- 임시 역할은 exact member/role/condition tuple로만 회수한다. 전파 대기는 단계별 최대 600초이며 실패를 PASS로 바꾸지 않는다. project/workload/bucket IAM 내용 hash가 시작 시 baseline과 일치해야 한다.

## 안전·비용 가드레일

- Notion 본문에 따라 가상 `altostrat.com` 대신 **실제 B**에 workload-only `roles/iam.serviceAccountUser`와 임시 project Compute Instance Admin을 부여한다. SA unique ID·원래 빈 workload policy를 확인하고 exact tuple만 회수한다.
- SA 가장/TokenCreator와 장기 키를 사용하지 않는다. VM은 immutable Debian12, e2-micro, 10GB pd-standard, 외부 IP 없음, OS Login/IAP-only SSH다. 신규 OS Login 공개 SSH 키 등록은 발생할 수 있다.
- Resource Manager API만 Terraform에서 활성화하고 cleanup 후에도 공용 API를 끄지 않는다. 기존 Minecraft VM·월드·방화벽은 Terraform 대상이 아니다.
- cleanup은 run journal·SA unique ID·VM/disk label·zone을 대조한다. 조회 실패를 잔여 0으로 바꾸지 않는다. 실패 시 해당 run 리소스만 정리하며, 사용자 OAuth 로그인 자체는 삭제하지 않는다.
- 성공 후 VM/bucket/workload는 최종 cleanup 승인까지 남아 비용이 발생할 수 있다. commit·push는 자동 실행하지 않는다.

## 완료 조건

- 원본 Task 1–8과 Notion 대조표에 실제 사용자/VM identity와 권한 전이 증거가 연결된다.
- CLI/API 완료와 콘솔 UI 경계를 구분해 Extension 또는 단일 모델 검토를 거치고 사용자가 승인한다.
- cleanup 후 소유 리소스와 임시 User2 권한이 없으며 기존 사용자 권한과 다른 Phase는 보존된다.

## 현재 구현과 검증 범위

관측 2026-08-26: Notion 본문 대조, 실제 두 사용자·계정 등록, Python 회귀 **84개**·Terraform mock **8개**를 통과했다. 새 clone 계정 입력, 격리된 실제 CLI와 Linux PTY, B의 권한 grant/rollback, VM RUNNING identity와 Creator 읽기 거부 경로를 offline 검사했다. OAuth 성공/취소 분기는 mock 범위이며, 별도 읽기 전용 검사에서 현재 A/B의 실제 OAuth userinfo identity도 모두 확인했다. 새 Cloud E2E는 아직 미수행이므로 **Notion 실습 전체 완료가 아니다.** `phase-07-applied.json`, IAM 검증 `phase-07-machine.json`, 최종 destroy를 구분하며 `lab_completion.complete=false`는 리소스 정리 전 상태를 명시한다.

구현 근거: [사용자 계정별 gcloud 인증](https://docs.cloud.google.com/sdk/gcloud/reference/auth/print-access-token), [Storage testIamPermissions](https://docs.cloud.google.com/storage/docs/json_api/v1/buckets/testIamPermissions), [Compute operation 결과](https://docs.cloud.google.com/compute/docs/api/best-practices#wait_for_operations_to_be_done). 원본 Task 문서는 보존한다.

## Command Code·Extension handoff 지시

실행자는 두 사용자 OAuth identity 증거, role scope, saved plan SHA, 원본 Task별 검사와 실패 cleanup을 함께 전달한다. 검토자는 실제 사용자 인증과 metadata workload 인증을 구분하고 console UI/manual boundary를 자동 완료로 승격하지 않는다. 원문보다 좁힌 workload actAs 범위와 project-level Storage 권한의 기존 bucket 영향을 확인한다.

## Git 종료 조건

사용자가 승인한 변경만 한국어로 commit하고 별도로 push를 승인받는다. 원격 SHA 확인 전 다음 Phase 완료로 간주하지 않는다.
