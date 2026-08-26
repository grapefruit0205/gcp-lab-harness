# Phase 07 — Notion 본문 대조와 검증 범위

- 기준: [사용자 지정 07. Exploring IAM](https://app.notion.com/p/3c76d458853781ecbcf3d1c5e12f28dd), 2026-08-26 13:58 KST fetch 본문.
- 본문은 실제 사용자 A/B 방식이며 하단 Qwiklabs Markdown 첨부는 과거 참고 자료다. Notion과 `references/` 원문은 읽기 전용으로 보존했다.
- 판정: 구현 및 offline 검증. 실제 A/B OAuth identity 확인도 통과했으며 새 Cloud apply/E2E·Windows 실기동은 아직 미수행이다.

## Task별 요구와 반영

| Notion 요구 | 반영·증거 위치 | 경계 |
|---|---|---|
| 1: 서로 다른 실제 A/B, 로그인과 권한 구분 | `auth.py`/`auth.sh`의 사용자별 등록, OAuth userinfo와 명시적 account 검사 | 일반/시크릿 창 UI를 자동 조작했다고 주장하지 않음 |
| 2: A가 B에게 project Viewer 부여, B 조회·IAM 수정 불가 | `verify.sh`의 Viewer grant·project/bucket/policy read·policy-edit denial | Owner/Editor를 B에게 부여하지 않음 |
| 3: 비공개 Multi-region Standard bucket과 비민감 sample | Terraform의 US bucket, PAP/UBLA, run 고유 fixture | Terraform baseline은 검증 전 준비되므로 콘솔 클릭 순서 그대로는 아님 |
| 4: Viewer만 회수, 파일이 남아 있는 상태에서 B 접근 거부 | revoked-project/buckets/**storage-read** | 파일 부재를 권한 거부로 통과시키지 않음 |
| 5: project Object Viewer, B 실제 파일 읽기·목록 허용/쓰기 거부 | storage-list/read/write-deny; 최신 project get 역할과 실제 응답 대조 | 브라우저 인증 다운로드 대신 동일 B OAuth Storage API; 서명 URL/공개 파일 아님 |
| 6: A가 B에게 특정 SA actAs와 project Compute Admin 부여, **B가 VM 생성** | user2-vm-permissions action, user2-create-vm operation actor, user2-vm-running | A의 VM 생성으로 대체하지 않음. A의 SSH/IAP는 별도 |
| 7: metadata SA Viewer 읽기 허용/쓰기 거부 → Creator 쓰기 허용/**읽기 거부** | guest-object-read/write-deny, guest-creator-write/**read-deny** | SA에 사용자 token·키를 복사하지 않음 |
| 8: B 임시 역할 회수와 A 보존, 이번 리소스만 정리 | 4개 exact User2 tuple rollback, 3개 IAM baseline, rollback-admin-preserved, 소유권 destroy | machine 검증과 최종 리소스 정리는 별도. destroy 전 `lab_completion.complete=false` |

## 실제 변경

- 기존 User1 VM 생성 경로와 Terraform의 User1 workload actAs를 제거했다. Terraform baseline은 9개에서 **8개**로 줄었다.
- B의 actAs는 workload SA 하나에만, Compute Instance Admin은 프로젝트에 임시 부여한다. SA unique ID와 원래 빈 policy를 확인하고 A/기존 principal은 변경하지 않는다.
- operation HTTP 접수뿐 아니라 B actor·최종 DONE·실제 VM RUNNING·workload identity·private subnet을 검증한다.
- Creator 단계에서 sample 읽기 거부와 최종 B Compute/actAs 회수 검사, A 관리자 권한 보존 검사를 추가했다.
- 계정 등록은 특정 개인 이메일에 고정하지 않는다. `accounts setup`은 clone한 사람의 입력을 사용하고 최초 A 제안값도 그 환경의 활성 gcloud 사용자다. 개인 설정/credentials/state는 Git에 포함하지 않는다.

## 안전·승인 범위

project Storage 역할은 기존 버킷에, B의 project Compute Instance Admin은 **기존 VM에** 적용된다. 자동화 API의 실제 생성/삭제 대상은 고유 run 리소스로 제한되지만 역할 자체의 범위는 더 넓다. 새 plan/action bundle에 이 범위를 포함하고 exact SHA 승인 없이 적용하지 않는다. 조직 정책을 풀거나 SSH를 전체 공개하는 fallback은 없다.

새 Google 계정/프로젝트 생성, Qwiklabs 임시 계정 발급, 콘솔 UI 검사, Task 5까지만 수행하는 별도 단축 모드는 이번 구현에 포함하지 않는다. 전체 경로는 Task 6–7까지 포함한다. 정상 리소스 최종 destroy는 별도 승인 계약을 유지하고, 실패 시에는 run 소유 리소스만 자동 정리한다.

## 검증 기록

- observed 2026-08-26: Python 84 tests, Terraform mock 8 tests PASS. 실행 증거는 ignored `artifacts/phase-07-notion-unit.log`와 `phase-07-notion-mock.log`다.
- mock/격리 CLI 검사는 계정 등록, clone 사용자 기본값, IAM tuple/rollback, 잘못된 identity, 비동기 operation, private RUNNING 검사를 포함한다. 별도 읽기 전용 `accounts check`에서 현재 A/B의 실제 OAuth userinfo identity도 확인했다. 새 Cloud E2E 증거는 아니다.
- 기본 Storage 역할과 SA 연결 요구사항은 [Cloud Storage 역할](https://docs.cloud.google.com/storage/docs/access-control/iam-roles), [SA 연결 권한](https://docs.cloud.google.com/iam/docs/attach-service-accounts)을 대조했다.
