# Phase 10–15 오류 보완·상세 콘솔 안내 감사

판정일: 2026-08-26. 최초 범위는 로컬 코드·회귀·Terraform mock/정적 검사이며 이후 Phase10 실제 실행에서 발견한 오류를 아래 별도 항목에 추가했다. **전체 Phase10–15 Cloud 실습·실제 콘솔 UI·통신 성공 기록은 아니다.** 과거 [07–15 감사](phase-07-15-coverage.md)는 당시 기록이며 현재 변경은 아래를 따른다.

## 발견한 오류와 수정

| 대상 | 수정·검증 방법 |
|---|---|
| 공통10–15 | 별도 safe adapter. 실패 시 state/리소스/계획/시도 로그 보존. 같은 run replan, 소스·work·입력·현재 계정·프로젝트·state와 정확한 SHA 결합. 일반 복구 delete/replace 차단. 컨트롤러는 원문 계약에 선언된 manual-boundary만 수동 경계로 허용하며 누락/실패를 통과시키지 않음 |
| 10 BigQuery | 비구조화 bq dry-run 파싱 제거. jobs API의 dryRun·maximumBytesBilled·DONE/error·totalRows 검사. job ID로 콘솔 작업 기록 연결 |
| 11 Monitoring | uptime group enum INSTANCE 수정. 실제 checker IP /32 방화벽. 시계열 존재가 아닌 각 VM의 최신 true 검사. VM1/2 각각20%·60초 조건, 정확한 group ID집합, alert 활성→비활성 증거. MCP 필수 preflight 제거 |
| 12 HA VPN | 실패 자동 destroy 제거. baseline/라우팅 전이/장애/완료 단계 저장. 이미 tunnel0이 삭제된 재시도에서4터널 대기하지 않음. 삭제 직전 baseline Cloud ID 대조. Task8 정리 완료 오판 제거 |
| 13 ALB | builder 외부 삭제 대신 stopped 상태 보존, image 준비 종속성의 실제 instance ID. autoscaler target_size 충돌 방지. 각 리전별 health 확인, frontend readback, 정확한 systemd load unit360초 제한 |
| 14 ILB | NAT 준비 전 MIG startup 경쟁 방지, apt 유한 재시도, PHP의 실제 REMOTE_ADDR. 중간 curl 실패 전파·VIP60회 성공·정확한 두 backend. 삭제 inventory 전체 zone 조회·조회 오류 fail-closed |
| 15 Terraform | data source를 managed4개에 잘못 포함하던 검사 수정. 서로 다른 region의 zone 강제, ping readiness, 멱등성 plan의 lock timeout·로그 |
| 콘솔 문서 | Phase01–15의90개 Task·Task 안의 원문 하위 제목167개. P09 번호 절차와 P10 분석7개 질문도 상세 분할해 안내 하위 항목은221개다. 단일 Task 출력에 준비·증거 경로 포함. 중복/누락 하위 제목 회귀 검사 |

## Phase10 최초 실기에서 발견한 Avro 시간 타입 오류

2026-08-26 observed, n=1: dataset apply와415602행 load는 성공했지만 실제usage_end_time이INTEGER라 schema 검증에서 중단됐다. load job에는useAvroLogicalTypes가 없었고 승인된 원본 header의시간3개필드는timestamp-micros였다. [공식 변환 규칙](https://docs.cloud.google.com/bigquery/docs/loading-data-cloud-storage-avro#logical_types)에 맞춰true를 명시했다. 기대타입을INTEGER로낮추지않고 오류에필드/기대/실제값을 추가했다.

회귀42개·Phase10 TF mock1개/fmt/validate·Bash/gate를 통과했다. 실패뒤dataset/table/state/job receipt를 보존했고 query는아직0개다. 같은run의WRITE_TRUNCATE 재적재(data/schema)를action plan에 명시했으며, 새 SHA 승인 전 보완재적용/8쿼리성공을주장하지않는다. 실제 증거는 `memory/PRODUCT-TRUTH.md`의동일제목항목과ignored run진단파일에 있다.

새 독자 리허설(observed, 2026-08-26, 1회): 한국어 clone 사용자의 로컬 범위에서 Task2 출력·전체coverage·안내13개검사를실행해모두exit0·차단/추측0이었다. INTEGER를실패로판정하고dataset/state보존과sampleinfotable데이터·스키마덮어쓰기를구분했으며새SHA승인조건을문서에서찾았다. 실제Cloud/API/auth/Git변경·콘솔클릭은수행하지않았다.

## 재현 명령

후속관측(2026-08-26): D-047의Phase15까지명시위임후Phase10 수정bundle을재apply/verify해415602행·시간3개TIMESTAMP·8query·Task1–5가통과했다. 총billed bytes는333MiB이며전체golden/UI/Billing export/종료destroy는별도다. 최초오류기록은위에보존한다. Phase11 사전대조에서dashboard GET의v1/v3경로오류도수정했고43개회귀·Phase11 gate/mock을통과했다.

```bash
make test-offline
./tests/test-phases-10-15.sh
python3 tests/test-phase-09.py
./scripts/phase-gate.sh docs/phases/phase-10-bigquery-billing.md
```

Phase gate는11–15에도 각각 수행한다. 검사는 Cloud apply를 포함하지 않는다. 오프라인 시험으로 API 권한·quota·실제 metric 도착·VPN 수렴·autoscaling을 보장할 수 없다. 최종 실행 결과는 `memory/SESSION-LOG.md`와 `memory/PRODUCT-TRUTH.md`에 기록한다.

## 원문과의 차이·미검증 범위

- Phase10: 실제 Billing export 연결은 없다. 고정 AVRO의 적재 전후 generation/CRC32C를 비교하지만 동시 객체 변경을 원자적으로 막지는 않는다. 결과 총행수·표본 조건·정렬 검사는 전체 golden 정답 비교와 다르다.
- Phase11: 이메일 채널 생성·실제 메일 수신·사용자의 Metrics Explorer 조작은 자동 검증하지 않는다. MCP는 선택 검증이다.
- Phase12: 온프레미스 VM은 원문의 다른 zone 대신 primary zone에 있다. 최종 topology는 터널 하나가 삭제된 장애 실험 상태다. Task8 cleanup은 별도 승인 전 미완료다.
- Phase13: 원문의 builder reset/삭제 실험은 미구현이다. stopped builder와 disk를 보존한다. 양쪽 backend RATE50·축소 autoscaler1–2·primary-region loadgen을 사용한다. marker2개가 양쪽 리전 트래픽 분산을 증명하지는 않는다. IPv6 route가 없는 실행 환경은 HTTP 검사를 unavailable로 남긴다.
- 공통: 자동 만료·비용 종료 스케줄러는 없다. `diagnose`는 최소 state/log 안내이며 서비스 원인 자동 분석기는 아니다. 구형 run 자동 이관과 일반 복구의 삭제/교체는 지원하지 않는다.
- Phase03/04/06의 코드는 이번에 변경하지 않았다. 문서에는 각각 auto→custom/유럽 private subnet 미구현, 두 VM 동시 대조와 HTTPS probe, Minecraft TCP-only 검증 한계를 표시했다.

따라서 **로컬 구현·검사 완료**, **실제 Cloud 실습 완료**, **원문 모든 수동 단계 완료**, **종료 삭제 완료**를 구분한다. 새로운 배포에는 [보존형 실행 안내](../phase-10-15-execution.md)의 저장 계획 승인이 필요하다.

## 공식 근거

- [BigQuery Job 구조와 dryRun](https://docs.cloud.google.com/bigquery/docs/reference/rest/v2/Job), [getQueryResults의 전체 행 수·페이지](https://docs.cloud.google.com/bigquery/docs/reference/rest/v2/jobs/getQueryResults).
- [Uptime checker IP 조회](https://docs.cloud.google.com/monitoring/uptime-checks/using-uptime-checks), [provider uptime check resource_group](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_uptime_check_config).
- [Terraform data source](https://developer.hashicorp.com/terraform/language/data-sources), [Google provider7.45 MIG target_size](https://raw.githubusercontent.com/hashicorp/terraform-provider-google/v7.45.0/website/docs/r/compute_region_instance_group_manager.html.markdown).

## 처음 보는 사용자 리허설

1차: 독립 실행자가 로컬 명령·32개 문서/89개 링크·90개 Task와 하위 항목을 확인했다. 단일 Task의 준비 안내 누락, P10 작업 기록 진입/필드명, P09 유지와 삭제 상태 구분, 중복 하위 제목 검사를 지적했다. 네 항목 모두 수정했다. 최초 집계177은 Task 밖의 제목까지 포함한 수라, 2차의 독립 집계와 awk 대조로 Task 안의167개로 정정했다.

2차 observed: 새 실행자가 로컬 안내·단일 Task 출력·13개 안내 검사·당시34개 회귀와 Terraform mock6개·Phase10–15 gate를 모두 exit0으로 실행했다.34문서/107개 로컬 링크 누락0,90 Task/원문 하위 제목167개/상세 항목221개 누락0, 차단되는 막힘0이었다. 비차단 지적 네 가지(177 집계, Phase09 번호 붙음, Phase03 편집 메모, 목록의 golden query)는 수정하고 안내13개 검사를 재실행했다. 이후 코드 점검에서 추가한 Monitoring 대상·controller·replan/config 회귀까지 주 실행자의 최종40개 검사가 통과했다. Cloud 실행·실제 콘솔 클릭은 두 리허설 모두 범위 밖이다.
