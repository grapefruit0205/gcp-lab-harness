# Phase 05 — 가상 머신 생성

- 원본: `references/google-cloud-labs-ko/labs/05.Creating Virtual Machines_KR.md`
- 비용 위험: 중간
- 주요 서비스: Compute Engine Linux·Windows·custom machine

## 목적

Linux 유틸리티 VM, Windows VM, custom machine VM을 명시적 사양으로 생성하고 각 운영체제와 머신 설정의 readiness를 CLI로 검증한다.

## 범위와 원본 매핑

| 원본 Task | 분류 | 자동화·증거 |
|---|---|---|
| Task 1. 유틸리티 가상 머신 생성하기 | automated | VM 사양·상태·serial log·SSH probe |
| Task 2. Windows 가상 머신 생성하기 | cli-equivalent | Windows VM readiness와 일회성 비밀번호 생성 경계 |
| Task 3. 커스텀 가상 머신 생성하기 | automated | custom vCPU·memory describe와 SSH guest 검사 |
| Task 4. Review | cli-equivalent | 세 VM의 설정·로그·접속 결과 비교 |

## Task별 콘솔 확인

[공통 확인법](../console-checks.md)을 먼저 읽고 자신의 프로젝트·해당 run만 선택한다. 아래는 **확인 기준**이지 이번 실행의 성공 기록이 아니다. 원본 Task 이름은 위 매핑과 대응한다.

| Task | 콘솔 경로·대상 | 통과 기준 | 한계·보조 확인 |
|---|---|---|---|
| 1 | Compute Engine → VM 인스턴스 → utility VM 상세 | RUNNING, Linux 이미지·zone·머신·디스크·NIC가 계획과 일치 | SSH·guest OS 확인 evidence도 필요 |
| 2 | Compute Engine → VM 인스턴스 → Windows VM 상세/직렬 포트 출력 | Windows 이미지·사양·guest agent 준비 상태가 기대와 일치 | RDP readiness 증거와 실제 GUI 로그인은 별개. 비밀번호를 재설정하거나 로그에 게시하지 않음 |
| 3 | Compute Engine → VM 인스턴스 → custom VM 상세 | custom vCPU·메모리·zone이 승인 계획과 일치 | guest CPU·메모리 인식은 SSH 검사 evidence 대조 |
| 4 | 세 VM 상세 페이지 | Linux/Windows/custom 사양과 각 readiness 결과를 나란히 확인 | RUNNING만으로 OS 로그인·앱 동작이 입증되지 않음 |

메뉴 확인 근거(2026-08-26): [VM 상세 확인](https://docs.cloud.google.com/compute/docs/instances/view-vm-details). 화면 언어/버전에 따라 상단 검색으로 같은 서비스에 접근한다. 실제 UI 클릭 전 과정 검증은 별도다.

## 구현 작업

1. zone, image family, machine series, Windows license 비용과 quota를 preflight한다.
2. 세 VM의 image·disk·network·service account·metadata를 saved plan에 고정한다.
3. Linux와 custom VM은 SSH·guest OS·CPU·memory를 확인한다.
4. Windows는 guest agent와 RDP readiness를 CLI로 확인하고 GUI 조작은 경계로 기록한다.
5. serial output에서 자격 증명·개인정보를 제거한 상태 요약만 보존한다.

## 실행 계약

Command Code `cmd`는 현재 고정 모델을 상속해 세 VM adapter를 순서대로 실행한다. Windows 비밀번호는 필요할 때만 안전한 일회성 출력으로 제공하고 artifact에 저장하지 않는다. machine verification 뒤 Extension review까지 VM을 유지한다.

## 검증 게이트

- 각 VM의 image, zone, machine type, disk, NIC가 plan과 일치한다.
- Linux·custom VM SSH와 guest 검사가 성공한다.
- Windows VM의 guest agent와 RDP port readiness가 정상이다.
- Extension은 Compute Engine read-only describe와 secret scan을 수행한다.
- 사용자가 명시적으로 승인한 뒤에만 VM과 disk를 삭제한다.

## 안전·비용 가드레일

- machine series·vCPU·memory·disk size에 상한을 둔다.
- public SSH/RDP source를 `0.0.0.0/0`으로 열지 않는다.
- Windows 비밀번호, SSH private key, serial 민감정보를 Git에 넣지 않는다.
- auto-delete 여부와 별개로 disk·IP 잔여 inventory를 확인한다.

## 완료 조건

- Task 1–4 coverage와 세 VM의 기계 검증 결과가 있다.
- Extension에서 P0/P1이 없고 사용자가 승인했다.
- cleanup 후 VM, disk, address 잔여 리소스가 0이다.

## Command Code·Extension handoff 지시

Command Code는 RDP GUI를 자동 완료로 표시하지 않고 CLI로 관찰한 readiness만 보고한다. Extension은 사양·방화벽·비밀정보 처리를 검토하고 사용자에게 GUI 경계와 미실행 검사를 명시한다.

## Git 종료 조건

`Phase 05: 가상 머신 생성 자동화 및 검증 완료` 커밋을 같은 branch에 push하고 remote SHA 확인 후 Phase 06으로 전이한다.
