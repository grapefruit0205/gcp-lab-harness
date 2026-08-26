# Cloud Storage 삭제 완료와 복구 보존 구분

## 활성 리소스 삭제와 soft-delete 보존은 별개 — observed 2026-08-26

- 관측: Phase 06 저장 destroy plan이 10 destroyed로 끝나고 Terraform state 및 live bucket 목록에서 대상이 사라졌다. 같은 사용자로 Storage JSON API `buckets.list?project=...&softDeleted=true&prefix=...`를 페이지 끝까지 조회하니 해당 bucket의 `softDeleteTime=2026-08-26T05:40:00.292Z`, `hardDeleteTime=2026-09-02T05:40:59.905Z`가 반환됐다.
- 반증 확인: live 목록/빈 state만으로 복구 불가능 또는 보존 데이터 0이라고 주장하지 않았다. 기존 bucket 정책의 retentionDurationSeconds=604800과 실제 삭제 후 API 결과를 대조했다. `gcloud storage ls --buckets --soft-deleted --json`의 HTTP404를 빈 목록으로 처리하지 않았다.
- 근거: [공식 soft delete 동작](https://docs.cloud.google.com/storage/docs/soft-delete), [공식 buckets.list의 softDeleted·pagination](https://docs.cloud.google.com/storage/docs/json_api/v1/buckets/list), ignored `artifacts/cleanup-before-phase08.PSOwfC/{minecraft-bucket-before.json,soft-delete-rest.json,phase06-apply.log,result.json}`.
- 표본/한계: 한 프로젝트의 한 bucket, n=1. 다른 bucket의 보존 기간이나 모든 CLI 버전의 동작으로 일반화하지 않는다. 에이전트가 새 백업·복구·snapshot을 생성하지 않았으며 기존 정책도 변경하지 않았다. 공식 문서는 soft-deleted 상태가 보존 기간 동안 복구 가능하고 조기 영구 삭제할 수 없음을 설명한다. 비용 0이라고 주장하지 않는다.
- Checked: 2026-08-26. 실제 정리 완료 보고는 활성 잔여 수와 자동 복구 보존 상태를 분리한다.
