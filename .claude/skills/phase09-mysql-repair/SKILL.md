---
name: phase09-mysql-repair
description: gcp-lab-harness Phase09의 MySQL1044 또는 root 역할 API400을 기존 리소스와 state를 보존하며 진단·복구할 때 사용한다. 일반적인 모든 HTTP400이나 다른 Phase에는 적용하지 않는다.
---

# Phase09 MySQL 보존 복구

기존 Phase09 run 복구에만 사용한다. 이 절차 자체는 새 Cloud 변경 승인이 아니다. 계정·project·run은 해당 실행의 saved inputs를 사용하고 개인 기본값을 만들지 않는다.

## 로컬 확인

저장소 최상위에서 다음 세 명령을 실행한다. 이 로컬 리허설은 여기서 끝나며 Cloud 로그인·plan/apply/실제verify/destroy를 실행하지 않는다.

```bash
bash tests/test-phase-09.sh
./scripts/phase-gate.sh docs/phases/phase-09-cloud-sql.md
./phases/09/execute.sh --help
```

## 실제 복구 순서

아래 실제 명령의 `execute.sh`는 저장소 최상위의 `./phases/09/execute.sh`를 뜻한다. `<기존ID>`와 `<승인SHA>`는 해당 run의 실제 값으로 대체한다.

1. 기존 run의 manifest·실패 stage/숫자 MySQL errno·recovery.json을 확인한다. state·로그를 보존하고 `execute.sh diagnose --run <기존ID>`로 조회한다. 조회 실패를 리소스 0개로 바꾸지 않는다. 자세한 실행 계약은 [Phase09 안내](../../../docs/phases/phase-09-cloud-sql.md)를 따른다.
2. 1044면 네트워크/비밀번호만 반복 변경하지 않는다. 비밀번호를 VM 밖으로 꺼내지 않는 읽기 전용 SQL로 인증 사용자·활성 역할·권한·DB 선택 결과를 구분한다. 이 프로젝트에서는 root@% 인증 성공·USAGE뿐·wordpress 접근1044가 관측됐다. 다른 errno까지 같은 원인으로 단정하지 않는다.
3. 역할 수정이 필요하면 `phases/09/sql_lab.py`의 검증된 경로를 사용한다. 기존 root는 BUILT_IN을 명시한 비밀번호 없는 역할 요청 → operation 성공 확인 → 별도 비밀번호 요청 순서다. databaseRoles는 update query, revokeExistingRoles=false다. 역할 실패 시 비밀번호를 변경하지 않고 후속 실패에도 역할 회수/사용자 삭제를 하지 않는다. 없는 root의 insert는 구현돼 있지만 이 복구 표본에서 실기 검증하지 않았다.
4. 소스 변경 후 로컬 검사와 동일 state의 `execute.sh replan --run <기존ID>`를 실행한다. 새 plan의 범위·source/input/state/identity·exact bundle SHA를 검토하고 사용자 승인 후에만 `execute.sh apply --run <기존ID> --confirm-plan-sha <승인SHA>`를 실행한다. no-op Terraform이어도 SQL action·코드가 바뀌면 새 승인이 필요하다. 3번의 기존 root 역할 보완은 해당 SQL action을 포함한 새 plan 승인 범위 안에서 진행한다. 삭제/교체·새 계정·승인받은 DB 역할 보완 범위를 넘는 권한 확장(예: GCP IAM 추가)이 필요하면 중단하고 별도 지시를 받는다.
5. apply 성공 직후 `execute.sh verify --run <기존ID>`를 실행한다. API operation 성공만으로 완료라 하지 않는다. 양쪽 guest 설치·Proxy SQL 쓰기/private SQL 읽기·두 HTTP 본문/DB probe·Task1–6 evidence와 manifest verified를 대조한다. 실패하면 환경을 유지하고 추가 진단하며 임의 재시도/전체 destroy를 하지 않는다.

## 검증과 한계

- Verified: 2026-08-26, 기존 SQL1/MySQL8.0.45·VM2의 run1에서 분리 요청 apply와 Task1–6 실제 검증 exit0, Terraform0/0/0. 70개 로컬 테스트와 TF 검사도 통과했다.
- Evidence: [PRODUCT-TRUTH의 Phase09 실제 검증 성공](../../../memory/PRODUCT-TRUTH.md), ignored `artifacts/phase-09-separated-role-cloud-{apply,verify}.log`와 해당 run의 `evidence/phase-09-machine.json`.
- Source: [Cloud SQL 실행 경계](../../../memory/knowledge/gcp-sql-wordpress.md)의 분리 요청 성공 항목.
- 기존400의 원문이 없어 type 누락/비밀번호 결합 중 하나만을 원인으로 분리 입증하지 않았다. 모든400·다른 환경·Windows를 보장하지 않는다.
- 리소스 유지가 요청됐으면 destroy하지 않는다. `lab_completion.complete=false/destroy_pending=true`는 미정리 상태이고 Task 검증 실패와 구분한다. 보존 중 과금과 guest 비밀번호 보유를 알린다.
- 90일 경과·절차 실패·근거 지식 변경 시 재검증한다. 이전 승인 SHA·개인 로그/비밀/state를 재사용 기본값이나 Git 게시 자료로 만들지 않는다.
