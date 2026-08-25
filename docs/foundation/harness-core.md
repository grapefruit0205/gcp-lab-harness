# Foundation B — 상태 머신·승인·증거·Git 코어

이 문서는 Lab adapter가 공유하는 deterministic controller의 구현 계약이다.

## 공통 명령

```text
gcp-lab-harness doctor
gcp-lab-harness run-all
gcp-lab-harness resume --run <id>
gcp-lab-harness phase plan|apply|verify|destroy <NN>
gcp-lab-harness gate approve|reject <NN> --run <id>
gcp-lab-harness inventory <NN> --run <id>
```

## 공통 상태

`synced -> preflight -> planned -> applied -> machine_verified -> waiting_extension_review -> human_approved -> destroyed -> committed -> pushed`

반려는 같은 Command Code session의 수정·재검증으로 돌아간다. stale approval, cleanup 실패, push 실패가 있으면 다음 Phase로 전이하지 않는다.

## 공통 안전 계약

- 저장된 plan hash와 run ID의 명시 승인 없이 apply 금지
- manifest가 소유권을 증명한 리소스만 destroy
- 원시 artifact는 0700 디렉터리와 Git ignore
- approval은 plan/diff/evidence hash를 묶은 atomic JSON
- Phase가 선언한 path만 stage하고 Phase당 한국어 commit 하나
- remote main drift가 있으면 자동 rebase/merge 금지
- Phase 시작 전 clean working tree에서 `git pull --ff-only` 성공 필수

## offline 검증

fake provider로 정상, apply 중단, expected-denial, Extension 반려, stale 승인, cleanup 실패, push 실패, resume를 모두 재현해야 한다.
