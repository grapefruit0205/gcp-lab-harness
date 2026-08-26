# Checkpoint — 이전 실습 백업 없이 정리 — 2026-08-26 14:38

## The story so far

사용자가 Minecraft VM·월드 디스크·기존 백업 버킷·IP 삭제 설명 뒤 “백업 하지말고 전부 destroy 해줘.”라고 명시했다(D-028). Phase 07 새 apply 대기 대신 이전 실습 정리를 진행한다. 새 백업/스냅샷은 만들지 않는다.

실제 Cloud inventory에서 하네스 소유 Minecraft 리소스 10개가 남았다. Phase 5 `runphase005`의 state에는 5개가 남았지만 실제 리소스는 이미 없어 destroy plan은 0개다. Phase 4·과거 5/6/7과 foundation state는 비어 있고 최신 Phase 7은 미적용이다.

저장 삭제 계획은 ignored `artifacts/cleanup-before-phase08.PSOwfC/`에 있다. Phase 6 destroy 10, SHA `b057bcce8c73cd95a4099d2dec0937d976b9663a5c6fb2af1add255f15033329`; Phase 5 0-change/state refresh SHA `6f2778a762a1f127f1308bb12a34571ac39385243f9b091a6f954dea74243da3`. 모든 Phase 6 대상이 해당 run/project와 일치하고 delete-only임을 검사했다. 아직 이 계획은 적용 전이다.

## Decided

- D-028은 이전 Minecraft 보존과 Phase 07 새 apply 대기를 대체한다. 실습 소유 리소스만 삭제하고 project/billing/사용자 인증/공통 API는 유지한다.
- 기존 backup bucket에는 7일 soft-delete 정책이 있다. 새 백업은 만들지 않으며 Cloud의 기존 보존 정책을 임의로 바꾸지 않는다.
- 관리 밖 기존 bucket/snapshot/SA/firewall은 소유 확인 없이 삭제하지 않는다.
- Git commit/push와 Phase 8 apply는 이번 삭제 요청에 포함되지 않는다.

## Waiting on the user

관리 밖 `junseok-lab` bucket, `mynet-us-vm-…` snapshot, `lampstack`·`read-bucket-objects` SA, `privatenet-allow-ssh` firewall도 이전 실습 삭제 대상인지 비차단 질문을 보냈다. 확인된 하네스 삭제는 계속한다.

## Next first action

`artifacts/cleanup-before-phase08.PSOwfC/cleanup-authorization.json`의 hash를 저장 binary와 재대조하고 해당 Phase 06·05 work에서 저장된 destroy plan만 apply한다. 이후 실제 inventory와 빈 state를 확인해 manifest를 정리한다.

## Tried

- 과거 Phase 5 verified manifest는 실제 리소스 존재 증거가 아니었다. API refresh에서 이미 삭제됐음을 확인했다.
- Terraform destroy의 소유 대상과 프로젝트의 모든 리소스를 혼동하지 않는다. default network/공통 SA/실습 밖 리소스는 보존한다.
- Phase 07 최신 plan은 never-applied이며 실습 완료가 아니다. 정리 요청을 새 리소스 생성 승인으로 해석하지 않는다.
