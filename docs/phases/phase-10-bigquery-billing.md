# Phase 10 — BigQuery로 Billing 데이터 분석

- 원본: `references/google-cloud-labs-ko/labs/10.Examining Billing data with BigQuery_KR.md`
- 비용 위험: 중간
- 주요 서비스: BigQuery, Cloud Billing export 또는 고정 billing fixture

## 목적

청구 데이터 sample을 BigQuery에 적재하고 schema·행 수를 확인한 뒤 단순 쿼리와 대규모 분석 SQL을 결정적으로 검증한다.

## 범위와 원본 매핑

| 원본 Task | 분류 | 자동화·증거 |
|---|---|---|
| Task 1. BigQuery로 데이터 가져오기 | automated | dataset/table 생성, fixture load job 상태·행 수 |
| Task 2. 테이블 검토하기 | automated | schema·partition·sample 통계의 구조화 조회 |
| Task 3. 간단한 쿼리 작성하기 | automated | versioned SQL과 golden result 비교 |
| Task 4. SQL로 대규모 청구 데이터세트 분석하기 | automated/conditional | fixture 기본 경로; 실제 Billing export는 opt-in과 readiness 대기 |
| Task 5. Review | cli-equivalent | load·schema·query 비용·결과 검토 |

## Task별 콘솔 확인

[공통 확인법](../console-checks.md)을 먼저 읽고 자신의 프로젝트·해당 run만 선택한다. 아래는 **확인 기준**이지 이번 실행의 성공 기록이 아니다. 원본 Task 이름은 위 매핑과 대응한다.

| Task | 콘솔 경로·대상 | 통과 기준 | 한계·보조 확인 |
|---|---|---|---|
| 1 | BigQuery → 탐색기 → billing_<RUN_ID의 하이픈을 밑줄로 변경> → sampleinfotable | load job 성공, 승인 fixture의415602행 | 실제 Billing export 연결과 sample fixture 실습을 구분 |
| 2 | 테이블 → 스키마(Schema)·세부정보(Details)·미리보기 | 필드 타입·행 수·sample 데이터가 계약과 일치 | 미리보기만 보고 전체 데이터 일치를 단정하지 않음 |
| 3 | BigQuery → 탐색기 → 작업 기록 → 프로젝트 기록 → 단순 query | Cost>0 쿼리 작업 성공과 저장 결과 hash/처리 bytes가 있음 | 기록에 없으면 프로젝트/실행 계정/리전을 확인. 쿼리를 임의 재실행해 비용을 만들지 않음 |
| 4 | 작업 기록 → 해당 실행 시간대의 분석 query7개 | 각 query가 오류 없이 종료했고 byte 상한·정제 결과가 기록됨 | 청구 원본/민감 결과를 Git·채팅에 복사하지 않음 |
| 5 | 테이블 상세 + load/전체8개 query 기록 | Task1–4 행 수·schema·비용 상한·결과를 대조 | 작업 성공만으로 기대 결과의 의미적 정확성이 입증되지는 않음 |

메뉴 확인 근거(2026-08-26): [테이블 정보 확인](https://docs.cloud.google.com/bigquery/docs/tables), [작업 기록 확인](https://docs.cloud.google.com/bigquery/docs/managing-jobs). 화면 언어/버전에 따라 상단 검색으로 같은 서비스에 접근한다. 실제 UI 클릭 전 과정 검증은 별도다.

## 구현 작업

1. dataset location, BigQuery 권한, query byte limit와 fixture checksum을 preflight한다.
2. dataset/table/load/query 변경과 최대 처리 bytes를 plan에 기록한다.
3. 기본 경로는 versioned fixture를 사용해 즉시 재현 가능하게 한다.
4. 실제 Billing export 경로는 별도 opt-in, billing 권한, 비동기 데이터 도착을 확인한다.
5. 쿼리 결과는 안정 정렬·타입 정규화 후 golden JSON과 비교한다.

## 실행 계약

Command Code `cmd`는 모델 선택 없이 `bq` 또는 BigQuery API를 호출한다. query dry-run으로 bytes와 비용 경계를 먼저 확인하고 한도를 넘으면 실행하지 않는다. Billing export 미도착은 성공이 아니라 `blocked` 또는 `skipped`로 구분한다.

## 검증 게이트

- load job이 성공하고 행 수·schema가 fixture manifest와 일치한다.
- 단순·분석 SQL의 정규화 결과가 golden result와 일치한다.
- 각 query의 처리 bytes가 plan의 상한 이하다.
- Extension은 BigQuery read-only metadata·job 결과와 diff를 검토한다.
- 사용자 승인을 받은 뒤 dataset/table cleanup으로 전이한다.

## 안전·비용 가드레일

- 실제 billing account ID, project ID, invoice 정보는 evidence에서 제거한다.
- `maximum_bytes_billed`, query timeout, dataset location allowlist를 강제한다.
- Billing export 활성화는 지속적 외부 설정이므로 기본 자동화에서 만들지 않는다.
- run dataset/table만 삭제하고 공유 billing export dataset은 절대 삭제하지 않는다.

## 완료 조건

- Task 1–5 coverage와 load·schema·두 종류 query evidence가 있다.
- Extension이 데이터 노출·query 비용을 검토하고 사용자가 승인했다.
- fixture 경로 cleanup 뒤 run dataset/table이 0이며 공유 export는 변경되지 않았다.

## Command Code·Extension handoff 지시

Command Code는 fixture와 실제 export 결과를 혼합하지 않고 데이터 출처를 명시한다. Extension은 query를 다시 실행할 때 dry-run과 byte limit를 적용하고 사용자 대신 결과를 승인하지 않는다.

## 현재 adapter

`phases/10/terraform`은 run 전용 US dataset을 소유한다. action plan은 원본 AVRO의 generation과 CRC32C를 고정하고, verifier는 415,602행을 요구한 뒤 `phases/10/sql/`의 원본 SQL 8개를 dry-run·1 GiB 상한으로 실행해 결과 hash와 처리 bytes만 남긴다.

## Git 종료 조건

`Phase 10: BigQuery 청구 데이터 분석 자동화 및 검증 완료` 커밋·push가 확인된 뒤 Phase 11로 이동한다.
