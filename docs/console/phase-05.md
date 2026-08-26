# Phase 05 — Task 하위 항목별 콘솔 확인

[공통 준비](../console-checks.md) · [Phase 요약](../phases/phase-05-creating-vms.md)

확인 안내이며 실제 Cloud 성공 기록이 아닙니다. `<RUN_ID>`·`<PROJECT_ID>`는 본인의 실행 값입니다. 읽기 전용으로 확인하며 생성·편집 저장·삭제·비밀번호 재설정은 하지 않습니다. 현재 값과 과거 검증 증거를 구분합니다. 로컬 증거는 `artifacts/runs/<RUN_ID>/phase-05/evidence/phase-05-machine.json`입니다.

원문 `05.Creating Virtual Machines_KR.md`. 현재 **세 VM 모두 외부 IP 없음**, SSH/RDP IAP 만 허용. Windows 비밀번호/GUI 는 manual-boundary.

## Task 1. 유틸리티 가상 머신 생성하기

### VM 생성하기

1. 화면 열기·값 대조: VM 목록 → `utility-vm-<RUN_ID>` → e2-medium·savedzone·Debian12·10GB pd-balanced → NIC 외부 IP 없음 확인.
2. 판정·한계·보조 증거: 원문에서 e2-standard-4 를 잠깐선택한 비용비교는 자동화 미수행. machine 변경/비용계산을 확인 목적으로 저장하지 않음.

### VM 세부정보 살펴보기

1. 화면 열기·값 대조: utility 상세 → CPU platform·network tags·boot disk 링크·availability policies 의 자동재시작/호스트유지보수 항목을 읽고 savedplan 과 대조.
2. 판정·한계·보조 증거: 플랫폼모델은 실행시 배정될 수 있어 특정 CPU 브랜드 고정기대금지. Edit 를 열었다면 저장하지 않음; 디스크자동삭제 옵션은 삭제수행증거와 별개.

### VM 로그 살펴보기

1. 화면 열기·값 대조: utility 상세 → Logging → 로그탐색기 → 실행 시간/VM 인스턴스 필터 → 행확장에서 timestamp/resource/severity 확인.
2. 판정·한계·보조 증거: 로그미수집/보존/권한에 따라 없을 수 있음. `.checks.utility_ssh_guest`와 `utility_guest_summary`는 별도 guest 근거.

## Task 2. Windows 가상 머신 생성하기

### VM 생성하기

1. 화면 열기·값 대조: VM → `windows-vm-<RUN_ID>` → e2-standard-2·Windows2022 Core → boot disk64GB pd-ssd → NIC 외부 IP 없음; VPC `gcp-lab-p05-fw-rdp-<RUN_ID>`에서 IAP3389 확인.
2. 판정·한계·보조 증거: 원문 HTTP/HTTPS 공개와 달리 자동화는 IAP 제한. `.checks.windows_guest_agent_rdp_ready`는 VM 내부 TermService/포트준비 증거이지 RDP 로그인성공 아님.

### VM의 비밀번호 설정하기

1. 화면 열기·값 대조: Windows VM 상세에서 연결유형 RDP 임을 읽고 `.checks.windows_password_and_gui=manual-boundary` 확인.
2. 판정·한계·보조 증거: 비밀번호재설정 버튼을 누르지 않는다. 현재 자동화는 원문일회성비밀번호 발급을 완료하지 않았고 원문도 실제 RDP 연결은 범위밖.

## Task 3. 커스텀 가상 머신 생성하기

### VM 생성하기

1. 화면 열기·값 대조: VM → `custom-vm-<RUN_ID>` → `e2-custom-2-4096`, vCPU2/메모리 4GiB, Debian12, savedzone, 외부 IP 없음 확인.
2. 판정·한계·보조 증거: RUNNING 이 guest CPU 인식 증거는 아님.

### 커스텀 VM에 SSH로 접속하기

1. 화면 열기·값 대조: 허용된 IAP SSH → `nproc` 2, `free -m`, `lscpu` 읽기 → evidence `custom_guest_summary`와 대조한다.
2. 판정·한계·보조 증거: OS 표시메모리는 예약영역 때문에 정확 4096MB 가 아닐 수 있음. 코드판정 3500–4300MB; 원문 dmidecode 까지 수행했다고 자동화증거를 확대하지 않음.

## Task 4. Review

### 검토할 세부 항목

1. 세 VM 타입·OS·외부 IP·Linux guest/Windows guest-attribute 를 각각 비교하며 비밀번호·GUI 경계를 유지한다.
2. 위 화면별 확인 값과 로컬 정제 증거의 상태·실행 시각을 각각 비교합니다. 미수행·수동 경계를 통과로 바꾸지 않습니다. 삭제했다면 현재 목록 부재와 삭제 전 증거를 나눠 기록합니다.

## 출처·검증 범위

원문: [보존된 실습 05](../../references/google-cloud-labs-ko/labs/05.Creating%20Virtual%20Machines_KR.md). 2026-08-26 에 원문 하위 제목과 현재 코드의 대조를 수행했습니다(observed). 메뉴의 공식 설명은 Phase 요약의 근거 링크를 참고합니다. 실제 콘솔 클릭·Cloud 통합 성공은 별도 검증입니다.
