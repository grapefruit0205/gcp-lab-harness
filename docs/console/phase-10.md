# Phase 10 — Task 하위 항목별 콘솔 확인

[공통 준비](../console-checks.md) · [Phase 요약](../phases/phase-10-bigquery-billing.md)

본인 프로젝트·run 을 선택합니다. 아래는 확인 방법이며 실제 성공 기록이 아닙니다. 확인 목적으로 **Run/테이블 만들기/삭제**를 누르지 않습니다. 증거는 `artifacts/runs/<RUN_ID>/phase-10/evidence/`의 `billing-jobs-*.json`, `phase-10-machine.json`입니다. dataset 이름은 `billing_<RUN_ID의 하이픈을 밑줄로 변경>`입니다.

## Task 1. BigQuery로 데이터 가져오기

### BigQuery에 로그인하여 데이터세트 생성하기

1. 상단 검색 **BigQuery → Studio → Explorer → 본인 프로젝트 → Datasets**를 펼쳐 run dataset 을 클릭합니다.
2. **Details**에서 dataset ID·Location=US·기본 테이블 만료=1 일을 확인합니다. 원문의 `billing_dataset` 대신 run 이름을 사용합니다.
3. 목록에 없다면 프로젝트·run·manifest 상태부터 확인합니다. 새 dataset 을 만들지 않습니다. 실제 Billing export 연결은 이 실습 범위가 아닙니다.

### 테이블 생성 및 가져오기

1. dataset 아래 **sampleinfotable → Details**를 엽니다.
2. **Job history → Project history**에서 `billing-jobs-*.json`의 load job ID 를 검색합니다. source=승인 AVRO, destination=본인 table, DONE/오류 없음, 행 수 415602 를 확인합니다.
3. generation/CRC32C 는 `action-plan.json`과 정제 증거에서 적재 전후 일치를 확인합니다. 테이블 이름만 존재한다고 적재 성공은 아닙니다.

## Task 2. 테이블 검토하기

### 1. Schema의 이름과 타입

1. **sampleinfotable → Schema**에서 project/service/sku/location/usage 를 펼칩니다.
2. billing_account_id·currency 는 STRING, cost 는 FLOAT, usage_end_time 은 TIMESTAMP, 중첩 필드는 RECORD 인지 확인합니다.
3. 필드 이름만 보고 타입·중첩 구조까지 확인했다고 쓰지 않습니다. 자동 검증의 필수 schema 검사와 대조합니다.

시간 필드가 `INTEGER`라면 통과가 아닙니다. 이 원본의 Avro 시간 타입은 `timestamp-micros`이며 자동화는 `useAvroLogicalTypes=true`로 적재합니다. 이전 실행에서 옵션이 빠졌다면 리소스를 삭제하지 말고 같은 run의 `diagnose → 수정 → replan → 새 SHA 승인 → apply → verify` 절차를 따릅니다. 재검증의 `WRITE_TRUNCATE`는 해당 run의 `sampleinfotable` 데이터·스키마를 원본 fixture로 다시 적재하므로, 이 테이블에 별도 작업 데이터를 추가하지 않습니다. [Avro 타입 변환](https://docs.cloud.google.com/bigquery/docs/loading-data-cloud-storage-avro#logical_types)

### 2. Details의 전체 행 수

1. **Details → Number of rows**를 읽습니다.
2. 전체 415602 행과 생성 시각·위치를 확인합니다. Preview100 행과 전체 행 수를 혼동하지 않습니다.
3. dataset 의 1 일 만료로 테이블이 사라졌다면 과거 job/evidence 와 현재 부재를 구분합니다.

### 3. Preview의 데이터

1. **Preview**에서 cost 와 중첩 project/service/usage 값을 읽습니다.
2. 숫자·문자·NULL 값이 스키마와 맞는지 관찰합니다.
3. Preview 는 전체 데이터 정확성 검증이 아닙니다. 청구 원본을 채팅·Git 에 복사하지 않습니다.

## Task 3. 간단한 쿼리 작성하기

### 1–3. Cost가 양수인 레코드

1. **Job history → Project history → query1 job ID → Query/Results/Execution details**를 엽니다.
2. SQL 의 `WHERE Cost > 0`, 작업 성공, `total_rows > 0`, sample cost 모두양수, billed bytes≤1GiB 를 확인합니다.
3. 결과 페이지 크기와 전체 결과 행 수는 다릅니다. 확인용 재실행은 하지 않습니다.

## Task 4. SQL로 대규모 청구 데이터세트 분석하기

### 1–2. 전체 청구 필드 query2

1. **BigQuery → Job history → Project history**에서 `billing-jobs-*.json`의 query2 job ID 를 찾아 **Query·Results**를 엽니다. billing_account_id/project.id/project.name/service.description/currency/currency_conversion_rate/cost/usage 필드를 확인합니다.
2. 전체 결과 415602 행을 확인합니다. 저장 sample100 행은 전체 행 수가 아닙니다.
3. 모든 분석 job 의 번호는 `billing-jobs-*.json`의 stage 로 찾습니다.

### 3–4. 최신 양수 비용100개 query3

1. query3 의 **Query**에서 `Cost>0`, `ORDER BY usage_end_time DESC`, `LIMIT 100`을 확인합니다.
2. **Results**의 전체 100 행과 cost 양수 여부를 대조합니다.
3. 결과 열에는 usage_end_time 자체가 없으므로 결과 표만으로 시간 정렬을 입증하지 않습니다.

### 5–6. 10달러 초과 query4

1. query4 의 **Query → WHERE cost > 10**, **Results → cost/currency**를 봅니다.
2. sample cost 가 모두 10 보다 큰지, 작업 오류가 없는지 확인합니다.
3. 통화는 데이터의 currency 를 기준으로 읽으며 개인 청구서 금액과 혼동하지 않습니다.

### 7–8. 레코드가 가장 많은 제품 query5

1. query5 **Results**의 description·billing_records 를 봅니다.
2. GROUP BY service.description 및 billing_records 내림차순을 확인하고 첫 행 제품명·수를 기록합니다.
3. 첫 행 정답을 미리 가정하지 않습니다. 현재 구현은 고정 golden 전체 정답과 비교하지 않습니다.

### 9–10. 1달러 초과 최다 제품 query6

1. query6 **Query**의 `WHERE cost>1`, **Results**의 description·billing_records 를 봅니다.
2. 첫 행의 제품과 레코드 수를 query5 와 비교합니다.
3. 전체 최다 제품과 1 달러 초과 최다 제품이 같다고 가정하지 않습니다.

### 11–12. 가장 일반적인 사용량 단위 query7

1. query7 **Query**의 `cost>0`, `GROUP BY usage.unit`, 내림차순을 확인합니다.
2. **Results** 첫 행의 unit 과 billing_records 를 기록합니다.
3. unit 과 pricing_unit 은 다른 필드입니다.

### 13–14. 합산 비용 최다 제품 query8

1. query8 **Query**의 `ROUND(SUM(cost),2)`와 내림차순을 확인합니다.
2. **Results** 첫 행의 description·total_cost 와 작업 billed bytes≤1GiB 를 기록합니다.
3. 쿼리 8 개 모두 작업 성공·전체 행 수·처리 상한을 개별 확인해야 합니다.

## Task 5. Review

### 적재·스키마·8개 질문의 답

1. 테이블 Details, load job, query1–8 을 Task1–4 와 대조합니다.
2. 각 job ID/행수/bytes/hash 가 `phase-10-machine.json`과 연결되는지 확인합니다.
3. 이미 만료/destroy 했다면 과거 job 기록과 현재 테이블 부재를 구분하고 재적재하지 않습니다.

## 출처·검증 범위

2026-08-26 원문 10 및 현재 SQL/검증 코드 대조(observed). 실제 UI 클릭·Cloud 실행은 별도입니다. [공식 테이블 정보](https://docs.cloud.google.com/bigquery/docs/tables), [작업 결과의 totalRows 와 페이지 구분](https://docs.cloud.google.com/bigquery/docs/reference/rest/v2/jobs/getQueryResults).
