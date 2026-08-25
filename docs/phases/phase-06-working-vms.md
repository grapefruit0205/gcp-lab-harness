# Phase 06 — 가상 머신 운용

- 원본: `references/google-cloud-labs-ko/labs/06.Working with Virtual Machines_KR.md`
- 비용 위험: 중간
- 주요 서비스: Compute Engine, Persistent Disk, Cloud Storage, firewall, guest automation

## 목적

VM과 데이터 disk를 준비하고 애플리케이션을 설치·실행하며 client traffic, 정기 backup, 시작·종료 유지보수를 실제 guest 동작으로 검증한다.

## 범위와 원본 매핑

| 원본 Task | 분류 | 자동화·증거 |
|---|---|---|
| Task 1. VM 생성하기 | automated | 고급 VM 옵션과 metadata·service account describe |
| Task 2. 데이터 디스크 준비하기 | automated | attach·format·mount·fstab·재부팅 후 mount 유지 |
| Task 3. 애플리케이션 설치 및 실행하기 | automated | JRE·Minecraft artifact·EULA·service/process readiness |
| Task 4. 클라이언트 트래픽 허용하기 | automated | 제한된 firewall와 TCP application probe |
| Task 5. 정기 백업 예약하기 | automated | bucket·backup script·cron·객체 hash/세대 확인 |
| Task 6. 서버 유지보수하기 | automated | graceful stop, VM stop/start, startup/shutdown script evidence |
| Task 7. Review | cli-equivalent | disk·app·network·backup·maintenance 결과 검토 |

## 구현 작업

1. image·disk·외부 artifact URL과 checksum·라이선스 조건을 preflight한다.
2. VM과 별도 disk를 plan하고 고유 UUID 기반 mount 구성을 만든다.
3. 버전이 고정된 JRE와 서버 artifact를 설치하고 systemd 또는 동등한 관리 단위로 실행한다.
4. 승인된 source의 application port만 열고 외부 client probe를 수행한다.
5. backup script를 즉시 시험한 뒤 cron을 등록하고 guest stop/start hook을 검증한다.

## 실행 계약

Command Code `cmd`는 모델 관련 인수를 받지 않고 현재 계정 설정으로 guest 작업까지 오케스트레이션한다. 외부 artifact의 checksum이 달라지면 실행을 중단한다. machine verification 뒤 Extension 검토를 위해 리소스를 일시 유지한다.

## 검증 게이트

- disk filesystem·UUID·mountpoint가 재부팅 전후 일치한다.
- server process와 application TCP probe가 실제로 성공한다.
- backup 객체가 생성되고 원본과 hash 또는 복구 가능한 내용이 일치한다.
- maintenance cycle 후 server와 mount가 정상 복구된다.
- Extension이 Compute/Storage 조회와 guest evidence를 검토한 뒤 사용자가 승인한다.

## 안전·비용 가드레일

- 외부 artifact는 버전·checksum을 고정하고 임의 스크립트를 pipe로 실행하지 않는다.
- EULA 동의가 필요한 경우 명시적 configuration과 근거를 남긴다.
- firewall source, VM 크기, disk 크기, 실행 시간을 제한한다.
- bucket, VM, boot/data disk, firewall을 manifest 소유권에 따라 정리한다.

## 완료 조건

- Task 1–7 coverage와 disk·app·traffic·backup·maintenance 증거가 모두 있다.
- Extension 검토와 사용자 승인 hash가 유효하다.
- cleanup 후 VM·disk·bucket·firewall 잔여 리소스가 0이다.

## Command Code·Extension handoff 지시

Command Code는 SSH 명령 성공만으로 앱 준비를 판단하지 않고 외부 client probe와 backup 복구성을 검사한다. Extension은 실행 명령, artifact provenance, public exposure와 cleanup 범위를 read-only로 검토한다.

## Git 종료 조건

`Phase 06: 가상 머신 운용 자동화 및 검증 완료` 커밋·push가 remote에서 확인되어야 Phase 07이 시작된다.
