# Phase 09 — Cloud SQL 구현

- 원본: `references/google-cloud-labs-ko/labs/09.Implementing Cloud SQL_KR.md`
- 비용 위험: 높음 — SQL·VM·디스크·외부 IP 등에 비용이 발생한다.
- 현재 상태(2026-08-26): 수정본 apply와 실제 Task1–6의 SQL/WordPress 검증을 통과했고, 이후 사용자 요청으로 종료 정리를 실행했다. SQL·VM2·디스크2·전용 subnet/방화벽/SA는 삭제됐다. PSA producer 해제 지연으로 VPC·할당 범위·서비스 연결3개는 남아 있어 전체 destroy는 미완료다. Phase08과 공통 API는 유지한다. 삭제 전 성공 기록과 현재 리소스 부재를 구분하며, 다른 환경/Windows 실기 검증은 수행하지 않았다.

## 목적

Cloud SQL 하나와 WordPress VM 두 개로 Auth Proxy 및 내부 IP 직접 연결이 같은 DB를 사용하는지 검증한다. 자신의 Google Cloud 계정으로 clone한 저장소를 실행하는 사용자를 위한 안내다. Linux Bash·Terraform·gcloud와 저장소 기본 준비가 필요하다. Phase 07 두 계정 실습을 먼저 실행할 필요는 없다.

## 범위와 원본 매핑

| 원본 Task | 분류 | 자동화·증거 |
|---|---|---|
| Task 1. Cloud SQL 데이터베이스 생성하기 | automated | MySQL8 Enterprise 1vCPU/3.75GB·10GB SSD, RUNNABLE·root 초기화·wordpress DB 질의 |
| Task 2. 두 가상 머신에 WordPress 설치하기 | automated | Debian12 VM2, 고정 artifact·Apache/PHP·두 WordPress HTTP200 본문 |
| Task 3. 가상 머신에 프록시 구성하기 | automated | localhost:3306 Auth Proxy systemd·connection name·public-default 경로 |
| Task 4. 애플리케이션을 Cloud SQL 인스턴스에 연결하기 | automated | Proxy WordPress 설치·DB marker 생성·HTTP에서 DB 읽기 |
| Task 5. 내부 IP를 통해 Cloud SQL에 연결하기 | automated | 다른 VM의 private DB_HOST 직접 SQL·HTTP에서 동일 marker 읽기 |
| Task 6. Review | cli-equivalent | Task1–6 evidence 검토, 성공 후 최종 destroy는 별도 |

원문은 보존한다. 자동화에서는 default network 대신 고유 run 전용 VPC/PSA를 만들고, 웹 접근은 클라이언트 공개 IPv4 한 곳(`/32`)만 허용한다. 콘솔 클릭 대신 API·SSH·SQL·HTTP를 사용하고 WordPress는 latest 대신 고정 버전/hash로 설치한다. private 직접 연결은 Proxy를 거치지 않으며 자동 TLS 경로라는 뜻이 아니다.

## Task별 콘솔 확인

[하위 항목별 상세 확인](../console/phase-09.md): 원문 하위 제목/번호 절차마다 클릭 경로·값·판정·한계를 확인합니다.

[공통 확인법](../console-checks.md)을 먼저 읽고 자신의 프로젝트·해당 run만 선택한다. 아래는 **확인 기준**이지 이번 실행의 성공 기록이 아니다. 원본 Task 이름은 위 매핑과 대응한다.

| Task | 콘솔 경로·대상 | 통과 기준 | 한계·보조 확인 |
|---|---|---|---|
| 1 | SQL → 인스턴스 → wordpress-db-<RUN_ID> → 개요/데이터베이스/사용자 | 실행 상태 정상, MySQL8·승인 사양, wordpress DB와 root 사용자 존재 | 사용자 목록만으로 DB 권한은 판정 불가. 실제 SQL/권한 evidence가 필요 |
| 2 | Compute Engine → VM 인스턴스 → wordpress-proxy/private-<RUN_ID> | VM2 RUNNING; 각 외부 IP의 http:// 주소에서 WordPress 화면 | 허용된 client /32에서 접속. HTTP200만으로 DB 연결까지 입증하지 않음 |
| 3 | Proxy VM → SSH → systemctl is-active cloud-sql-proxy | active, localhost 연결과 승인 connection name의 Proxy 증거 | 이 SSH 조회는 콘솔 UI 바깥 guest 검사. DB 쿼리 결과와 함께 확인 |
| 4 | Proxy WordPress 주소; SQL의 wordpress DB + Task4 evidence | WordPress 정상 본문과 Proxy가 쓴 harness_probe marker의 DB-backed 읽기 일치 | 검증용 HTTP probe는 회수됨. 삭제된 probe URL을 재호출해 실패로 오해하지 않음 |
| 5 | SQL 인스턴스 → 연결 → 네트워킹/Private IP; Private VM의 NIC | 같은 전용 VPC에 private IP가 있고 direct SQL에서 같은 marker를 읽음 | 프런트엔드 외부 IP와 DB private IP는 별개. 화면상 IP 존재만으로 직접 연결 입증 불가 |
| 6 | SQL·VM·VPC 화면 + evidence/phase-09-machine.json | Task1–6 통과와 두 데이터 경로 증거를 확인 | destroy 후에는 SQL/VM/디스크 부재로 정리 여부만 확인. PSA 연결/VPC가 남으면 cleanup 미완료 |

메뉴 확인 근거(2026-08-26): [SQL 데이터베이스 목록 확인](https://docs.cloud.google.com/sql/docs/mysql/create-manage-databases), [VM 상세 확인](https://docs.cloud.google.com/compute/docs/instances/view-vm-details). 화면 언어/버전에 따라 상단 검색으로 같은 서비스에 접근한다. 실제 UI 클릭 전 과정 검증은 별도다.

## 구현 작업

Terraform은 16개 managed resource를 만든다: SQL instance/DB, VM2, SA2, Proxy SA의 Cloud SQL Client IAM, VPC/subnet/PSA range/connection, SSH/HTTP firewall, API3개. VM boot disk2개는 VM에 포함된다. SQL은 zonal `db-custom-1-3840`, VM은 `e2-micro`·각10GB다. SQL 자동 확장·백업·binary log·삭제 보호는 이 일회성 실습에서 꺼진다.

`assets.json`은 WordPress 7.1, Auth Proxy 2.25.2, WP-CLI 2.12.0의 공식 HTTPS URL과 SHA256을 고정한다. plan 전 다운로드 hash를 확인하고 guest에서도 비교한다. 원 제작자 서명 검증까지 했다는 뜻은 아니다.

## 실행 계약

명령은 **저장소 최상위**에서 실행한다. 비밀·plan·state·원시 로그를 Git에 추가하지 않는다.

### 1. 로컬 검사

```bash
bash tests/test-phase-09.sh
./scripts/phase-gate.sh docs/phases/phase-09-cloud-sql.md
./phases/09/execute.sh --help
```

위 명령은 로그인·Cloud 리소스 변경을 하지 않는다. provider 설치를 위한 네트워크는 사용할 수 있다. 이 문서의 로컬 리허설은 여기까지만 실행한다.

### 2. 자신의 계정으로 새 계획 생성

실제 계획 전에 저장소 [기본 준비 안내](../../README.md)에 따라 자신의 gcloud 로그인·ADC와 ignored `config/harness.env`의 project/allowlist/region/zone을 준비한다. 현재 활성 사용자를 saved inputs에 고정하고 OAuth identity를 확인한다. 특정 개인 이메일을 배포 기본값으로 쓰거나 전역 계정/project를 임의 변경하지 않는다.

기본 Compute/IAM/Resource Manager/Service Usage/OS Login API와 생성·IAM·API 활성화·IAP/OS Login 권한이 필요하다. SQL Admin·Service Networking·IAP API는 승인된 Terraform에서 활성화한다.

```bash
P09_RUN="p09-$(date +%y%m%d)-$(openssl rand -hex 2)"
./phases/09/execute.sh plan --run "$P09_RUN"
```

HTTP 허용 IP는 HTTPS로 조회한 현재 공개 IPv4 `/32`다. 다른 네트워크에서 접속한다면 plan 전에 `P09_CLIENT_SOURCE_CIDR`에 그 클라이언트의 공개 IPv4/32를 설정한다. 전체 인터넷·사설 주소·IPv6는 거부한다. 계획 후 IP가 바뀌면 새 계획이 필요하다.

새 run의 plan은 리소스를 생성하지 않는다. 기본 API·이름 충돌·일부 IAM/Compute quota·artifact hash·create-only 범위를 검사한다. 기존 run은 아래 `replan`을 사용한다. SQL API 미활성 상태의 SQL 목록/quota와 실제 용량·모든 조직 정책·IAP 접속을 미리 완전히 보장하지는 않는다.

공유 preflight의 기존 `GCP_CLEANUP_ON_FAILURE=true` 설정 검사는 아직 남아 있지만, Phase09 전용 apply/verify는 이 값으로 자동 destroy하지 않는다. 다른 Phase의 실패 처리까지 바뀌었다는 뜻이 아니다.

### 3. exact SHA 승인 후 apply·즉시 verify

새 run은 16개 create/0 change/0 destroy다. 복구 run은 실제 plan의 create/update/no-op 수를 확인한다. 계정/project/client `/32`, 비용·보존 정책과 출력된 bundle SHA256을 검토하고 사용자가 승인한 SHA만 아래에 입력한다. 코드 변경 시 같은 run의 `replan`과 새 승인이 필요하며, 다른 계정/프로젝트로 같은 run을 재사용하지 않는다.

```bash
./phases/09/execute.sh apply --run "$P09_RUN" --confirm-plan-sha '<승인된 bundle SHA256>'
./phases/09/execute.sh verify --run "$P09_RUN"
```

apply 후 root 계정/역할 준비와 난수 비밀번호 초기화, verify 시 메모리 난수 교체·WordPress 설치·Proxy SQL 쓰기/private SQL 읽기·두 HTTP 화면과 SQL-backed probe를 실행한다. Provider가 기본 root@%를 삭제하므로 계정이 없으면 SQL users.insert로 생성한다. 기존 계정은 BUILT_IN을 명시하고 password를 넣지 않은 users.update의 databaseRoles query로 cloudsqlsuperuser를 추가한다. 역할 operation 성공을 확인한 뒤 별도 요청으로 비밀번호를 갱신한다. 기존 역할은 회수하지 않는다. 이 역할은 **실습 SQL 전용 DB 관리자 권한**이며 운영 WordPress의 최소권한 설정 예시가 아니다. GCP IAM을 추가하거나 방화벽을 넓히는 변경은 아니다.

API operation 완료나 TCP 접속만으로 DB 사용 가능·실습 성공을 판정하지 않는다. Task 증거는 해당 run의 `evidence/phase-09-machine.json`이다. 현재 plan의 apply 완료 기록이 있으면 같은 run에서 verify를 재시도할 수 있다. 이전 시도 증거는 `verification-attempts/`에 보존한다.

기존 계정의 역할·비밀번호 작업은 총600초 deadline을 공유한다. 역할 작업 실패 시 비밀번호를 변경하지 않으며, 이후 비밀번호 작업이 실패해도 추가된 역할을 회수하거나 사용자를 삭제하지 않는다. API 실패는 작업 단계와 HTTP code·고정 status/reason/category만 남기고 오류 원문은 출력하지 않는다. `unknown` 분류는 원인이 확인됐다는 뜻이 아니다.

설치 전에 PHP/mysqli·설정 문법·실제 DB `SELECT 1`을 확인하고 DB 연결/인증 준비를 최대120초 기다린다. MySQL1044는 DB 접근 권한 거부(`db-privilege-denied`)로 즉시 분류하며 준비 지연처럼 반복 대기하지 않는다. `evidence/guest-install-proxy.json`과 `guest-install-private.json`은 허용된 단계·오류 종류·exit code·숫자 MySQL errno만 기록한다. 비밀번호나 child 오류 원문은 기록하지 않으며, SSH/비정상 응답은 transport 실패로 구분한다. 진단 보완 자체가 새 Cloud 성공을 뜻하지 않는다.

### 4. 실패한 run 보존·진단·복구

실패·timeout·중단 시 VM/SQL/state/plan/로그를 보존하며 자동 destroy하지 않는다. manifest `failed`와 `recovery.json`을 확인한다. 이전 버전의 `cleanup_required`도 삭제를 재개하라는 지시가 아니다. 보존 중에도 과금될 수 있다.

```bash
# 새 run ID를 만들지 말고 실패한 기존 ID를 지정한다.
P09_RUN='<실패한 기존 run ID>'
./phases/09/execute.sh diagnose --run "$P09_RUN"
# 진단에 따라 phases/09 구현을 수정한 다음, 같은 work/terraform.tfstate로 계획한다.
./phases/09/execute.sh replan --run "$P09_RUN"
# 새 계획의 변경 수·계정·범위와 exact SHA를 사용자가 승인한 뒤에만 실행한다.
./phases/09/execute.sh apply --run "$P09_RUN" --confirm-plan-sha '<새로 승인된 bundle SHA256>'
./phases/09/execute.sh verify --run "$P09_RUN"
```

`diagnose`는 Cloud/state 조회와 guest 읽기 전용 상태 검사를 수행해 `evidence/diagnosis.json`에 기록한다. 조회 실패를 리소스0으로 해석하지 않는다. 현재 root/설정/child 오류 원문은 출력하지 않는다. `apply.log`, `verification.log`, guest 진단에서 실패 단계와 errno를 먼저 확인한다.

`replan`은 기존 state를 이동·삭제·import하지 않고 같은 위치에서 사용한다. 이전 plan/승인/소스 메타데이터는 `revisions/`에 보존한다. 남은 Cloud identity와 state hash를 새 승인에 묶으며 삭제·교체가 나오면 중단한다. plan 전에 기존 리소스를 지우지 않는다. 새 DB/VM 생성 없이 코드·검증만 갱신하는 no-op Terraform 계획도 새 action-plan SHA 승인이 필요하다. 삭제·교체가 꼭 필요하다면 원인·최소 범위를 별도로 검토·승인해야 하며 이 복구 명령이 자동으로 허용하지 않는다.

재검증은 관리 표식의 run/hash가 일치하는 `wp-config.php`만 갱신하고 기존 WordPress DB를 재사용한다. 관리 밖 파일·다른 run·수동 변경은 덮어쓰지 않는다. 표식이 없는 이전 버전 guest 설정은 자동 채택하지 않고 중단한다. DB 비밀번호 교체 중 실패하면 기존 웹 연결이 끊길 수 있으므로 환경을 보존한 채 진단한다. startup 재실행은 WordPress 전체 파일을 삭제하지 않는다. probe 회수 실패도 전체 destroy 사유가 아니다.

### 5. 명시적으로 요청한 실습 종료 정리

정상 성공은 리소스 유지 상태이며 자동 만료가 없다. 사용자가 해당 run 삭제를 요청한 뒤 아래를 실행한다. DB·VM·디스크 데이터를 삭제하며 새 백업을 만들지 않는다.

```bash
./phases/09/execute.sh destroy --run "$P09_RUN"
./phases/09/verify.sh --destroyed --run "$P09_RUN"
```

실패만을 이유로 위 destroy를 실행하지 않는다. 조회 오류를 “없음”으로 해석하지 않고 승인/state 밖 동명 재생성 identity·다른 run 대상이면 중단한다. **Cloud SQL 삭제 후 producer 해제에 최대4일이 걸려 PSA 연결/VPC 삭제가 실패할 수 있다.** 명시적 종료 중 실패하면 `cleanup_required`와 state를 유지하며, 재시도도 사용자 지시에 따른다. peering 강제 삭제나 state 제거로 잔여0을 꾸미지 않는다. 공통 `sqladmin`·`servicenetworking`·`iap` API3개는 정상 destroy 후에도 활성 상태로 유지한다.

## 검증 게이트

- Bash 문법, Python 회귀, Terraform fmt/init/validate/mock·provider JSON guard, Phase gate.
- source/input/action/bundle hash, allowlist, saved OAuth 사용자, run resource name/identity.
- SQL/Proxy/private SQL과 두 WordPress HTTP200 본문·실제 DB marker 일치.
- 실패 시 state/plan/로그 보존, 동일 state replan·새 exact SHA·survivor identity 검사.
- 명시적 종료 후 빈 state·Cloud 목록·run SA IAM 잔여를 확인해야 destroyed로 기록.

오프라인 통과만으로 실제 Cloud·PHP 게스트·Windows 성공을 주장하지 않는다. 초기 두 번의 실패에는 정확한 MySQL errno가 없었고, 당시 자동 cleanup은 VM/SQL을 삭제했다. 이후 보존 복구 apply는 성공했으나 실제 verifier에서1044를 기록했다. 읽기 전용 진단으로 Auth Proxy/SQL private 두 경로의 root@% 인증은 성공하되 권한이 USAGE뿐이고 wordpress DB 접근이 거부됨을 확인했다. 이는 당시1044의 직접 원인이며, 미보관된 과거 오류까지 같은 원인으로 단정하지 않는다.

다음 권한 보완 실행은 Terraform16개 no-op으로 완료됐지만, 역할과 비밀번호를 합친 API 요청은HTTP400/operation INTERNAL_ERROR였다. 세부 오류 원문은 미보관이라 유일한 원인을 확정하지 않는다. 공식 CLI와 대조해type을 명시하고 역할→비밀번호 요청을 분리했다. 수정본 실제apply와verify에서API400이 재발하지 않았고 양쪽guest/SQL/HTTP Task1–6가통과했다. 이는2026-08-26의한run에서실측한성공이며 모든향후400·다른DB버전·신규root insert 성공을 보장하지 않는다. 소스와 SQL action이 바뀌면 Terraform이16개 no-op이어도 새 bundle 승인이 필요하다. 보존한 예전 소스는 이력 확인용이며 그 자동 cleanup을 다시 실행하지 않는다.

## 안전·비용 가드레일

DB 비밀번호를 Terraform 입력/state·로컬 비밀 파일·명령 인자에 넣지 않고 SQL API body와 SSH stdin으로 전달한다. guest `wp-config.php`는 root:www-data·0640이며 최종 VM/disk 삭제까지 비밀번호를 보유한다. WordPress 관리자 비밀번호는 stdin으로 전달하고 보관하지 않으므로 수동 관리자 로그인 자격 증명을 제공하지 않는다. 메모리/swap 완전 소거까지 보장하지 않는다.

SQL public IP는 있지만 Authorized Networks를 열지 않는다. Proxy workload SA에만 `roles/cloudsql.client`를 부여하고 SSH는 IAP, HTTP는 client `/32`로 제한한다. 두 WordPress는 같은 DB에 각자의 `WP_HOME`/`WP_SITEURL`을 설정해 다른 frontend로 redirect되지 않게 한다.

timeout은 실행 대기 상한이지 리소스 수명·비용 상한이 아니다. 정상 verify 후에도 과금될 수 있다. Phase08과 다른 run 리소스는 Phase09 정리 대상이 아니다.

## 완료 조건

Task1–6 실제 증거·사용자 판정과 최종 destroy/잔여 확인을 구분한다. verify만 통과하면 `lab_completion.complete=false`, `destroy_pending=true`다. run 잔여0과 API 유지 상태를 확인하기 전 전체 정리·비용0을 주장하지 않는다.

## Command Code·Extension handoff 지시

현재 모델 설정을 사용하고 모델/effort override를 넣지 않는다. source/plan/identity·redacted evidence를 대조하며 새 exact SHA 사용자 승인과 실패 보존·진단·같은 state 복구를 유지한다. 실행자는 임의 commit/push하지 않는다. 공유 harness의 기존 auto-cleanup apply helper를 Phase09에서 직접 호출하지 않는다.

## Git 종료 조건

사용자 승인된 관련 파일만 검증 범위를 명시해 한국어 commit·push한다. 원격 SHA 확인 후 다음 Phase로 진행한다. 미검증 상태를 Cloud 검증 완료로 게시하지 않는다.

## 공식 근거

- [Google Provider7.45.0 SQL instance](https://registry.terraform.io/providers/hashicorp/google/7.45.0/docs/resources/sql_database_instance): 생성 후 기본 root 삭제. [실제 Provider 소스](https://github.com/hashicorp/terraform-provider-google/blob/v7.45.0/google/services/sql/resource_sql_database_instance.go#L1782)도 대조했다.
- [Cloud SQL users.insert](https://docs.cloud.google.com/sql/docs/mysql/admin-api/rest/v1/users/insert): 없는 계정 생성.
- [Cloud SQL users.update](https://docs.cloud.google.com/sql/docs/mysql/admin-api/rest/v1/users/update): 비밀번호·databaseRoles query 갱신, revokeExistingRoles와 operation.
- [Cloud SQL MySQL 사용자](https://docs.cloud.google.com/sql/docs/mysql/users): root·cloudsqlsuperuser 권한 범위.
- [기존 사용자 역할 추가](https://docs.cloud.google.com/sql/docs/mysql/create-manage-users#add-database-roles): BUILT_IN 명시와 별도 역할 요청. 로컬 공식gcloud581.0.0의 assign_roles.py 요청도 대조했다.
- [Cloud SQL Auth Proxy](https://docs.cloud.google.com/sql/docs/mysql/connect-auth-proxy): 연결과 identity.
- [Private services access](https://docs.cloud.google.com/vpc/docs/configure-private-services-access): SQL producer 삭제 지연.
- [WordPress wp-config](https://developer.wordpress.org/advanced-administration/wordpress/wp-config/): WP_HOME/WP_SITEURL.
- [WP-CLI core install](https://developer.wordpress.org/cli/commands/core/install/): 비밀번호 stdin prompt.
