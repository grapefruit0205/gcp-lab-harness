# Checkpoint — Phase 07 비동기 수정 plan 적용 성공·검증 시작 — 2026-08-26 13:14

## The story so far

observed: D-022 run `p07-260826-e6a1`은 13개 apply와 read-only/no-drift를 통과했다. IAM 실습의 Viewer·Storage·actAs-only 경계도 통과했지만 Compute-only insert의 HTTP 2xx를 생성 성공으로 오판해 중단했다. 실제 최종 operation은 `DONE`·HTTP error 400·`SERVICE_ACCOUNT_ACCESS_DENIED`, VM inventory는 빈 배열이었다. 실패 cleanup으로 13개를 정리했고 manifest destroyed/completed/remaining=0이다. 공용 Resource Manager API는 계획대로 활성 유지, project IAM hash 복구·빈 Terraform state를 확인했다. Minecraft는 같은 ID/IP/start/RUNNING이다.

비동기 operation의 정확한 identity와 최종 결과·actAs 부재·VM 부재를 검사하도록 수정했고 Python 36개·Terraform mock 6개·정적/offline gate를 통과했다. 사용자가 새 run `p07-260826-a9d2`를 D-023으로 승인했다. hash/source/inputs/runner 대조 후 apply가 13 added·0 changed·0 destroyed로 완료됐다. read-only applied/no-drift 검사 session `62441`이 진행 중이다. 이 검사가 통과하면 실제 `execute.sh verify --run p07-260826-a9d2`를 실행한다. guest/전체 IAM 검증은 아직 완료하지 않았다.

## Decided

- D-021/D-022의 승인은 각 old SHA의 apply·실패 cleanup까지 사용했다. 새 코드/새 run으로 확대하지 않는다.
- D-023: 사용자 “ㅇㅇ”가 run `p07-260826-a9d2`, bundle `85a107f4f0bd2bbf4ab084d3babb563cc74d15dafb1b2aacdb8c8b1f70e89653`의 apply·IAM 실습·임시 권한 회수·실패 cleanup을 승인했다.
- 새 plan은 `cloudresourcemanager.googleapis.com`만 활성화한다. destroy 때 다른 workload에 영향을 주지 않도록 공용 API는 활성 상태로 유지한다. IAM 임시 grant는 검증 종료 시 회수하고 최종 destroy·commit·push는 별도 승인이다.

## Waiting on the user

현재 없음. 승인된 IAM 검증을 계속한다. 최종 destroy·commit·push는 별도다.

## Next first action

session `62441`의 read-only/no-drift 완료를 확인하고 `/home/grapefruit/gcp-lab-harness/phases/07/execute.sh verify --run p07-260826-a9d2`를 45분 제한·run verify.log 캡처로 실행한다. 재apply나 코드 변경은 하지 않는다.

## Tried

- 사용자 OAuth의 Resource Manager HTTP200을 새 SA의 API consumer 활성화 증거로 쓰면 안 된다. 같은 endpoint에 SA는 SERVICE_DISABLED를 반환했다. 오류는 old run `baseline-project-error.json`에 보존했다.
- cleanup inventory의 `gcloud compute subnetworks list`는 잘못된 CLI다. `gcloud compute networks subnets list`로 수정해 실 API 재검사와 회귀 테스트를 통과했다. 첫 자동 cleanup의 실패는 실제 Terraform 삭제 실패가 아니라 이 후속 검사의 실패였다.
- old run은 source hash도 stale이고 리소스가 이미 삭제됐다. 재apply하지 않는다. c4b7/f8e2 중간 후보도 사용하지 않는다.
- 새 runner의 serviceusage enable·IAP tunnel·OS Login·actAs project testIamPermissions는 HTTP200, missing=[]였지만 실제 Cloud 실습 완료를 대신하지 않는다.
- 새 plan의 source/inputs/action/bundle/Terraform hash와 정확한 13개 구성을 재검사했다. source를 수정하면 새 계획이 다시 필요하다.
- e6a1의 HTTP 2xx는 생성 완료가 아니었다. `failed-create-operations.json`과 `failed-create-instances.json`을 보존했고 최종 비동기 오류 판정으로 고쳤다. `memory/knowledge/gcp-compute-operation-iam.md` 참고. 단순 대기 늘리기나 권한 확대는 이 오류의 해결책이 아니다.
