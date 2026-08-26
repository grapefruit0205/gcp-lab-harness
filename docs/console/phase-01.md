# Phase 01 — Task 하위 항목별 콘솔 확인

[공통 준비](../console-checks.md) · [Phase 요약](../phases/phase-01-console-cloud-shell.md)

확인 안내이며 실제 Cloud 성공 기록이 아닙니다. `<RUN_ID>`·`<PROJECT_ID>`는 본인의 실행 값입니다. 읽기 전용으로 확인하며 생성·편집 저장·삭제·비밀번호 재설정은 하지 않습니다. 현재 값과 과거 검증 증거를 구분합니다. 로컬 증거는 `artifacts/runs/<RUN_ID>/phase-01/evidence/phase-01-machine.json`입니다.

원문 `01.Working with the Google Cloud Console and Cloud Shell_KR.md`. 객체/버킷은 원문 GUI 생성 대신 API 동등 결과다. 증거 `.checks`는 `account_project_tool_preflight`, `two_private_buckets`, `object_roundtrip_sha256`, `isolated_profile_reload`, `cloud_shell_ui`다.

## Task 1. Cloud console을 사용하여 버킷 생성하기

### Storage 서비스로 이동하여 버킷 생성하기

원문 절차 범위: 1–5: 이름/기본값/PAP 확인.

1. 화면 열기·값 대조: Cloud Storage → 버킷 → `gcp-lab-p01-console-<RUN_ID>` → 구성에서 위치 `US`, Standard 확인 → 권한에서 공개 액세스 방지 enforced 및 균일한 버킷 수준 액세스 확인.
2. 판정·한계·보조 증거: 생성 버튼을 누르지 않는다. `.checks.two_private_buckets`가 passed 여도 GUI 클릭 수행을 뜻하지 않음.

### Cloud console의 기능 살펴보기

원문 절차 범위: Notifications 피드백.

1. 화면 열기·값 대조: 콘솔 오른쪽 위 알림 종 아이콘 → 이번 실행 시각의 항목만 펼쳐 작업 이름·상태를 읽는다.
2. 판정·한계·보조 증거: Terraform/API 작업이 콘솔 알림에 남는다는 보장은 없음. 알림이 없으면 manifest 와 작업 로그가 근거이며 이 UI 탐색은 수동 경계.

## Task 2. Cloud Shell 액세스하기

### Cloud Shell 열고 기능 살펴보기

원문 절차 범위: 1–2: 열기/최소화/최대화/새 창/닫기.

1. 화면 열기·값 대조: 상단 Cloud Shell 아이콘 → 터미널이 열리면 본인 계정/프로젝트 표시 확인 → 툴바의 최소화·복원·새창·닫기 위치 확인. `gcloud config get-value project`, `gcloud auth list --filter=status:ACTIVE --format='value(account)'`로 읽기만 대조.
2. 판정·한계·보조 증거: Restart/Reset 은 누르지 않음. 로컬 Bash 검증은 실제 Cloud Shell 사용 증거 아님. `cloud_shell_ui=manual-boundary`.

## Task 3. Cloud Shell을 사용하여 Cloud Storage 버킷 생성하기

### 두 번째 버킷을 생성하고 Cloud console에서 확인하기

원문 절차 범위: 1–4: CLI 생성/목록 대조.

1. 화면 열기·값 대조: Cloud Storage → 버킷 → 새로고침 → `gcp-lab-p01-shell-<RUN_ID>` 검색 → console 버킷과 이름이 다르고 위치 US/Standard/PAP enforced 인지 확인.
2. 판정·한계·보조 증거: 버킷 두 개 존재만으로 어느 UI 에서 만들었는지 구분 불가. API 동등 자동화임.

## Task 4. Cloud Shell의 추가 기능 살펴보기

### 파일 업로드하기

원문 절차 범위: 1–7: Cloud Shell 업로드/ls/버킷 복사/툴바.

1. 화면 열기·값 대조: shell 버킷 → 객체 → `fixtures/` → `<RUN_ID>.txt` → 객체 상세의 이름·크기를 확인한다. 비민감 fixture 내용은 `phase=01`과 본인 run ID 다.
2. 판정·한계·보조 증거: 현재 객체 화면은 Cloud Shell Upload 버튼 사용을 입증하지 않음. `object_roundtrip_sha256=passed`와 `fixture_sha256`으로 다운로드 무결성을 대조. 확인하려고 다시 업로드하지 않음.

## Task 5. Cloud Shell에서 지속 상태 만들기

### 사용 가능한 리전 확인하기

원문 절차 범위: 1–3: 목록/리전 선택.

1. 화면 열기·값 대조: Cloud Shell 의 읽기 전용 `gcloud compute regions list`에서 이번 saved inputs 의 리전이 목록에 있는지 확인.
2. 판정·한계·보조 증거: 목록 확인은 설정 변경이 아님. 실제 자동화가 원문 리전변수 선택 과정을 수행했다는 별도 evidence 는 없음.

### 환경 변수 생성 및 확인하기

원문 절차 범위: export/echo.

1. 화면 열기·값 대조: 현재 자동화의 `isolated_profile_reload` 값을 로컬 evidence 에서 확인한다. 직접 원문 실습을 했던 Cloud Shell 이라면 `printenv INFRACLASS_REGION`으로 현재 값만 확인 가능.
2. 판정·한계·보조 증거: 자동화는 `HARNESS_PROFILE_MARKER`를 임시 HOME 에 두므로 원문 `INFRACLASS_REGION`이 본인 셸에 없어도 정상이다. 환경 변수를 지금 생성하지 않는다.

### 환경 변수를 파일에 추가하기

원문 절차 범위: config 저장/프로젝트/source/Restart 전후.

1. 화면 열기·값 대조: 자동화 evidence 의 `account_project_tool_preflight`와 `isolated_profile_reload`를 확인한다. 직접 원문을 수행했다면 Cloud Shell 편집기에서 본인의 `infraclass/config`를 읽기 전용으로 열어 region/project export 두 줄을 확인한다.
2. 판정·한계·보조 증거: 자동화는 본인 `infraclass/config`를 만들지 않는다. 없는 파일을 생성하거나 Restart 하여 과거 검사를 재현하지 않음.

### bash 프로필 수정 및 지속성 설정하기

원문 절차 범위: .profile/source/Restart 후 값.

1. 화면 열기·값 대조: 자동화 evidence 의 `isolated_profile_reload=passed` 확인. 원문 수동 실습을 한 사용자만 Cloud Shell 편집기에서 `.profile`의 config source 줄을 읽는다.
2. 판정·한계·보조 증거: 자동화는 임시 `.bashrc`의 새 Bash 로딩만 검사한다. Cloud Shell VM 재시작 지속성/실제 `.profile` 변경은 미검증이며 확인용 편집 금지.

## Task 6. Google Cloud 인터페이스 정리하기

### 개인 프로젝트에서 생성한 리소스 정리하기

원문 절차 범위: 1–2: 정확한 두 버킷 삭제.

1. 화면 열기·값 대조: 명시적 destroy 후 Cloud Storage → 버킷에서 console/shell 두 정확한 이름이 없는지 확인하고 해당 run 삭제 inventory 0 과 대조한다.
2. 판정·한계·보조 증거: destroy 전 두 버킷이 남는 것은 정상. 원문 rm 명령을 재실행하지 않는다. 타 run·soft-delete 보존을 별도로 구분.

## 출처·검증 범위

원문: [보존된 실습 01](../../references/google-cloud-labs-ko/labs/01.Working%20with%20the%20Google%20Cloud%20Console%20and%20Cloud%20Shell_KR.md). 2026-08-26 에 원문 하위 제목과 현재 코드의 대조를 수행했습니다(observed). 메뉴의 공식 설명은 Phase 요약의 근거 링크를 참고합니다. 실제 콘솔 클릭·Cloud 통합 성공은 별도 검증입니다.
