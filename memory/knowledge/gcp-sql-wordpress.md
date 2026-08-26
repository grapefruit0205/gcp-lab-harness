# Cloud SQL·WordPress 실행 경계 — 2026-08-26

## quiet와 비밀번호 프롬프트 충돌 — observed

- 관측: 로컬 gcloud 581.0.0의 `lib/surface/sql/users/set_password.py`는 `--prompt-for-password`에서 `PromptPassword`를 호출한다. `lib/googlecloudsdk/core/console/console_io.py`는 disable_prompts가 켜졌으면 None을 반환한다. 따라서 기존 Phase09의 quiet+prompt 조합을 비밀번호 입력 완료로 믿을 수 없다.
- 대응/근거: [공식 users.update API](https://docs.cloud.google.com/sql/docs/mysql/admin-api/rest/v1/users/update)는 root·host=%의 password 갱신과 operation 반환을 제공한다. body는 메모리에서 보내고 DONE/error를 확인하도록 구현했다. `tests/test-phase-09.py`는 비동기 성공·실패·timeout·오류 원문 비노출을 mock으로 검사한다.
- 한계: SDK 소스 관측과 오프라인 검증이며 새 Cloud SQL 실제 비밀번호 갱신 성공은 아직 관측하지 않았다. API body는 TLS로 전송하고 서버에서 처리되므로 “어디에도 비밀번호가 존재하지 않는다”는 뜻이 아니다.

## 두 WordPress frontend의 URL·비밀번호 전달 — confirmed (self-gated)

- Claim: WordPress `WP_HOME`/`WP_SITEURL`은 DB URL을 덮어쓰는 설정으로 frontend마다 구분할 수 있다. WP-CLI core install은 `--prompt=admin_password`의 stdin 입력을 지원한다.
- 근거: [WordPress wp-config](https://developer.wordpress.org/advanced-administration/wordpress/wp-config/), [WP-CLI core install](https://developer.wordpress.org/cli/commands/core/install/). 각각 해당 항목의 직접 공식 문서이며 서로 다른 사실을 뒷받침한다.
- 반증/검사: 단순 HTTP200/redirect로 DB 연결을 판정하지 않는다. WordPress 본문과 양쪽 SQL-backed HTTP probe의 동일 marker를 검사하고 probe는 finally에서 회수한다. SQL query는 WordPress DB 연결의 wp eval을 사용해 별도 mysql password argv를 만들지 않는다.
- 한계: PHP/Apache/WordPress 실제 guest 실행은 아직 미검증이다. guest wp-config에는 최종 destroy까지 DB 비밀번호가 남고 두 private/public 데이터 경로의 보안 성질은 같지 않다.

## Cloud SQL 삭제 후 PSA 즉시 삭제를 보장하지 않는다 — hearsay (직접 공식 문서, 실기 미관측)

- 공식 명시: [Private services access 구성](https://docs.cloud.google.com/vpc/docs/configure-private-services-access)의 connection 삭제 주의에 따르면 Cloud SQL service producer의 삭제 대기 때문에 마지막 인스턴스 삭제 후 최대4일간 연결 삭제가 실패할 수 있다.
- 반영: Phase09 실패 정리·정상 destroy에서 실패를 숨기지 않고 cleanup_required/state를 보존한다. 같은 run 재시도를 안내하고 강제 peering 삭제나 ABANDON으로 잔여 검사를 우회하지 않는다.
- 한계: 공식 문서 1개에 근거한 제한이며 이 프로젝트에서 4일 경과를 직접 측정한 결과가 아니다. 다른 producer·권한·네트워크 실패도 별도로 확인해야 한다.

## 설치 파일 lock — observed

- 2026-08-26 공식 WordPress 7.1 tar.gz·GCS Auth Proxy 2.25.2 linux.amd64·GitHub WP-CLI 2.12.0 phar를 다운로드해 SHA256을 계산했다. 값/URL은 `phases/09/assets.json`에 기록한다.
- WordPress release manifest와 tar의 version/최소 PHP를 대조했고, WP-CLI는 GitHub release digest와도 일치했다. Proxy는 공식 GCS 바이트 hash 관측이며 서명 검증을 주장하지 않는다. host에서 이 다운로드 binary를 실행하지 않았다.
- 근거: [WordPress releases](https://wordpress.org/download/releases/), [WP-CLI release API](https://api.github.com/repos/wp-cli/wp-cli/releases/latest), [Cloud SQL Auth Proxy 공식 설치](https://docs.cloud.google.com/sql/docs/mysql/connect-auth-proxy). 설치 파일 업데이트는 새 source/input/plan 승인이 필요하다.

## 실제 API 초기화와 PSA 정리 지연 — observed 2026-08-26, n=1

- D-033 run `p09-260826-5d82`에서 SQL users API 비밀번호 초기화·verify의 재설정 operation 완료를 관측했다. 이는 앞선 미검증 범위 중 API 경로만 검증한 것이며 WordPress 설치 성공은 아니다.
- verify의 guest 설정 단계 실패 후 SQL을 삭제했지만 PSA Delete는 Error9와 producer 사용 중으로 거부됐다. 별도 inventory/state에서 SQL/VM/disk0, 전용 network/range/ACTIVE peering3개 잔여를 관측했다. 앞선 공식 문서의 정리 지연 가능성이 실제 발생했으나 실제 해제까지4일이 걸리는지는 아직 측정하지 않았다.
- 근거: ignored `artifacts/phase-09-cloud-{apply,verify}.log`, 해당 run의 `database-initialized.json`·`verification-cleanup.log`·`evidence/phase-09-postfailure-audit.json`. 정확한 WordPress 실패 원인은 세부 오류 미보관으로 unknown이며 권한/CLI/DB 후보를 확정 사실로 기록하지 않는다.

## mysqli readiness 검사 근거 — confirmed (self-gated), 2026-08-26

- [PHP mysqli.options 공식 문서](https://www.php.net/manual/en/mysqli.options.php)는 init 이후·real_connect 이전에 연결/읽기 timeout 옵션을 설정하도록 명시한다. [mysqli.real_connect](https://www.php.net/manual/en/mysqli.real-connect.php)는 host/user/password/database/port 인자를 받는다.
- 적용: guest에서 JSON stdin으로만 DB 비밀번호를 받고 connect/read timeout5초·SELECT1을 수행한다. local tests는 child 프로세스를 mock하므로 실제 PHP DB 경로 성공을 입증하지 않는다. 과거 실패를 DB 준비 지연으로 확정하는 근거도 아니다.

## 재생성 이름·identity와 실패 보존 — 2026-08-26

- hearsay(공식 문서): [Cloud SQL instance 삭제](https://docs.cloud.google.com/sql/docs/mysql/delete-instance)는 삭제한 instance 이름의 즉시 재사용을 허용한다. PSA producer 정리 지연과 이름 재사용 제한을 혼동하지 않는다. 이번 수정에서 불필요한 새 SQL 이름 suffix를 추가하지 않았다. 실제 같은 이름 SQL 재생성 성공은 아직 관측하지 않았다.
- hearsay(공식 문서): [Service account 개요](https://docs.cloud.google.com/iam/docs/service-account-overview)는 같은 email로 다시 만든 SA도 새로운 고유 identity이며 옛 역할 binding을 상속하지 않는다고 설명한다. 복구는 생존 identity를 고정하고, 승인 create+TF state 기록에 해당하는 새 SA 등만 새 identity로 기록하도록 구현·오프라인 검사했다.
- observed: 두 번째 run Proxy는 connection 수락 직후 종료됐지만 기존 진단은 상세 errno를 버렸다. 당시 state 설정은 MYSQL_8_0·database_flags=[]·connector_enforcement NOT_REQUIRED·ssl_mode ALLOW_UNENCRYPTED_AND_ENCRYPTED였다. 강제 TLS·PHP 미설치를 원인으로 확정할 근거가 없다.
- unknown: mysqli 실제 오류 번호와 WordPress/SQL 전체 경로 성공. 새 숫자 errno 진단·보존 복구 코드의 오프라인 검증은 통과했으나 Cloud 재apply/검증은 새 계획 승인 대기다.
- 정책 경계: 앞선 자동 cleanup 사례는 역사다. D-036/D-037 이후 실패만으로 전체 destroy하지 않고 state/로그/리소스를 보존한다.

## Provider 기본 root 삭제와 MySQL1044 — observed / confirmed (self-gated), 2026-08-26

- Claim/observed: D-039 실행에서 비밀번호 API operation DONE 이후에도 root@%는 USAGE만 있고 wordpress DB 접근이1044였다. Proxy VM에서 localhost Auth Proxy와 SQL private IP 두 경로로 DB를 지정하지 않은 연결은 성공했고 CURRENT_ROLE=NONE·SHOW GRANTS=USAGE·DB 선택1044를 각각 확인했다. 직접 원인은 DB 접근 권한 누락이며 방화벽/비밀번호 인증 실패가 아니다.
- Sources: ignored `artifacts/runs/p09-260826-eb03/phase-09/evidence/read-only-db-privileges.json`의 읽기 전용 실측; [Google Provider7.45.0 실제 소스](https://github.com/hashicorp/terraform-provider-google/blob/v7.45.0/google/services/sql/resource_sql_database_instance.go#L1782)는 instance 생성 직후 root@%를 삭제한다. [Provider 리소스 설명](https://registry.terraform.io/providers/hashicorp/google/7.45.0/docs/resources/sql_database_instance)도 기본 root 삭제를 명시한다. 둘은 같은 Provider 근거이지 서로 독립된 두 표본이 아니다.
- Sample/limits: SQL1(MySQL8.0.45-google), 동일 VM의 연결2경로, 각1회 진단. WordPress 설치/별도 private VM의 전체 경로 성공은 아니다. 과거 두 실패의 상세 errno는 없어 동일 원인으로 확정하지 않는다. 삭제된 root에 users.update가 어떤 서버 내부 절차로 USAGE 계정을 만들었는지는 직접 추적하지 않았다.
- Claim/confirmed(self-gated): [users.insert](https://docs.cloud.google.com/sql/docs/mysql/admin-api/rest/v1/users/insert)는 User body로 사용자를 생성한다. [User](https://docs.cloud.google.com/sql/docs/mysql/admin-api/rest/v1/users)의 databaseRoles와 [users.update](https://docs.cloud.google.com/sql/docs/mysql/admin-api/rest/v1/users/update)의 databaseRoles query/revokeExistingRoles=false로 역할 추가를 지정한다. update body.databaseRoles는 무시되므로 query가 필요하다. [MySQL 사용자 권한](https://docs.cloud.google.com/sql/docs/mysql/users)의 cloudsqlsuperuser는 실습 root 관리자용이다. 이 근거는 직접 연 공식 문서/소스이며 실제 역할 복구 성공 표본은0이다.
- Contradiction/scope: 위의 “실제 API 초기화와 PSA 정리 지연”은 API operation 성공만 입증하며 DB 사용 가능성을 입증하지 않는다. 위 “재생성 이름·identity와 실패 보존”의 errno unknown은 이번 실행에 한해1044로 갱신하며, 같은 SQL 이름 재생성은 D-039 apply에서 성공했다. 당시 과거 관측은 유지한다.
- Applied: root 목록/정확한 host/type 검사 후 insert 또는 update+역할 추가를 코드·action-plan에 구현했다. 오프라인64개 검사가 통과했지만 Cloud 권한 변경은 새 exact SHA 승인 전이다. 1044를 transient로 반복해도 권한이 생기지 않으므로 별도 분류한다. 운영 애플리케이션의 최소권한 설계는 별도다.

## 기존 사용자 역할·비밀번호 요청 경계 — observed, 2026-08-26

- Claim: D-040 실행에서 비밀번호와 databaseRoles query를 합치고 body.type을 생략한 users.update는HTTP400, 대응UPDATE_USER operation은INTERNAL_ERROR였다. 원문은 보관되지 않아 세부 backend 원인은unknown이다. 이후 같은 SQL1/연결2경로 읽기 전용 재확인에서 root@% USAGE·wordpress1044가 유지됐다. 리소스/계정 삭제는 하지 않았다.
- Sources: ignored `artifacts/phase-09-root-role-cloud-apply.log`, `phase-09-root-role-api-operations.json`, `phase-09-root-role-postfailure-db.log`; [공식 역할 추가 안내](https://docs.cloud.google.com/sql/docs/mysql/create-manage-users#add-database-roles)는 BUILT_IN 명시와 역할/비밀번호 정책 동시 변경 제한을 설명한다. 로컬 공식gcloud581.0.0 `surface/sql/users/assign_roles.py`도 user.type을 명시한 별도 요청에 databaseRoles/revokeExistingRoles query를 보내고 password는 넣지 않는다. 같은 Google 서비스 문서/SDK이므로 독립된 backend 성공 표본 두 개로 계산하지 않는다.
- Sample/limits: 실패한 API 변경1회, SQL1·연결2경로 재조회. 비밀번호 값 변경과 비밀번호 정책은 다른 개념이며 공식 문구를 “모든 동시 비밀번호 변경 금지”로 확대하지 않는다. CLI와 요청형식 차이는 확인됐지만HTTP400의 정확한 원인은 아직미확정이다. 새 분리 요청의Cloud 성공 표본은0이다.
- Contradiction: 위 기존 “Provider 기본 root 삭제와1044”의 DB 권한 누락 관측은 유지한다. 그 이후64tests 보완이 실제 역할 복구를 입증한 것은 아니며 이번 실패로 “현재 보완은 승인 대기” 상태를 갱신한다. 새 구현은 type 명시·역할 operation 완료 후 별도 비밀번호 갱신이며, 실제 성공은 다음 승인 실행에서 별도검증한다.

## 분리 요청·실제 SQL/WordPress 성공 — observed, 2026-08-26 18:05 KST

- Claim: D-041에서 BUILT_IN 명시·비밀번호 없는 역할 요청 완료 후 별도 비밀번호 갱신이 apply/verify에서 성공했고HTTP400이재발하지않았다. Terraform0/0/0·기존리소스유지 상태로 Proxy/private guest 설치와 DB readiness를 통과했다. ProxySQL marker 쓰기→private VM 직접SQL 읽기, 두WordPress HTTP200/본문·SQL-backed HTTP probe 일치도 통과했다.
- Sources: ignored `artifacts/phase-09-separated-role-cloud-{apply,verify}.log`; run `p09-260826-eb03`의 `evidence/phase-09-machine.json`, `evidence/guest-install-{proxy,private}.json`, manifest verified. 독립된 별도운영환경 표본은아니며같은실행의검사들이다.
- Sample/limits: SQL1(MySQL8.0.45-google)·VM2·실습run1, apply/verify 각각의역할/비밀번호API처리. 없는root 신규insert·다른계정/DB버전/지역·Windows·장기운영은미검증. 기존HTTP400원문이없고type과요청순서를함께수정했으므로어느한항목만이유일한원인이었다고분리입증하지않았다. 모든향후400이없다는보장이아니다.
- Contradiction/scope: 위의API400·DB1044는이전실패의실제기록으로유지한다. 새분리요청의성공표본0·현재E2E미검증상태는이번실측으로갱신한다. 최종destroy를하지않아lab_completion.complete=false이며,리소스유지·계속과금은실습실패와다르다.
- 사후관측18:08 KST: 같은Proxy VM의두SQL경로에서활성cloudsqlsuperuser·wordpress선택성공/errno0을재확인했다(`evidence/read-only-db-privileges.json`). 별도수동SET ROLE/GRANT를실행하지않았으며분리API경로후로그인에서이미활성화돼있었다. 같은환경재확인이므로독립된환경표본은아니다.

## 성공한 실습의 명시적 destroy 후에도 PSA는 남을 수 있음 — observed, 2026-08-26

- Claim: D-042의 현재 성공 run을 정상 종료한 뒤 SQL/VM/disk/subnet/firewall/SA는0이지만 PSA 삭제 Error9로 VPC·할당 범위·서비스 연결3개가 남았다. Cloud SQL 삭제 성공과 전체 네트워크 정리는 별개다.
- Sources: ignored `artifacts/phase-09-user-destroy.log`, `phase-09-user-destroy-after.log`, `phase-09-user-destroy-peerings.json`, 해당 run state/manifest. [공식 Private services access 정리 설명](https://docs.cloud.google.com/vpc/docs/configure-private-services-access#deleting-connection)은 Cloud SQL producer의4일 대기와 직접 peering 강제 삭제 금지를 설명한다(2026-08-26 재조회).
- Sample/limits: 현재 run1의 종료 시도1회. 과거 별도 run에서도 같은 종류의 오류를 관측했지만 정확한 해제 소요 시간은 측정하지 않았다. 오류가 자연 해제되기 전 강제 삭제/state 제거로 우회하지 않는다. 과금 전체0·백업 복구 가능성까지 입증한 것은 아니다.
- Contradiction/scope: 앞선18:05 성공은 삭제 전 실습 검증 기록으로 유효하다. 리소스 유지 상태는 이번 명시적 종료로 갱신했으며 실패만으로 전체 삭제한 것은 아니다. Q-020과 이전 Q-012를 구분한다.
