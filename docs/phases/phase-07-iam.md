# Phase 07 — IAM 탐색

- 원본: `references/google-cloud-labs-ko/labs/07.Exploring IAM_KR.md`
- 비용 위험: 중간
- 주요 서비스: IAM, Service Accounts, Cloud Storage, Compute Engine

## 목적

권한 부여·제거, Storage 한정 접근, Service Account User 역할과 VM 생성 권한의 차이를 격리된 test principal과 expected-denial 검사로 재현한다.

## 범위와 원본 매핑

| 원본 Task | 분류 | 자동화·증거 |
|---|---|---|
| Task 1. 두 사용자를 위한 설정하기 | cli-equivalent | 실제 사람 계정 대신 수명 제한 test service account 두 개와 가장 |
| Task 2. IAM 콘솔 살펴보기 | cli-equivalent | IAM policy·role permission의 구조화 조회 |
| Task 3. 액세스 테스트를 위한 리소스 준비하기 | automated | private bucket·sample object·baseline Viewer test |
| Task 4. 프로젝트 액세스 제거하기 | automated | role revoke 뒤 expected-denial reason/permission 검사 |
| Task 5. 스토리지 액세스 추가하기 | automated | 최소 Storage role 부여와 범위 내 성공·범위 밖 실패 |
| Task 6. Service Account User 설정하기 | automated | service account, actAs, Compute 권한, VM 생성 |
| Task 7. Service Account User 역할 살펴보기 | automated | actAs 유무에 따른 VM 생성 success/denial matrix |
| Task 8. Review | cli-equivalent | allow/deny matrix와 최종 rollback 검토 |

## 구현 작업

1. 조직 정책과 서비스 계정 가장 가능 여부를 read-only preflight한다.
2. 테스트 principal·resource·role binding 전체를 saved plan에 열거한다.
3. 각 권한 변경 전후 동일 명령을 실행해 success와 expected-denial을 수집한다.
4. denial은 상태 코드, 거부 permission, principal을 식별자 제거 형태로 검증한다.
5. 검토 승인 뒤 모든 binding을 먼저 회수하고 리소스와 test account를 삭제한다.

## 실행 계약

Command Code `cmd`는 현재 고정 모델을 상속하고 실제 사용자 두 명을 만들거나 로그인하지 않는다. 권한 변경은 allowlist role만 허용하고 primitive Owner/Editor를 부여하지 않는다. machine verification 후 모든 binding은 Extension 승인까지 manifest로 추적한다.

## 검증 게이트

- baseline, revoke, Storage-only, actAs 조합의 allow/deny matrix가 기대와 일치한다.
- expected-denial은 단순 nonzero가 아니라 해당 permission 거부임을 증명한다.
- 사용한 role과 scope가 원본 목표에 필요한 최소 범위다.
- Extension은 IAM policy와 audit log를 read-only API/Logging MCP로 대조한다.
- 사용자가 명시 승인한 뒤 binding rollback과 cleanup을 수행한다.

## 안전·비용 가드레일

- 실제 조직 사용자, 그룹, 기본 Compute service account를 변경하지 않는다.
- service account key를 생성하지 않고 단기 impersonation만 사용한다.
- role allowlist와 binding baseline hash가 다르면 apply·rollback 모두 중단한다.
- rollback은 이 run이 추가한 정확한 member-role-condition tuple에만 적용한다.

## 완료 조건

- Task 1–8과 모든 권한 전이가 coverage·matrix에 연결되어 있다.
- Extension review에서 privilege escalation·rollback 누락이 없고 사용자가 승인했다.
- cleanup 후 test account, binding, bucket, object, VM이 남지 않는다.

## Command Code·Extension handoff 지시

Command Code는 실제 사용자 로그인을 서비스 계정 가장과 동일하다고 숨기지 않고 `cli-equivalent` 경계를 보고한다. Extension은 execution identity와 verifier identity를 분리해 IAM policy·audit evidence를 확인한다.

## 현재 adapter

`phases/07/terraform`이 전용 VPC·비공개 bucket·격리 service account 3개와 최소 binding을 소유한다. `phases/07/verify.sh`는 immutable Debian image로 가장 VM을 만들고 project 조회 거부, object read 성공, write 거부, Viewer→Creator 전이를 실제 guest에서 확인한다.

## Git 종료 조건

`Phase 07: IAM 권한 경계 자동화 및 검증 완료` 커밋을 push하고 remote SHA가 확인된 뒤 Phase 08로 간다.
