# Phase 02 — Task 하위 항목별 콘솔 확인

[공통 준비](../console-checks.md) · [Phase 요약](../phases/phase-02-infrastructure-preview.md)

확인 안내이며 실제 Cloud 성공 기록이 아닙니다. `<RUN_ID>`·`<PROJECT_ID>`는 본인의 실행 값입니다. 읽기 전용으로 확인하며 생성·편집 저장·삭제·비밀번호 재설정은 하지 않습니다. 현재 값과 과거 검증 증거를 구분합니다. 로컬 증거는 `artifacts/runs/<RUN_ID>/phase-02/evidence/phase-02-machine.json`입니다.

원문 `02.Infrastructure Preview_KR.md`. 현재 코드는 `jenkins-1-vm-<RUN_ID>`에 외부 IP 를 주지 않고 IAP 를 사용한다. public Site URL 을 기대하면 안 된다. 공식 Marketplace 출처가 입증되지 않은 경우 blocked 를 유지한다.

## Task 1. Marketplace를 사용하여 배포 구축하기

### Marketplace로 이동하기

원문 절차 범위: 상품 검색/설명/설치 소프트웨어.

1. 화면 열기·값 대조: 상단 검색 Marketplace → Jenkins → 승인된 상품 상세의 제공자·상품 ID·소프트웨어 목록을 saved provenance 와 대조한다.
2. 판정·한계·보조 증거: 상품이 현재 검색되지 않거나 공식 artifact 가 없으면 확인불가/blocked. 다른 Jenkins 상품을 대신 배포하지 않음.

### Jenkins 실행하기

원문 절차 범위: 약관/API/SA/zone/e2-standard-2/배포.

1. 화면 열기·값 대조: Compute Engine → VM 인스턴스 → `jenkins-1-vm-<RUN_ID>` → zone/머신/서비스 계정 확인 → 부팅 디스크 링크 → source image 가 승인된 `click-to-deploy-images/.../jenkins-v20250921`인지 대조.
2. 판정·한계·보조 증거: VM 존재는 Marketplace 약관 클릭·배포 UI 완료 증거 아님. manifest 의 공식 출처와 `.checks.marketplace_provenance`를 함께 확인; API 나 배포 버튼 누르지 않음.

## Task 2. 배포 살펴보기

### 설치된 소프트웨어 확인 및 Jenkins 로그인하기

원문 절차 범위: 임시 관리자/URL/로그인/plugins.

1. 화면 열기·값 대조: VM 상세에서 외부 IP 없음 확인 → 기존 허용 IAP SSH 에서 `systemctl is-active jenkins`, `curl -I --max-time 5 http://127.0.0.1:8080/login` 읽기 검사. Jenkins 로그인 화면이 HTTP 로 정상 응답해야 한다.
2. 판정·한계·보조 증거: 자동 검증은 HTTP 준비 상태만 본다. 임시 비밀번호 생성·로그인·플러그인 설치 UI 는 별도 수동 경계. 외부 IP 링크나 공개 80 포트를 새로 만들지 않는다.

### Jenkins 살펴보기

원문 절차 범위: Manage Jenkins 메뉴.

1. 화면 열기·값 대조: 이미 허용된 터널/로그인 세션이 있을 때 Jenkins 왼쪽 메뉴의 Manage Jenkins 화면을 읽기만 확인한다.
2. 판정·한계·보조 증거: 로그인된 UI 가 없다면 `.checks.jenkins_http_ready`로 HTTP 근거만 확인하고 관리자 UI 는 미확인 표시. 재시작/설정 저장 금지.

## Task 3. 서비스 관리하기

### 배포 확인 및 VM에 SSH 접속하기

원문 절차 범위: VM 상세/SSH.

1. 화면 열기·값 대조: VM 목록 → 정확한 run VM → NIC 의 private 주소/외부 주소 없음 확인 → VPC 방화벽 `gcp-lab-p02-fw-<RUN_ID>`에서 IAP `35.235.240.0/20` 및 TCP22/80/8080 확인.
2. 판정·한계·보조 증거: SSH 성공은 계정/IAP 권한도 필요. 접속 실패를 Jenkins 불량으로 곧바로 해석하지 않음.

### 서비스 종료 및 재시작하기

원문 절차 범위: stop→HTTP 실패→start→HTTP 성공.

1. 화면 열기·값 대조: 기존 SSH 에서 `systemctl is-active jenkins` 결과 active 를 확인하고 `.checks.jenkins_stop_start_transition=passed`와 검증 시각을 대조한다.
2. 판정·한계·보조 증거: 현재 active 는 과거 stop/start 를 입증 못 함. stop/restart 명령을 다시 실행하지 않는다.

## Task 4. Review

### 검토할 세부 항목

1. 위 상품 출처/VM 사양/HTTP 응답/중지·시작 전이를 각각 확인했는지 정제 evidence 의 다섯 checks 와 비교한다. UI 로그인/플러그인 설치를 미수행이면 그 경계를 남긴다.
2. 위 화면별 확인 값과 로컬 정제 증거의 상태·실행 시각을 각각 비교합니다. 미수행·수동 경계를 통과로 바꾸지 않습니다. 삭제했다면 현재 목록 부재와 삭제 전 증거를 나눠 기록합니다.

## 출처·검증 범위

원문: [보존된 실습 02](../../references/google-cloud-labs-ko/labs/02.Infrastructure%20Preview_KR.md). 2026-08-26 에 원문 하위 제목과 현재 코드의 대조를 수행했습니다(observed). 메뉴의 공식 설명은 Phase 요약의 근거 링크를 참고합니다. 실제 콘솔 클릭·Cloud 통합 성공은 별도 검증입니다.
