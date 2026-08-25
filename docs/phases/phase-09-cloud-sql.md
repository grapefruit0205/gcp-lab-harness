# Phase 09 — Cloud SQL 구현

- 원본: `references/google-cloud-labs-ko/labs/09.Implementing Cloud SQL_KR.md`
- 비용 위험: 높음
- 주요 서비스: Cloud SQL, Compute Engine, WordPress, Cloud SQL Auth Proxy, private services access

## 목적

Cloud SQL 데이터베이스와 두 WordPress VM을 구성하고 Auth Proxy 및 내부 IP 연결 경로를 실제 SQL·HTTP 트랜잭션으로 검증한다.

## 범위와 원본 매핑

| 원본 Task | 분류 | 자동화·증거 |
|---|---|---|
| Task 1. Cloud SQL 데이터베이스 생성하기 | automated | instance·database·user readiness와 SQL query |
| Task 2. 두 가상 머신에 WordPress 설치하기 | automated | 두 VM의 package·web/PHP·WordPress HTTP readiness |
| Task 3. 가상 머신에 프록시 구성하기 | automated | Auth Proxy system service·socket/port·로그 상태 |
| Task 4. 애플리케이션을 Cloud SQL 인스턴스에 연결하기 | automated | WordPress DB transaction과 두 frontend HTTP 응답 |
| Task 5. 내부 IP를 통해 Cloud SQL에 연결하기 | automated | private services access와 private address SQL 경로 |
| Task 6. Review | cli-equivalent | DB·proxy·app·private path evidence 검토 |

## 구현 작업

1. SQL engine/version, region, private range, quota, 예상 시간과 비용을 preflight한다.
2. instance·database·network·VM·service account를 saved plan에 고정한다.
3. 비밀번호를 Secret Manager 또는 안전한 runtime input으로 전달하고 artifact에서 redaction한다.
4. Proxy identity와 최소 IAM을 구성해 SQL query를 실행한다.
5. 두 WordPress frontend에서 실제 create/read가 같은 database에 반영되는지 확인한다.

## 실행 계약

Command Code `cmd`는 현재 고정 모델로 장시간 Cloud SQL 작업을 timeout polling하며 모델 인수를 전달받지 않는다. apply는 높은 비용 등급과 saved plan의 명시 승인 없이는 거부한다. machine verification 뒤 Extension 판정까지 인스턴스를 유지하되 최대 보존 시간을 둔다.

## 검증 게이트

- SQL instance engine·region·network mode와 plan이 일치한다.
- Auth Proxy가 인증된 identity로 연결되고 test SQL이 성공한다.
- 두 WordPress VM이 정상 HTTP를 반환하고 DB state를 공유한다.
- private IP 경로에서 SQL 연결이 성공하며 public path 의존이 없다.
- Extension은 SQL/Compute/VPC read-only 조회, secret scan 후 사용자 승인을 요청한다.

## 안전·비용 가드레일

- 최소 tier·storage 상한·backup 정책·최대 실행 시간을 명시한다.
- DB 비밀번호, cookies, connection string, private IP를 Git evidence에 남기지 않는다.
- Authorized Networks로 광범위 public access를 열지 않는다.
- 삭제 보호를 plan에서 명시하고 cleanup 시 DB, peering/range, VM, disk 순서를 안전하게 처리한다.

## 완료 조건

- Task 1–6 coverage와 SQL·proxy·WordPress·private path 증거가 있다.
- Extension에서 P0/P1과 비밀 유출이 없고 사용자가 승인했다.
- cleanup 후 Cloud SQL, VM, network attachment, secret version 등 run 소유 리소스가 0이다.

## Command Code·Extension handoff 지시

Command Code는 UI 화면 대신 SQL·HTTP 트랜잭션으로 결과를 증명하고 비밀을 출력하지 않는다. Extension은 read-only Cloud 상태와 redacted evidence를 대조하며 높은 비용의 보존 시간을 사용자에게 알린다.

## 현재 adapter

`phases/09/terraform`은 pinned HTTPS artifact 세트, private service access, MySQL 8 public·private address, Auth Proxy VM과 private-direct VM을 만든다. verifier는 ignored 0600 runtime 비밀번호를 guest에 전달해 두 경로가 같은 SQL marker를 공유하는지와 제한 CIDR의 두 WordPress HTTP endpoint를 확인한 뒤 로컬 비밀을 삭제한다.

## Git 종료 조건

`Phase 09: Cloud SQL과 WordPress 연결 자동화 및 검증 완료`를 커밋·push하고 remote SHA를 확인해야 Phase 10으로 진행한다.
