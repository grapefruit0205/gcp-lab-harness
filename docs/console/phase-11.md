# Phase 11 — Task 하위 항목별 콘솔 확인

[공통 준비](../console-checks.md) · [Phase 요약](../phases/phase-11-monitoring.md)

본인 프로젝트·run 을 선택합니다. 확인 안내이지 실제 성공 기록이 아닙니다. 생성/저장/정책 토글/부하/테스트메일은 실행하지 않습니다. 증거는 `artifacts/runs/<RUN_ID>/phase-11/evidence/`입니다. 그래프 시간 범위를 실행 시각으로 맞춥니다.

## Task 1. Cloud Monitoring 열기

### 모니터링할 리소스 확인하기

1. **Compute Engine → VM instances**에서 RUN_ID 로 필터합니다.
2. nginxstack-1/2/3 세 VM 의 RUNNING·run/phase 라벨·instance ID 를 읽습니다.
3. VM 존재는 Nginx 응답이나 metric 도착 증거가 아닙니다.

### VM이 없는 경우 CLI로 배포하기

1. 현재 run 의 manifest 가 applied 인지 확인하고 VM 목록의 프로젝트·zone·이름 필터를 다시 봅니다.
2. 실행 전에는 부재가 정상입니다. 배포했다면 계획의 VM3 개가 있어야 합니다.
3. 원문 create 명령을 확인용으로 재실행하지 않습니다. 실패 시 보존 로그를 진단합니다.

### Cloud Monitoring 열기

1. 상단 검색 **Monitoring → Overview → Settings**를 엽니다.
2. metrics scope 가 본인 프로젝트를 포함하는지 읽고 실행 시각의 metric 을 봅니다.
3. 별도 Workspace/무료계정 생성이나 다른 프로젝트 추가는 필요하지 않습니다.

## Task 2. 커스텀 대시보드

### 대시보드 생성하기

1. **Monitoring → Dashboards → Phase 11 <RUN_ID>**를 엽니다.
2. 이름과 현재 run 의 대시보드가 맞는지 확인합니다.
3. Create Dashboard 를 누르지 않습니다.

### 차트 추가하기

1. CPU utilization 차트의 측정항목/구성을 읽습니다.
2. gce_instance, `compute.googleapis.com/instance/cpu/utilization`, run 라벨 필터,60 초 ALIGN_MEAN 및 VM3 개의 선을 대조합니다.
3. 빈 그래프는 시간 범위·수집 지연·권한도 점검합니다. 선 개수만으로 정확한 VM 집합을 입증하지 않습니다.

### Metrics Explorer

1. **Monitoring → Metrics explorer → VM Instance → CPU utilization**을 선택합니다.
2. run 라벨 필터·1 분 정렬로 같은 VM3 개가 표시되는지 읽기 조회합니다.
3. 이는 사용자의 수동 탐색입니다. 차트를 저장하거나 부하를 새로 만들지 않습니다.

## Task 3. 알림 정책

### 알림 생성 및 첫 번째 조건 추가하기

1. **Alerting → Policies → Phase 11 CPU <RUN_ID> → Conditions** 첫 조건을 엽니다.
2. VM1 의 instance_id, CPU utilization, Above20%,60 초를 확인합니다.
3. API 값 0.2 와 콘솔 20%를 구분합니다. 최종 policy 는 Off 가 정상입니다.

### 두 번째 조건 추가하기

1. 같은 policy 의 두 번째 조건과 Multi-condition trigger 를 봅니다.
2. 다른 VM2 의 instance_id·20%/60 초·All conditions are met(AND)를 확인합니다.
3. 같은 VM 에 같은 조건을 두 번 넣은 것과 구분합니다.

### 알림 설정 구성 및 알림 정책 완료하기

1. policy 의 Notifications 와 **Alerting → Notification channels**를 읽습니다.
2. 기본 자동화는 채널 연결 없음입니다. 별도로 승인한 기존 채널을 설정했다면 해당 이름만 대조합니다.
3. 이메일 채널 생성·메일 수신은 자동 검증하지 않습니다. 주소등록/테스트메일/저장을 확인 목적으로 수행하지 않습니다.

## Task 4. 리소스 그룹

### 1–4. 그룹 이름·조건

1. **Monitoring → Groups → Phase 11 nginx <RUN_ID> → Details**를 엽니다.
2. 현재 run 라벨을 정확히 선택하며 다른 run 을 포함하지 않는지 읽습니다.
3. 원문의 이름 contains nginx 대신 run 라벨로 범위를 좁혔습니다.

### 5–7. 구성원·대시보드

1. 같은 group 의 Resources/Members 와 그룹 대시보드를 엽니다.
2. nginx VM3 개의 instance ID 를 Compute 목록과 정확히 대조합니다.
3. 구성원 수 3 만 맞고 다른 VM 이 섞이면 실패입니다. 페이지가 있다면 끝까지 확인합니다.

## Task 5. 가동 시간 모니터링

### 1–3. HTTP·그룹·주기

1. **Monitoring → Uptime checks → Phase 11 uptime <RUN_ID> → Configuration**을 엽니다.
2. HTTP/80/경로 `/`, Instance group/본인 group, frequency1minute 를 읽습니다.
3. public checker 는 VM 외부주소로 접근합니다. 방화벽은 일반 LB healthcheck CIDR 이 아니라 실제 uptime source IP 목록과 대조합니다.

### 4–6. 제목·알림

1. uptime 의 표시이름과 알림 연결을 읽습니다.
2. 현재 run 이름과 기본 외부 알림 미연결을 확인합니다.
3. 원문의 채널 선택/알림 생성은 수동 경계입니다.

### 7–8. 실제 성공 값

1. uptime 상세의 Checked locations/Passed checks 에서 VM 별 최근 결과를 봅니다.
2. VM3 개 각각의 최신 체크가 성공인지 `phase-11-machine.json`과 대조합니다.
3. 시계열이 존재해도 boolValue=false 는 실패입니다. Test 버튼 대신 이미 수집된 결과를 읽습니다.

## Task 6. 알림 비활성화하기

### 1–3. 비활성화 전후

1. **Alerting → Policies → Phase 11 CPU <RUN_ID>**에서 Enabled=Off 를 확인합니다.
2. `alert-before-disable.json`에 같은 policy 가 enabled=true 였는지 대조합니다.
3. 현재 Off 만으로 과거 전이가 입증되지는 않습니다. 다시 켜지 않습니다.

## Task 7. Review

### 프로젝트·차트·AND·그룹·uptime·비활성화

1. Task1–6 화면과 정제 evidence 를 차례로 비교합니다.
2. VM3 개/두조건/정확한 group/최신 uptime 성공/Off 를 각각 기록합니다.
3. MCP 연결·메일 도착·사용자 Metrics Explorer 조작은 기계 PASS 에 포함하지 않습니다.

## 출처·검증 범위

2026-08-26 원문 11·현재 코드 대조(observed). 실제 UI/Cloud 성공은 별도입니다. [공식 uptime IP 목록](https://docs.cloud.google.com/monitoring/uptime-checks/using-uptime-checks), [공개 uptime 구성](https://docs.cloud.google.com/monitoring/uptime-checks).
