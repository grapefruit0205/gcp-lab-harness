# Checkpoint — Phase 08 수정본 게시·새 plan 승인 대기 — 2026-08-26 15:31

## The story so far

D-030 승인 run `p08-260826-8c1d`는 Terraform bucket 1개 생성과 정책 readback에 성공했으나 실제 실습은 HTTP401로 실패했다. 자동 cleanup으로 1개를 삭제했고 빈 state·활성 bucket 0·soft-deleted bucket 0을 확인했다. Cloud 실습 전체 성공은 아니다.

다운로드 오류를 JSON으로만 가정하던 처리를 수정했다. 익명 거부에는 인증 다운로드 전후 대조를, 비정형 CSEK 오류에는 동일 세대·키 metadata의 정확한 거부 검사를 추가했다. Python44·Terraform mock4/JSON guard3·Phase08 gate·Phase07–15 suite가 통과했다. 원래401의 정확한 요청 위치는 이전 로그만으로 확정할 수 없다.

수정본 새 run `p08-260826-c924` plan은 bucket `gcp-lab-p08-p08-260826-c924` 1개 create/change0/destroy0, bundle SHA `1222d79e290b309f117390ff457b5da1aa2577fef1a30bec32aa770ef575450a`다. hash/scope/manifest planned를 재검사했으며 아직 apply하지 않았다. 관련 24개 파일은 한국어 commit `33eae83edf73ccf272b6a8f352de4ecd3e14cd95`로 게시했고 15:30에 원격 main SHA 일치를 확인했다. 개인 설정·CSEK·state·원시 로그는 게시하지 않았다.

## Decided

- D-030: 첫 saved plan apply·실습 검증·관련 변경 stage/한국어 commit/push 승인. 실패 run 정리 완료.
- D-017/D-027: 실행 코드·입력·실제 사용자와 exact saved plan을 고정하며 clone 사용자 계정을 사용한다. 수정본 plan은 새 승인이 필요하다.
- 정상 성공 후 bucket 전체 destroy는 이번 승인에 포함하지 않는다. 앞선 D-028/D-029 정리 결과는 유지한다.

## Waiting on the user

Q-009: 새 SHA `1222d79e290b309f117390ff457b5da1aa2577fef1a30bec32aa770ef575450a`의 apply·실습 재검증 승인 대기. 새 bucket 1개, fixture 임시 공개/회수, soft-delete=0, CSEK 암호화 세대 삭제와 실패 cleanup은 동일한 범위다.

## Next first action

Q-009에 대한 사용자 승인을 확인한 뒤에만 `cd /home/grapefruit/gcp-lab-harness && ./phases/08/execute.sh apply --run p08-260826-c924 --confirm-plan-sha 1222d79e290b309f117390ff457b5da1aa2577fef1a30bec32aa770ef575450a`를 실행한다.

## Tried

- 최초 verify HTTP401 → 실패 cleanup 성공. 오류 원문을 남기지 않은 기존 로그로는 요청 위치를 확정할 수 없어 안전한 단계·오류 형식 진단을 추가했다.
- 다운로드 오류의 JSON-only 판정 → 삭제된 정확한 bucket에 대한 읽기 전용 GET에서 일반 텍스트404를 관측했다. 상태 코드만의 오탐도 막도록 인증 전후 대조/구체 CSEK metadata 검사를 추가했다.
- 이전 source SHA 승인을 수정 코드에 재사용하지 않는다. 새 run/plan으로 준비했다.
