# Checkpoint — Phase 07 수정 plan 승인·재apply 시작 — 2026-08-26 13:02

## The story so far

observed: D-021의 run `p07-260826-72bd` apply는 12 added·0 changed·0 destroyed로 성공했다. read-only topology/no-drift도 통과했으나 실제 IAM 실습의 첫 SA project 조회가 HTTP403 `SERVICE_DISABLED`로 실패했다. 대상은 `kdt5-05`의 Cloud Resource Manager API다. 임시 Viewer를 회수하고 실패 cleanup으로 12개 리소스를 삭제했다. 잘못된 subnet inventory CLI를 수정한 read-only 재검사·빈 Terraform state·bucket 직접 HTTP404·project IAM baseline hash 일치로 잔여 0과 복구를 확인했고 old manifest는 destroyed/completed다. Phase 06 VM의 ID/IP/lastStartTimestamp와 RUNNING도 그대로였다.

Resource Manager API를 Terraform에 추가하고 SA consumer 준비 대기·subnet inventory를 보완했다. 회귀 26개·Terraform mock 6개·validate/fmt·Phase gate·07–15 offline suite를 통과했다. 새 run `p07-260826-e6a1`의 API 포함 13 create plan을 사용자가 승인했다. runner·source·inputs·action·bundle·Terraform hash와 planned 상태를 재확인했으며 새 apply를 시작한다.

## Decided

- D-021 승인은 old bundle `cbadfcca92660a44a40653665e8ad1bc35cb61895b5699eb1467b0908ddd095e`에만 적용됐고 이미 apply/실패 cleanup을 수행했다. 새 scope/코드의 실행으로 확대하지 않는다.
- D-022: bundle SHA `78871cff6b5edfe12fb965d5f8c032595a52d4bc1c933318adc32fe366c70837`의 apply·IAM 검증·임시 권한 회수·실패 cleanup을 사용자 “ㄱㄱ” 응답으로 승인했다.
- 새 plan은 `cloudresourcemanager.googleapis.com`만 활성화한다. destroy 때 다른 workload에 영향을 주지 않도록 공용 API는 활성 상태로 유지한다. IAM 임시 grant는 검증 종료 시 회수하고 최종 destroy·commit·push는 별도 승인이다.

## Waiting on the user

현재 없음. 승인된 재apply와 검증을 진행한다.

## Next first action

`/home/grapefruit/gcp-lab-harness/phases/07/execute.sh apply --run p07-260826-e6a1 --confirm-plan-sha 78871cff6b5edfe12fb965d5f8c032595a52d4bc1c933318adc32fe366c70837`를 승인 plan backup 후 실행하고 같은 run의 read-only applied 검사와 IAM verify를 진행한다.

## Tried

- 사용자 OAuth의 Resource Manager HTTP200을 새 SA의 API consumer 활성화 증거로 쓰면 안 된다. 같은 endpoint에 SA는 SERVICE_DISABLED를 반환했다. 오류는 old run `baseline-project-error.json`에 보존했다.
- cleanup inventory의 `gcloud compute subnetworks list`는 잘못된 CLI다. `gcloud compute networks subnets list`로 수정해 실 API 재검사와 회귀 테스트를 통과했다. 첫 자동 cleanup의 실패는 실제 Terraform 삭제 실패가 아니라 이 후속 검사의 실패였다.
- old run은 source hash도 stale이고 리소스가 이미 삭제됐다. 재apply하지 않는다. c4b7/f8e2 중간 후보도 사용하지 않는다.
- 새 runner의 serviceusage enable·IAP tunnel·OS Login·actAs project testIamPermissions는 HTTP200, missing=[]였지만 실제 Cloud 실습 완료를 대신하지 않는다.
- 새 plan의 source/inputs/action/bundle/Terraform hash와 정확한 13개 구성을 재검사했다. source를 수정하면 새 계획이 다시 필요하다.
