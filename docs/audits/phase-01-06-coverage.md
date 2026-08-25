# Phase 01–06 구현 누락 감사

- 감사 기준: `docs/phases/phase-01-*.md`부터 `phase-06-*.md`까지의 Task, 검증 게이트, 안전·비용 가드레일
- 판정일: 2026-08-25
- 원칙: Cloud 리소스·IAM·metadata는 Terraform, VM 내부 상태 변화는 guest automation, 완료 판정은 `verify.sh`와 evidence가 소유한다.

## 요약

아래 표의 `감사 전 상태`와 `핵심 누락`은 발견 당시의 기록이다. 현재는 Phase 01·03 adapter를 추가했고 Phase 02·04·05·06의 guest·network·backup·maintenance 검증을 보완해 `tests/offline-phases-01-06.sh`를 통과했다. 실제 Google Cloud 재실행과 Extension 승인은 별도 완료 조건이다.

| Phase | 감사 전 상태 | 핵심 누락 | 올바른 반영 위치 |
|---|---|---|---|
| 01 | adapter 없음 | 버킷 2개, fixture, hash 왕복, 격리 profile, cleanup inventory | Terraform + 로컬 검증 |
| 02 | 리소스 존재 확인 | Jenkins HTTP, 내부 service stop/start, provenance 강제, 관리 포트 제한 | Terraform + guest 검증 |
| 03 | adapter 없음 | default VPC 조건부 경계, auto/custom topology, 실제 연결 matrix | Terraform + guest 검증 |
| 04 | 최종 리소스 존재 확인 | PGA 전 실패/후 성공, NAT 전 실패/후 성공, 실제 NAT log correlation | 단계별 Terraform plan + guest/log 검증 |
| 05 | VM 사양 일부 확인 | Linux/custom SSH와 guest 사양, Windows agent/RDP readiness, public RDP 제거 | Terraform + guest 검증 |
| 06 | 리소스 존재 확인 | disk UUID mount, JRE/app, checksum/EULA, TCP probe, backup/cron, maintenance cycle | Terraform + guest 검증 |

## Task coverage와 소유 계층

| Phase/Task | Terraform이 보장할 것 | 실행·검증이 보장할 것 | 감사 전 판정 |
|---|---|---|---|
| 01/1·3 | 비공개 버킷 2개, 고유 이름, 위치·클래스 | describe 결과가 plan과 일치 | 누락 |
| 01/2 | 해당 없음 | 활성 계정·프로젝트·도구 확인, UI는 manual boundary | 누락 |
| 01/4 | 작은 fixture 객체 | 업로드·다운로드 SHA-256 일치 | 누락 |
| 01/5 | 해당 없음 | 임시 HOME의 새 Bash에서 profile 재현 | 누락 |
| 01/6 | 소유 리소스 목록 | 객체·버킷 잔여 0 | 누락 |
| 02/1 | 공식 Click-to-Deploy 이미지와 생성 리소스 | 이미지 가용성·license/provenance를 실패 조건으로 검사 | 부분 |
| 02/2 | VM·disk·network·제한된 ingress | Jenkins HTTP readiness를 timeout 안에서 확인 | 부분 |
| 02/3 | IAP SSH 경로 | service active → stop 시 endpoint 실패 → start 후 성공 | 누락 |
| 02/4 | 해당 없음 | 구조화 evidence와 manual boundary | 부분 |
| 03/1 | 기존 default VPC를 소유하지 않음 | 전용 프로젝트가 아니면 삭제 거부, describe와 expected failure | 누락 |
| 03/2 | auto VPC·방화벽·2개 지역 VM | auto subnet/route 집합과 연결성 | 누락 |
| 03/3 | management/custom VPC·subnet·VM | NIC/CIDR/route 일치 | 누락 |
| 03/4 | 최소 source/tag 방화벽 | source/destination/address별 성공·expected failure matrix | 누락 |
| 03/5 | 해당 없음 | topology·matrix evidence | 누락 |
| 04/1 | 외부 IP 없는 VM, IAP SSH | SSH readiness | 부분 |
| 04/2 | PGA disabled baseline과 enabled stage | 동일 Storage 명령의 전 실패·후 성공 | 누락 |
| 04/3 | NAT disabled baseline과 enabled stage | 동일 일반 egress 명령의 전 실패·후 성공 | 누락 |
| 04/4 | NAT logging ALL | run marker와 실제 NAT log의 제한 polling | 누락 |
| 04/5 | 해당 없음 | 세 경로를 분리한 evidence | 누락 |
| 05/1 | Linux 사양·disk·NIC·최소 SA | serial readiness, SSH, guest OS | 부분 |
| 05/2 | Windows 사양·disk·제한된 RDP source | guest agent·TCP 3389 readiness, 비밀번호는 manual boundary | 부분 |
| 05/3 | custom CPU/memory·최소 SA | SSH와 guest CPU/memory | 부분 |
| 05/4 | 해당 없음 | 세 VM 비교 evidence | 부분 |
| 06/1 | VM·disk·bucket·최소 SA·metadata | guest startup 완료 | 부분 |
| 06/2 | 별도 data disk attach | filesystem·UUID·mount·fstab와 reboot 후 유지 | 누락 |
| 06/3 | 고정 artifact 변수와 명시적 EULA gate | checksum, JRE, systemd, process readiness | 누락 |
| 06/4 | 승인 CIDR의 25565만 허용 | 실제 외부 TCP probe | 누락 |
| 06/5 | 비공개 bucket과 최소 IAM | 즉시 backup·object hash·cron | 누락 |
| 06/6 | startup/shutdown metadata | graceful stop/start와 복구 | 누락 |
| 06/7 | 해당 없음 | 모든 evidence를 합친 결과 | 누락 |

## 공통 결함

1. plan만 확인한 Task를 `passed`로 기록한다. plan 단계는 반드시 `pending`이어야 한다.
2. plan의 action allowlist와 Phase별 최대 리소스 수가 강제되지 않는다.
3. apply·polling에 `GCP_MAX_APPLY_MINUTES`가 실제 적용되지 않는다.
4. apply 부분 실패 후 `cleanup_required` 전이와 소유 리소스 전체 inventory가 불완전하다.
5. manifest가 실제 Terraform 리소스를 빠뜨려 destroy 검증 범위가 축소된다.
6. mock schema 테스트가 실제 guest·network·backup 검증의 존재를 보장하지 않는다.

## 보완 순서

1. 공통 plan/action/resource/timeout guard를 모든 adapter에 적용한다.
2. Phase 01·03 adapter를 추가하되 default VPC 삭제와 public ingress를 자동화하지 않는다.
3. Phase 02·05의 ingress·service account를 최소화하고 guest readiness를 검증한다.
4. Phase 04를 baseline과 enabled의 두 저장 plan으로 나눠 전후 결과를 보존한다.
5. Phase 06에 명시적 artifact checksum·EULA gate와 guest lifecycle을 추가한다.
6. 각 Phase의 evidence가 없으면 `verified`로 전이하지 못하게 한다.

## 반영 결과

| 범위 | 로컬 반영 상태 | 남은 실제 증거 |
|---|---|---|
| Phase 01 | 버킷·fixture·hash 왕복·격리 profile·cleanup adapter 구현 | Cloud apply/verify/destroy와 Extension 승인 |
| Phase 02 | Marketplace provenance·Jenkins HTTP·service stop/start·IAP ingress 구현 | 개정 adapter Cloud 재검증 |
| Phase 03 | default VPC 보호·auto/custom topology·연결 matrix 구현 | 개정 adapter Cloud 재검증 |
| Phase 04 | PGA/NAT 전후 비교와 NAT log correlation 구현 | 개정 adapter Cloud 재검증 |
| Phase 05 | Linux/custom guest 사양과 Windows agent/RDP readiness 구현 | 개정 adapter Cloud 재검증 |
| Phase 06 | UUID mount·artifact checksum·앱/TCP·backup·maintenance 구현 | 개정 adapter Cloud 재검증 |

공통 plan/action/resource/timeout guard와 artifact 상태 전이도 적용했다. 이 표의 `구현`은 정적·offline 검증을 뜻하며 실제 Cloud 성공을 뜻하지 않는다.

## 완료 판정

이 문서는 누락 발견과 로컬 반영 기록이지 Cloud 완료 증거가 아니다. 각 행은 Terraform 정적 검사와 offline 계약을 통과했으며, 실제 Cloud canary와 Extension 독립 검토까지 끝나야 최종 `완료`가 된다.
