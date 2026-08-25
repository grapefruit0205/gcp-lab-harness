# Foundation B — 상태 머신·승인·증거·Git 코어

이 문서는 Lab adapter가 공유하는 deterministic controller의 구현 계약이다.

## 공통 명령

```text
gcp-lab-harness doctor
gcp-lab-harness run-all
gcp-lab-harness run init --run <id> [--mode cloud|offline]
gcp-lab-harness status --run <id>
gcp-lab-harness resume --run <id>
gcp-lab-harness hash <file>
gcp-lab-harness gate prepare|approve|reject <NN> --run <id> --*-hash <sha256>
gcp-lab-harness phase plan|apply|verify|destroy <NN> # adapter 구현 예정
gcp-lab-harness inventory <NN> --run <id>
```

Foundation B 명령은 `run init`, `status`, `resume`, `hash`, `gate prepare|approve|reject`다. `run-all --run <id>`는 Phase 01–15 adapter와 연결된 단일 Command Code supervisor를 열며, 각 Phase의 saved plan 승인과 Extension 사용자 승인에서 대기한다.

## 공통 상태

`pending -> synced -> preflight -> planned -> applied -> machine_verified -> waiting_extension_review -> human_approved -> destroyed -> committed -> pushed`

반려는 같은 Command Code session의 수정·재검증으로 돌아간다. stale approval, cleanup 실패, push 실패가 있으면 다음 Phase로 전이하지 않는다.

## 공통 안전 계약

- 저장된 plan hash와 run ID의 명시 승인 없이 apply 금지
- manifest가 소유권을 증명한 리소스만 destroy
- 원시 artifact는 0700 디렉터리와 Git ignore
- pipeline과 approval은 0600 파일로 작성한 뒤 같은 filesystem에서 atomic rename
- approval은 plan/diff/evidence hash를 묶고 현재 review bundle과 다르면 stale로 거부
- Phase가 선언한 path만 stage하고 Phase당 한국어 commit 하나
- remote main drift가 있으면 자동 rebase/merge 금지
- Phase 시작 전 clean working tree에서 `git pull --ff-only` 성공 필수

## offline 검증

`tests/offline-controller.sh`는 상태 초기화, 정상 전이, 잘못된 전이 차단, Extension 반려, stale 승인 거부, 승인, resume를 외부 변경 없이 확인한다. apply 중단, expected-denial, cleanup 실패, push 실패 fixture는 해당 실행 adapter와 Git supervisor를 연결할 때 추가한다.
