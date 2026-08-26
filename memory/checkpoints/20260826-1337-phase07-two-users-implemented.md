# Checkpoint — Phase 07 실제 사용자 두 계정으로 전환 — 2026-08-26 13:22

## The story so far

사용자는 원문이 실제 사용자 두 계정 실습임을 지적하고 “원문대로 진행할 수 있도록 자동화 구현 수정해줘”라고 요청했다(D-024). 계정 1은 현재 활성 사용자, 계정 2는 사용자가 지정한 개인 Google 계정이다. 값은 ignored `config/phase-07-users.json`(600)에만 보존한다. 현재 gcloud에는 사용자 계정 하나만 인증돼 있다. 실제 계정 2 로그인은 사용자 브라우저 인증이 필요하며 아직 수행하지 않았다.

observed: D-023의 `p07-260826-a9d2`는 apply/read-only/no-drift, 수정된 비동기 IAM matrix·VM 생성, guest Compute deny/read allow/write deny→Creator write까지 통과했다. 최종 actor2 Storage 회수 확인의 403 permission 판정에서 실패해 자동 cleanup했다. VM/bootdisk 포함 소유 리소스와 Terraform 13개 삭제, 잔여 0, project IAM baseline 복구, 빈 state, Minecraft before/after 동일을 확인했다. 모든 실행 session은 끝났다. 공용 Resource Manager API만 계획대로 활성 유지다. 원문 계정 두 개 실습 완료로 주장하지 않는다.

새 요청의 실행 코드 변경은 아직 시작하지 않았다. 현재 변경은 D-024/Q-007 기록, .gitignore의 config 예외, ignored 두 사용자 설정뿐이다. 기존 Phase 07 source는 old run `approved-source/`에 보존했다. 원문 전체를 읽었고 이제 실제 두 사용자 OAuth 인증·project-level 역할 흐름으로 코드를 교체해야 한다. old active Phase 07 run은 모두 destroyed이며 f8e2는 never-applied stale planned다.

## Decided

- D-024: SA 두 개의 가장으로 실제 사용자 두 계정 인증을 대체하지 않는다. User1/User2와 VM workload SA를 분리한다. 이메일은 로컬 ignored 설정에만 둔다.
- 실제 IAM 변경은 새 사용자 인증·새 plan SHA 승인 뒤다. 현재 요청은 구현 수정이며 기존 승인 SHA를 새 코드에 재사용하지 않는다. commit·push·Phase 06 변경은 승인 범위가 아니다.
- 원문의 가상 altostrat.com domain에는 실제 IAM 권한을 부여하지 않는다. 콘솔 UI 조작과 CLI 자동 검사도 구분한다.

## Waiting on the user

계정 2 이메일 지정은 완료됐다. 구현은 바로 진행한다. 실제 Cloud plan/apply 전 계정 2 브라우저 인증과 새 plan 승인이 필요하다. `gcloud auth login --no-activate`는 기본 활성 계정을 바꾸지 않는 것으로 로컬 CLI help에서 확인했다.

## Next first action

`/home/grapefruit/gcp-lab-harness/phases/07/`의 Terraform·execute·support·probe·verify·tests를 실제 두 사용자 OAuth 방식으로 수정한다. 고정 actor SA 두 개와 TokenCreator binding을 제거하고 workload SA 하나만 남긴다. 현재 실행 중인 cloud process는 없다.

## Tried

- 사용자 OAuth의 Resource Manager HTTP200을 새 SA의 API consumer 활성화 증거로 쓰면 안 된다. 같은 endpoint에 SA는 SERVICE_DISABLED를 반환했다. 오류는 old run `baseline-project-error.json`에 보존했다.
- cleanup inventory의 `gcloud compute subnetworks list`는 잘못된 CLI다. `gcloud compute networks subnets list`로 수정해 실 API 재검사와 회귀 테스트를 통과했다. 첫 자동 cleanup의 실패는 실제 Terraform 삭제 실패가 아니라 이 후속 검사의 실패였다.
- old run은 source hash도 stale이고 리소스가 이미 삭제됐다. 재apply하지 않는다. c4b7/f8e2 중간 후보도 사용하지 않는다.
- 새 runner의 serviceusage enable·IAP tunnel·OS Login·actAs project testIamPermissions는 HTTP200, missing=[]였지만 실제 Cloud 실습 완료를 대신하지 않는다.
- 새 plan의 source/inputs/action/bundle/Terraform hash와 정확한 13개 구성을 재검사했다. source를 수정하면 새 계획이 다시 필요하다.
- e6a1의 HTTP 2xx는 생성 완료가 아니었다. `failed-create-operations.json`과 `failed-create-instances.json`을 보존했고 최종 비동기 오류 판정으로 고쳤다. `memory/knowledge/gcp-compute-operation-iam.md` 참고. 단순 대기 늘리기나 권한 확대는 이 오류의 해결책이 아니다.
- 현재 실제 `roles/storage.objectViewer`의 includedPermissions에는 `resourcemanager.projects.get/list`가 포함된다. 원문처럼 project-level로 부여한 뒤 project GET 거부를 강제하면 거짓 실패다. 실제 role permission을 조회하고 객체 읽기/목록 성공·객체 쓰기/Compute/IAM 변경 거부로 경계를 검증해야 한다. 원문 자체는 보존한다.
- a9d2 최종 Storage 회수 확인은 구체 permission 없는/다른 403을 거부로 인정하지 않아 실패했다. 새 user 경로에서는 Cloud Storage `testIamPermissions`로 같은 authenticated user의 필요한 permission 부재를 보강하는 방안을 검토하고, API/scope/인증 오류를 거부로 통과시키지 않는다.
