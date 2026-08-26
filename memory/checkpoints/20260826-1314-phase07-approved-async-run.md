# Checkpoint — Phase 07 비동기 판정 수정·새 plan 승인 대기 — 2026-08-26 13:11

## The story so far

observed: D-022 run `p07-260826-e6a1`은 13개 apply와 read-only/no-drift를 통과했다. IAM 실습의 Viewer·Storage·actAs-only 경계도 통과했지만 Compute-only insert의 HTTP 2xx를 생성 성공으로 오판해 중단했다. 실제 최종 operation은 `DONE`·HTTP error 400·`SERVICE_ACCOUNT_ACCESS_DENIED`, VM inventory는 빈 배열이었다. 실패 cleanup으로 13개를 정리했고 manifest destroyed/completed/remaining=0이다. 공용 Resource Manager API는 계획대로 활성 유지, project IAM hash 복구·빈 Terraform state를 확인했다. Minecraft는 같은 ID/IP/start/RUNNING이다.

비동기 operation의 정확한 identity와 최종 결과·actAs 부재·VM 부재를 검사하도록 수정했다. Python 36개·Terraform mock 6개·Bash/fmt/validate/Phase gate/07–15 offline suite와 실제 캡처 operation offline replay가 통과했다. 새 run `p07-260826-a9d2`는 13 create·0 update·0 delete로 planned, 아직 apply하지 않았다. 새 source/inputs/action/bundle/Terraform hash도 일치한다. 실행 중인 session은 없다. 수정 후 Cloud E2E/guest는 미검증이다.

## Decided

- D-021/D-022의 승인은 각 old SHA의 apply·실패 cleanup까지 사용했다. 새 코드/새 run으로 확대하지 않는다.
- 새 승인 후보: run `p07-260826-a9d2`, bundle `85a107f4f0bd2bbf4ab084d3babb563cc74d15dafb1b2aacdb8c8b1f70e89653`.
- 새 plan은 `cloudresourcemanager.googleapis.com`만 활성화한다. destroy 때 다른 workload에 영향을 주지 않도록 공용 API는 활성 상태로 유지한다. IAM 임시 grant는 검증 종료 시 회수하고 최종 destroy·commit·push는 별도 승인이다.

## Waiting on the user

새 bundle SHA의 재apply·IAM 검증 승인. 승인 전에는 Cloud를 다시 생성하지 않는다. 최종 destroy·commit·push는 별도다.

## Next first action

`sha256sum /home/grapefruit/gcp-lab-harness/artifacts/runs/p07-260826-a9d2/phase-07/plan-bundle.json`으로 새 후보를 재확인하고, 사용자 승인 후에만 승인 기록·plan backup·apply·read-only check·실제 verify를 진행한다.

## Tried

- 사용자 OAuth의 Resource Manager HTTP200을 새 SA의 API consumer 활성화 증거로 쓰면 안 된다. 같은 endpoint에 SA는 SERVICE_DISABLED를 반환했다. 오류는 old run `baseline-project-error.json`에 보존했다.
- cleanup inventory의 `gcloud compute subnetworks list`는 잘못된 CLI다. `gcloud compute networks subnets list`로 수정해 실 API 재검사와 회귀 테스트를 통과했다. 첫 자동 cleanup의 실패는 실제 Terraform 삭제 실패가 아니라 이 후속 검사의 실패였다.
- old run은 source hash도 stale이고 리소스가 이미 삭제됐다. 재apply하지 않는다. c4b7/f8e2 중간 후보도 사용하지 않는다.
- 새 runner의 serviceusage enable·IAP tunnel·OS Login·actAs project testIamPermissions는 HTTP200, missing=[]였지만 실제 Cloud 실습 완료를 대신하지 않는다.
- 새 plan의 source/inputs/action/bundle/Terraform hash와 정확한 13개 구성을 재검사했다. source를 수정하면 새 계획이 다시 필요하다.
- e6a1의 HTTP 2xx는 생성 완료가 아니었다. `failed-create-operations.json`과 `failed-create-instances.json`을 보존했고 최종 비동기 오류 판정으로 고쳤다. `memory/knowledge/gcp-compute-operation-iam.md` 참고. 단순 대기 늘리기나 권한 확대는 이 오류의 해결책이 아니다.
