# BigQuery Avro 시간 타입 — 2026-08-26

## 기본 적재의 INTEGER와 명시적 논리 타입 변환 — observed

- 관측: Phase10 run `p10-260826-2106`에서415602행 load가DONE/오류0으로끝났지만usage_start_time/usage_end_time/export_time은INTEGER였다. load job의useAvroLogicalTypes는생략됐다. 같은 승인 generation의Avro header에서세필드의long/logicalType=timestamp-micros를확인했다.
- 반증 점검: 행 수 부족·load실패가 아닌지 실제table numRows와job badRecords/error를읽었다. 원본이논리타입없는단순long인지도header를직접읽어제외했다. 실제시간필드가INTEGER라는관측을TIMESTAMP라고덮어쓰지않았다.
- 근거: [공식 Avro 변환](https://docs.cloud.google.com/bigquery/docs/loading-data-cloud-storage-avro#logical_types), [JobConfigurationLoad](https://docs.cloud.google.com/bigquery/docs/reference/rest/v2/Job#JobConfigurationLoad); ignored run의`evidence/table-readback.json`, `load-readback.json`, `fixture-header-readback.json`와당시load설정코드.
- 보완: useAvroLogicalTypes=true를명시한다. WRITE_TRUNCATE 재적재는같은run의sampleinfotable 데이터·스키마를덮어쓰므로새action/bundle승인을받고시행한다. 기존dataset·state는삭제하지않으며공유청구테이블에는사용하지않는다.
- 표본/한계/날짜: 2026-08-26, 현재fixture1개·실제load1건.42개회귀중신규2개에서옵션누락/오류필드/실패후query0을검사했다. 수정후Cloud재적재·8쿼리성공은아직미검증이며다른Avro타입전체에일반화하지않는다. 연구초안은PRODUCT-TRUTH의실기진단항목에서이항목으로연결했다.
