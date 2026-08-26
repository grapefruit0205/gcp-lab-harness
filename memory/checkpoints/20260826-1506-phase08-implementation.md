# Checkpoint — Phase 08 구현 착수 — 2026-08-26 14:52

## The story so far

사용자가 Phase 8 구현을 요청했다. 원본 Lab 08과 기존 adapter를 대조 중이다. 기존 코드의 CSEK rewrite 옵션 누락, 실패를 예상 거부/삭제 성공으로 오판, 동기화 hash 미검사를 보완한다. 이번 작업은 구현·로컬 검증이며 신규 Cloud apply/commit/push는 실행하지 않는다. 아직 Phase 08 소스 변경은 없다. 원격 main은 HEAD 7e6df290과 같으며 미커밋 삭제 기록 때문에 pull/stash/reset하지 않았다.

D-028/D-029에 따라 이전 하네스 실습과 남겨둔 5개를 새 백업 없이 정리했다. Minecraft 관련 Terraform 10개, 추가 bucket의 전체 버전·snapshot·firewall을 삭제했다. 두 수동 SA는 새 작업 시작 전 이미 없어졌으며 남은 project IAM tombstone 4개를 회수했다.

실제 VM/disk/IP/router 0(직전 검증), live bucket/snapshot 0, 지정 추가 대상 5개의 활성 잔여 0이다. 모든 이전 Terraform state는 비었고 미적용 Phase 4/7/foundation plan은 생성 없이 종료했다. default network/기본 firewall 3개/default compute SA·공통 API·project/ADC/billing은 유지했다. 다른 project IAM은 대상 4개 제거 외 동일하다.

증거는 ignored `artifacts/cleanup-before-phase08.PSOwfC/result.json` 및 `artifacts/cleanup-extra-before-phase08.zWWylo/result.json`이다. 새 백업은 만들지 않았지만 bucket의 기존 7일 soft-delete 복구 보존은 별개로 남는다. Minecraft bucket API hardDeleteTime은 2026-09-02 14:40:59 KST다.

## Decided

- D-028: Minecraft·월드를 포함한 이전 하네스 실습 무백업 정리.
- D-029: 남겨둔 추가 5개와 두 삭제 SA의 IAM 잔여도 정리. Q-008 closed.
- 사용자 지시: 이미 명시된 같은 삭제 범위에 추가 승인 질문을 반복하지 않고 진행한다. 필요한 식별/사후 검사는 별도 질문 없이 수행한다.
- 소스/원문/계정 설정·전역 규칙 카탈로그는 변경하지 않았고 commit/push/Phase 8 apply는 하지 않았다.

## Waiting on the user

Phase 8 구현을 계속하기 위해 필요한 질문은 없다. Cloud apply는 아직 승인된 새 plan이 없다.

## Next first action

`cd /home/grapefruit/gcp-lab-harness && cat phases/08/verify.sh`를 기준으로 공식 Storage API 문서와 CSEK·ACL·버전·실패 정리 동작을 대조하고 구현한다.

## Tried

- 오래된 verified manifest는 실제 존재 증거가 아니었으며 Phase 5는 stale state만 정리했다.
- soft-deleted bucket의 gcloud JSON 목록 HTTP404를 잔여 0으로 오판하지 않고 공식 REST API로 보존 상태를 확인했다.
- 수동 SA 두 개는 이미 삭제됐어도 project IAM의 deleted principal binding이 남아 있었다. 정확한 UID/role 4개만 제거하고 다른 IAM 보존을 비교했다.
- “백업 없이 삭제”는 Cloud의 기존 soft-delete 기간을 우회하거나 즉시 영구 삭제했다고 주장할 근거가 아니다.
