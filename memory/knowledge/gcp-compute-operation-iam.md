# Compute Engine 비동기 작업과 IAM 판정

## VM 생성 HTTP 접수는 최종 성공이 아니다 — confirmed (self-gated) 2026-08-26

- Claim: Compute Engine VM 생성 요청의 HTTP 2xx와 `Operation` 응답은 요청 접수만 뜻한다. 권한 경계 검증은 해당 zonal operation이 `DONE`이 될 때까지 기다린 뒤 `error.errors`, `httpErrorStatusCode`, 정확한 operation/actor/target identity를 판정해야 한다.
- Refutation: 최초 `p07-260826-e6a1` verifier는 HTTP 2xx를 생성 성공으로 보았지만, 동일 operation의 최종 상태는 HTTP error 400과 `SERVICE_ACCOUNT_ACCESS_DENIED`였고 대상 VM inventory는 비어 있었다. 실제로 VM이 생성됐다는 반대 가설은 API operation·instance inventory에서 반박됐다.
- Primary sources: ignored run evidence `artifacts/runs/p07-260826-e6a1/phase-07/failed-create-operations.json`와 `failed-create-instances.json`; Google Cloud 공식 [Compute API operation 완료 확인](https://docs.cloud.google.com/compute/docs/api/best-practices#wait_for_operations_to_be_done); 공식 [zoneOperations 오류 필드](https://docs.cloud.google.com/compute/docs/reference/rest/v1/zoneOperations).
- Sample: 실제 project `kdt5-05`의 Compute-only/actAs-absent VM insert n=1, 공식 문서 2개. 회귀는 캡처된 operation replay와 36개 단위 테스트로 분리했다.
- Limits: 이 관찰은 해당 권한 거부 흐름만 입증한다. quota·조직 정책·다른 long-running API의 오류를 같은 IAM 거부로 해석하지 않는다. 수정 후 전체 Cloud IAM/guest 실습 성공은 새 run에서 별도 확인해야 한다.

## VM에 서비스 계정을 연결하려면 actAs가 필요하다 — confirmed (self-gated) 2026-08-26

- Claim: VM 같은 리소스에 서비스 계정을 연결할 때 대상 서비스 계정에 대한 `iam.serviceAccounts.actAs`가 필요하며 `roles/iam.serviceAccountUser`가 이를 포함한다.
- Refutation: Compute Instance Admin만 가진 actor가 VM insert를 접수할 수 있다는 사실만으로 actAs가 불필요하다고 볼 수 있는지 검사했다. 최종 operation은 `SERVICE_ACCOUNT_ACCESS_DENIED`였고 Service Account User 부여를 요구했으며 VM은 남지 않았다.
- Primary sources: 위 actual operation n=1; Google Cloud 공식 [Attach service accounts to resources](https://docs.cloud.google.com/iam/docs/attach-service-accounts), 특히 `roles/iam.serviceAccountUser`와 `iam.serviceAccounts.actAs` 요구사항.
- Sample: actual operation n=1과 공식 IAM 문서 1개. product 전체 동작이 아니라 해당 atomic permission 요구사항이다.
- Limits: 조직 정책·cross-project SA·다른 리소스 유형에서는 추가 권한과 정책이 필요할 수 있다. HTTP 요청 접수 여부가 아닌 최종 operation 기준이다.
