# Phase 02 — Infrastructure Preview

- 원본: `references/google-cloud-labs-ko/labs/02.Infrastructure Preview_KR.md`
- 비용 위험: 중간
- 주요 서비스: Cloud Marketplace, Compute Engine, Jenkins

## 목적

원본이 지정한 Marketplace Jenkins 배포의 구성과 서비스 수명주기를 CLI로 재현하고 검증한다. 해당 상품의 공식 자동 배포 경로가 없으면 임의 VM을 동등 결과로 대체하지 않고 Phase를 `blocked`로 종료한다.

## 범위와 원본 매핑

| 원본 Task | 분류 | 자동화·증거 |
|---|---|---|
| Task 1. Marketplace를 사용하여 배포 구축하기 | conditional | 공식 Marketplace Terraform·Deployment Manager·API 경로 확인 후 정확한 상품 배포 |
| Task 2. 배포 살펴보기 | automated | deployment provenance, VM·disk·network inventory, Jenkins HTTP 상태 |
| Task 3. 서비스 관리하기 | automated | SSH를 통한 Jenkins service stop/start와 상태 전이 |
| Task 4. Review | cli-equivalent | 구성·서비스·접속 결과를 구조화 summary로 검토 |

## Task별 콘솔 확인

[하위 항목별 상세 확인](../console/phase-02.md): 원문 하위 제목/번호 절차마다 클릭 경로·값·판정·한계를 확인합니다.

[공통 확인법](../console-checks.md)을 먼저 읽고 자신의 프로젝트·해당 run만 선택한다. 아래는 **확인 기준**이지 이번 실행의 성공 기록이 아니다. 원본 Task 이름은 위 매핑과 대응한다.

| Task | 콘솔 경로·대상 | 통과 기준 | 한계·보조 확인 |
|---|---|---|---|
| 1 | Marketplace → 승인된 Jenkins 상품; 배포 결과의 리소스 링크 | 상품 ID·배포 artifact와 생성 리소스의 출처가 승인 계획과 일치 | 지원 공식 배포 경로가 없으면 blocked. 임의 Jenkins VM을 Marketplace 완료로 간주하지 않음 |
| 2 | Compute Engine → VM 인스턴스 → 해당 run VM 및 디스크 | 예상 VM/디스크/네트워크가 있고 Jenkins 주소에서 정상 화면 | VM RUNNING만으로 Jenkins 준비 완료가 아님. HTTP·provenance evidence 대조 |
| 3 | VM 인스턴스 → SSH → Jenkins 서비스 상태 | 허용된 SSH 세션에서 systemctl is-active jenkins가 active | 이 읽기 전용 조회는 현재 상태만 확인. stop/start 전이는 저장 증거로 확인하고 재중단하지 않음 |
| 4 | Marketplace 상품 정보 + 해당 VM 상세 | Task 1–3 출처·구성·HTTP·서비스 전이 증거를 함께 설명 가능 | 상품 미지원/blocked이면 전체 완료로 표시하지 않음 |

메뉴 확인 근거(2026-08-26): [VM 상세 확인](https://docs.cloud.google.com/compute/docs/instances/view-vm-details). 화면 언어/버전에 따라 상단 검색으로 같은 서비스에 접근한다. 실제 UI 클릭 전 과정 검증은 별도다.

## 구현 작업

1. 상품 ID, 현재 제공 상태, 공식 CLI 배포 artifact를 preflight에서 확정한다.
2. 비용·머신 유형·disk·방화벽 변경을 저장된 plan에 기록한다.
3. 지원되는 공식 경로로만 배포하고 생성 리소스 provenance를 manifest에 넣는다.
4. Jenkins readiness를 제한 시간 polling으로 확인하고 service 중지·재시작을 검증한다.
5. 초기 관리자 비밀은 안전한 일회성 채널로만 취급하고 evidence에서 제거한다.

## 실행 계약

인증된 Command Code `cmd`가 공식 배포 가능성을 먼저 판정한다. 실행에는 모델 선택 인수를 전달하지 않는다. 공식 CLI 경로가 확인된 경우에만 `apply`하고, 그렇지 않으면 이유와 확인한 상품 정보를 남긴 `blocked` 결과로 Extension에 handoff한다.

## 검증 게이트

- 배포된 리소스가 원본 Marketplace 상품에서 유래했음을 증명한다.
- Jenkins HTTP endpoint와 VM 내부 service가 모두 ready다.
- stop 동안 실패하고 restart 뒤 성공하는 expected transition을 확인한다.
- Extension은 Marketplace provenance, firewall 범위, 비밀정보 노출 여부를 검토한다.
- 사용자가 통과 또는 blocked 처리 결과를 명시적으로 승인해야 다음 전이가 가능하다.

## 안전·비용 가드레일

- 상품·버전·가격 정보가 불명확하면 apply하지 않는다.
- 대체 Jenkins 설치를 Marketplace 실습 완료로 표시하지 않는다.
- 관리 포트는 승인된 source range에만 노출한다.
- 자동 만료 시간과 VM·disk·IP 전체 cleanup manifest를 둔다.

## 완료 조건

- Task 1–4의 지원 여부와 결과가 coverage manifest에 있다.
- 정확한 상품 배포·서비스 상태 검증이 통과했거나 재현 불가가 근거와 함께 승인된 `blocked`다.
- 실행한 경우 cleanup 후 소유 리소스가 0이다.

## Command Code·Extension handoff 지시

Command Code는 상품 지원 여부를 추측하지 말고 공식 artifact를 근거로 기록한다. Extension은 read-only resource 조회와 evidence를 대조하고, blocked를 성공으로 바꾸지 않는다. 최종 결정은 사용자가 내린다.

## Git 종료 조건

승인된 evidence를 `Phase 02: Marketplace 인프라 미리보기 자동화 및 검증 완료`로 커밋·push한다. blocked라면 메시지에 완료를 쓰지 않고 별도 사용자 지시를 기다린다.
