# Checkpoint — Phase 08 구현·오프라인 검증 완료 — 2026-08-26 15:06

## The story so far

사용자의 “phase 8 구현 부탁해”에 따라 원본 Lab 08 Task 1–8과 기존 코드를 대조해 Cloud Storage adapter를 보완했다. region bucket/fine-grained ACL, memory-only CSEK rewrite와 구키·신키 matrix, 31일 lifecycle readback, 3세대 목록·크기·원본 로컬 복구, recursive rsync 개별 hash, 실패 cleanup을 연결했다. 실제 Cloud plan/apply/verify/destroy와 Git commit/push는 이번에 실행하지 않았다.

Python 40 tests, Terraform mock 4 tests 및 mock JSON 3개→plan guard, Phase 08 gate, shared Phase 07–15 offline suite, diff check가 통과했다. ignored 로그는 artifacts/phase-08-offline.log 및 phase-08-shared-offline.log다. 문서 실행 rehearsal 1회에서 새 실행자가 테스트·gate·help를 성공했고 Cloud 경계 앞에서 멈췄다.

이전 D-028/D-029 cleanup은 완료 상태를 유지한다. 이전 Terraform state는 비었고 기존 soft-deleted bucket의 보존은 별개다. 삭제 기록의 기존 미커밋 변경도 보존했다. 원격/HEAD는 7e6df290이고 dirty tree 때문에 pull/stash/reset하지 않았다.

## Decided

- D-027: clone한 사람이 자신의 로그인으로 사용. Phase 08은 실제 사용자 1명이며 이전 Phase 07 사용자 설정에 의존하지 않음.
- 새 run/project/actor/input/source SHA와 bucket 생성 identity·state 대상 검사, exact saved plan 승인 유지.
- 새로운 임시 Phase 08 bucket의 soft-delete=0과 fixture/메모리 API 키/선적용 정책 등 원문 대비 차이를 guide/action plan에 명시함. 기존 bucket 설정 변경 없음.
- 구현·테스트·문서만 작업했으며 새 Cloud 적용·commit·push 승인으로 확대하지 않음.

## Waiting on the user

구현 요청에 남은 질문은 없다. 실제 Cloud 실행은 새 run plan 검토·exact SHA 승인 후 진행할 별도 단계다.

## Next first action

`cd /home/grapefruit/gcp-lab-harness && bash tests/test-phase-08.sh`로 구현을 재확인하고, 실제 실행 요청 시 docs/phases/phase-08-cloud-storage.md의 새 run plan부터 진행한다.

## Tried

- 옵션 없는 gcloud objects update를 키 교체로 인정하지 않고 source/destination CSEK header를 분리한 JSON API rewrite로 교체했다.
- 인증·네트워크·404 실패를 예상 키 거부/삭제 성공으로 간주하지 않는다.
- Terraform mock은 region 대문자 정규화를 자동 수행하지 않아 코드에 upper(region)을 명시했다. lifecycle condition은 set이라 one()으로 검사한다.
- provider JSON의 action.storage_class=null을 guard가 허용하도록 고치고 실제 mock JSON 3개로 호환성을 검사했다.
- 문서 첫 개정에서 원본 경로 줄 suffix와 필수 제목 변경이 gate를 깨뜨려 원래 계약 형식을 복구했다.
- Google provider가 추가하는 goog-terraform-provisioned label은 허용하면서 소유 label 3개·bucket 생성 시각은 검사한다.
