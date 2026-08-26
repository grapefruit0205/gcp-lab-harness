# Cloud Storage CSEK와 오류 판정 — 2026-08-26

## CSEK 변경은 rewrite이며 구키·신키 header가 별개 — confirmed (self-gated)

- Claim: JSON API objects.rewrite는 source decrypt header와 destination encrypt header를 따로 받고, `done=false`이면 rewriteToken으로 계속 요청해야 한다. source/destination generation precondition으로 대상을 고정할 수 있다. gcloud objects update의 encryption-key 또는 clear-encryption-key가 rewrite를 요청한다.
- Refutation: 기존 Phase 08의 옵션 없는 objects update를 키 교체로 인정하지 않았다. 두 API header 집합, 최종 metadata keySha256, 새 키 복호화 hash를 각각 검사하도록 보완했다.
- Evidence: [공식 rewrite API](https://docs.cloud.google.com/storage/docs/json_api/v1/objects/rewrite), [공식 gcloud objects update](https://docs.cloud.google.com/sdk/gcloud/reference/storage/objects/update), [공식 CSEK 동작](https://docs.cloud.google.com/storage/docs/encryption/customer-supplied-keys).
- Sample/limits: 공식 문서 3개와 `tests/test-phase-08.py`의 mock 검증. 실제 Cloud CSEK 실행은 아직 없음. 기존 키가 필요한 이전 세대는 키 폐기 전에 삭제/재암호화/보존 정책을 별도로 고려한다.

## 예상 거부와 장애는 HTTP code·reason을 함께 검사 — confirmed (self-gated)

- Claim: 잘못된 CSEK는 HTTP400 `customerEncryptionKeyIsIncorrect`, 키 미제공은 `resourceIsEncryptedWithCustomerEncryptionKey`다. 인증401·권한403·404·네트워크 오류는 CSEK 거부의 증거가 아니다. PAP 공개 ACL 생성 거부는412이며 무관한 generation precondition412와 구별해야 한다.
- Evidence: [공식 JSON API error codes](https://docs.cloud.google.com/storage/docs/json_api/v1/status-codes), [공식 Public Access Prevention](https://docs.cloud.google.com/storage/docs/public-access-prevention).
- Refutation: 모든 nonzero 반환을 통과시키지 않고 code/reason/PAP 메시지를 검사한다. HTTP 원문에는 비밀이 반사될 수 있어 로그에 출력하지 않는다.
- Limits: API error 형식 변화·실제 조직 정책은 live 실행 시 재확인. 정책을 자동 해제하지 않는다.

## 실습 임시 bucket의 soft-delete 해제 — confirmed (self-gated)

- Claim: bucket softDeletePolicy.retentionDurationSeconds=0은 soft-delete를 비활성화한다. 실습에서는 Terraform 새 bucket에 명시하고 metadata readback 및 최종 live/soft-deleted paginated inventory를 별도로 확인한다.
- Evidence: [공식 bucket resource](https://docs.cloud.google.com/storage/docs/json_api/v1/buckets), 기존 `gcp-storage-soft-delete.md`의 이전 실습 실제 관측.
- Limits: 기존 soft-deleted 데이터 보존 기간을 소급 삭제하는 기능이 아니며, Phase 08 새 bucket의 실제 API 실행은 미검증이다.

## alt=media 오류는 항상 JSON이 아니다 — observed 2026-08-26

- 관측: 첫 Cloud verify는 HTTP401에서 중단됐고 run bucket은 자동 정리됐다. 삭제된 그 bucket의 동일 alt=media 경로를 읽기 전용으로 조회하면 HTTP404와 일반 텍스트 `The specified bucket does not exist.`가 반환됐다(n=1). 기존 ApiError는 non-JSON body의 reason을 빈 집합으로 만들었으므로 HTTP401/403도 익명 접근 거부로 분류하지 못할 수 있었다.
- 반증/한계: 기존 실패 로그는 body 형식과 Task를 기록하지 않아 첫401의 요청 위치나 원인을 단정할 수 없다. 객체 부재404를 ACL 거부로 인정하는 변경은 하지 않았다. 새 판정은 같은 generation의 인증 GET이 전후 성공할 때 익명401/403만 허용한다. CSEK400의 non-JSON body는 그 자체로 키 거부 증거가 아니며 JSON checksum metadata의 정확한 CSEK reason을 추가로 요구한다.
- 근거: [공식 JSON 오류표](https://docs.cloud.google.com/storage/docs/json_api/v1/status-codes)는 오류 body가 보통 JSON임을 설명하지만 항상이라고 보장하지 않는다. [공식 objects.get](https://docs.cloud.google.com/storage/docs/json_api/v1/objects/get)은 alt=media와 metadata 반환을 구분한다. ignored `artifacts/phase-08-anonymous-diagnostic.{headers,body}`, `tests/test-phase-08.py`의 plaintext 오류/positive-control 검사.
- 상태: 수정 후 44개 오프라인 테스트 통과. 수정 코드의 실제 Cloud 재검증은 아직 없다. → 첫 실행에서 bucket soft-delete=0 readback과 cleanup 잔여0은 별도로 관측됨.
