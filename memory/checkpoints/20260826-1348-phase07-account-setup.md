# Checkpoint — Phase 07 실제 두 사용자 구현·수동 실습 안내 — 2026-08-26 13:37

## The story so far

D-024의 실제 사용자 두 계정 방식으로 Phase 07 Terraform·인증·execute·verify·회귀 테스트와 문서를 수정했다. User1/User2는 각자의 OAuth를 사용하고 VM에는 별도 workload SA 하나만 연결한다. 개인정보는 ignored 로컬 설정(600)에만 보관한다. 원본 references 및 Phase 06 코드는 변경하지 않았다.

observed: 최종 Python 47 tests, Terraform mock 8 tests, validate/fmt, 개별 Bash syntax, Phase gate와 Phase 07–15 offline suite가 통과했다. 실제 User1 OAuth·관리 권한 확인은 통과했고 User2는 미인증이다. plan 진입점은 User2 인증 전에 종료하며 run/plan을 생성하지 않는 것을 확인했다. 새 Cloud apply·E2E·commit·push는 수행하지 않았다.

이전 승인 run a9d2는 마지막 Storage 거부 판정 실패 후 소유 VM/bootdisk와 Terraform 13개 cleanup, 잔여 0·IAM baseline 복구·빈 state·Minecraft before/after 동일로 종료했다. 새 구현의 전체 Cloud 성공으로 취급하지 않는다. 문서 rehearsal은 독립된 같은 모델이 인증 수동 경계까지 1회 점검했다(당시 offline 44 tests, 이후 root 최종 47 tests). Cloud E2E rehearsal은 아니다.

사용자의 최신 질문은 Qwiklabs의 역할과 수동 실습 방법이다. 원문 Task 1/2 및 공식 Exploring IAM·Start a lab·Lab provisioning 안내를 읽었다. Qwiklabs가 임시 사용자 두 개·프로젝트·초기 역할·접속정보·종료 정리를 제공한다는 전제를, 개인 계정 실습의 직접 준비·요금·정리 책임과 구분해 설명한다.

## Decided

- D-024: 실제 인간 사용자 두 개를 SA 가장으로 대체하지 않는다. 가상 altostrat.com domain에는 권한을 부여하지 않는다.
- 새 IAM 변경/apply는 두 계정 인증 및 새 saved plan SHA 승인 뒤에만 수행한다. 이전 SHA를 재사용하지 않는다.
- 원문 project-level Storage 역할은 기존 모든 버킷까지 영향을 줄 수 있음을 문서와 action plan에 명시했다. Phase 06 서버와 원문은 보존한다.
- 수동 실습 질문은 Cloud 변경·권한 부여·실습 전용 새 프로젝트 생성 승인이 아니다.

## Waiting on the user

자동 실행을 재개하려면 User2 브라우저 인증이 필요하다. 이후 새 plan의 정확한 SHA 승인이 필요하다. 사용자는 현재 수동 실습을 이해하려고 질문 중이므로 로그인/apply를 자동으로 시작하지 않는다.

## Next first action

사용자가 자동 실행 재개를 요청하면 `cd /home/grapefruit/gcp-lab-harness && ./phases/07/auth.sh --check`로 실제 두 사용자 인증 상태부터 재확인한다. 수동 질문에는 원문과 플랫폼 제공 환경의 차이를 먼저 설명한다.

## Tried

- SA 두 개의 대체 검증은 원문의 실제 사용자 로그인 두 개와 같지 않다. 원문 완료로 주장하지 않는다.
- VM insert HTTP200은 생성 완료가 아니다. 최종 zone operation과 정확한 IAM 오류·VM 부재를 확인한다.
- 프로젝트 testIamPermissions로 Storage 객체 권한을 검증하면 거짓 실패할 수 있다. 객체 권한은 해당 버킷 endpoint로 검증한다.
- 실제 Storage Object Viewer 역할에 project get/list가 포함될 수 있으므로 Task 5 이후 프로젝트 조회 거부를 고정 기대하지 않는다.
- 일반 403을 곧바로 IAM 거부로 통과시키지 않는다. 같은 인증 주체의 testIamPermissions로 필요한 권한 부재를 보강하고 API/scope/인증 오류는 실패 처리한다.
- old run은 모두 정리됐거나 never-applied stale plan이다. source가 다른 기존 승인을 재사용하지 않는다.
