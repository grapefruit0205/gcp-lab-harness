# Phase 06 — Task 하위 항목별 콘솔 확인

[공통 준비](../console-checks.md) · [Phase 요약](../phases/phase-06-working-vms.md)

확인 안내이며 실제 Cloud 성공 기록이 아닙니다. `<RUN_ID>`·`<PROJECT_ID>`는 본인의 실행 값입니다. 읽기 전용으로 확인하며 생성·편집 저장·삭제·비밀번호 재설정은 하지 않습니다. 현재 값과 과거 검증 증거를 구분합니다. 로컬 증거는 `artifacts/runs/<RUN_ID>/phase-06/evidence/phase-06-machine.json`입니다.

원문 `06.Working with Virtual Machines_KR.md`. 현 자동화는 **`/srv/minecraft` + systemd**이며 원문 `/home/minecraft` + screen 과 다르다. cron 은 **매일 02:15(guest 시간대)**로 원문 4 시간마다와 다르다. 백업은 tar.gz+sha256 이고 원문 world 폴더복사와 다르다.

## Task 1. VM 생성하기

### 고급 옵션으로 VM 정의하기

1. 화면 열기·값 대조: VM → `mc-server-<RUN_ID>` → e2-medium/Debian12 → 추가디스크 `minecraft-disk-<RUN_ID>`50GB pd-ssd → NIC tag minecraft-server → VPC IP 주소 `mc-ip-<RUN_ID>`가 해당 VM 에 연결된 예약외부 IP 인지 확인.
2. 판정·한계·보조 증거: 원문 defaultVPC 대신 `gcp-lab-p06-net-<RUN_ID>` 전용 VPC. SA/Storage 범위도 savedplan 과 대조; 실기구현값을 원문값과 혼동하지 않음.

## Task 2. 데이터 디스크 준비하기

### 디렉터리 생성 후 디스크 포맷 및 마운트하기

1. 화면 열기·값 대조: VM 추가디스크 연결을 확인 → 허용 SSH 에서 `findmnt /srv/minecraft`·`lsblk -f` 읽기 → ext4/같은 UUID 를 evidence `.disk_uuid_sha256` 및 `.checks.disk_uuid_mount_fstab`와 대조.
2. 판정·한계·보조 증거: 콘솔 attach 만으로 mount 입증불가. mkfs/mount/fstab 편집/재부팅 금지. 원문마운트경로와 다름.

## Task 3. 애플리케이션 설치 및 실행하기

### Java Runtime Environment(JRE)와 Minecraft 서버 설치하기

1. 화면 열기·값 대조: SSH 에서 `java -version` 및 `sha256sum /srv/minecraft/server.jar` 읽기 → savedartifact 와 `.jre_package_version`/`.artifact_sha256` 대조.
2. 판정·한계·보조 증거: 패키지재설치/외부 JAR 재다운로드 금지. 원문 default-jre 대신 고정 openjdk17 패키지버전.

### Minecraft 서버 초기화하기

1. 화면 열기·값 대조: SSH 에서 `test -f /srv/minecraft/world/level.dat`와 `rg '^eula=' /srv/minecraft/eula.txt` 읽기 → world 존재/eula=true 확인.
2. 판정·한계·보조 증거: 사용자 EULA 승인은 savedinputs 의 근거와 대조. 현재파일존재만으로 초기실패→동의의 원문전이를 수행했다고 쓰지 않음.

### Minecraft 서버를 시작할 가상 터미널(screen) 만들기

1. 화면 열기·값 대조: SSH 에서 `systemctl is-active minecraft.service`가 active 인지 확인 → `.checks.artifact_checksum_eula_systemd` 대조.
2. 판정·한계·보조 증거: screen 은 사용하지 않는다. `screen -ls`에 mcs 가 없어도 정상이며 systemd 동등경로라고 명시.

### screen에서 분리하고 SSH 세션 닫기

1. 화면 열기·값 대조: 서비스가 systemd 로관리됨을 확인한 뒤 SSH 창을 닫아도 된다는 구조를 읽는다. 기존 검증의 maintenance 재시작후 active/TCP 증거 확인.
2. 판정·한계·보조 증거: screen detach 키입력·새 screen 생성 불필요. 실제게임접속은 TCP 포트연결보다 강한검사이며 코드 TCP 검증을 protocol 성공으로 부풀리지 않음.

## Task 4. 클라이언트 트래픽 허용하기

### 방화벽 규칙 생성하기

1. 화면 열기·값 대조: VPC 방화벽 → `minecraft-rule-<RUN_ID>` → INGRESS/ALLOW/TCP25565/tag minecraft-server/source savedCIDR 확인 → 별도 `minecraft-iap-ssh-<RUN_ID>`는 IAP22 만 확인.
2. 판정·한계·보조 증거: 공개서버예외 0/0 은 게임 TCP25565 만. RDP/UDP/SSH 전체공개금지.

### 서버 가용성 확인하기

1. 화면 열기·값 대조: VPC → IP 주소 → mc-ip 의 현재 VM 연결 확인 → 같은 IP 의 25565 를 실제 Minecraft 클라이언트 또는 승인된상태조회 결과와 대조.
2. 판정·한계·보조 증거: 외부사이트 timeout 만으로 방화벽문제로단정하지 않음. VM RUNNING→systemdactive→listen→firewall 순으로 읽기확인. 자동화증거는 TCP handshake 뿐이며 protocol 버전 1.14.3/게임로그인까지 통과한 것은 아님.

## Task 5. 정기 백업 예약하기

### Cloud Storage 버킷 생성하기

1. 화면 열기·값 대조: CloudStorage → `gcp-lab-p06-backup-<RUN_ID>` → 권한 PAP enforced/균일액세스 → workloadSA 의 전용 bucket 권한확인.
2. 판정·한계·보조 증거: 원문 projectID-minecraft-backup 과 이름다름. 새백업생성하지 않음.

### 백업 스크립트 만들기

1. 화면 열기·값 대조: SSH 에서 `test -x /usr/local/sbin/minecraft-backup` 읽기 → script 가 현재 run 전용 bucket 을 대상으로 하는지 비밀없는경로만확인.
2. 판정·한계·보조 증거: 원문 `/home/minecraft/backup.sh`/screen save-all 방식과 다르다. 실행하면 새객체를만드므로 확인 작업에서 실행금지.

### 백업 스크립트 테스트 및 cron 작업 예약하기

1. 화면 열기·값 대조: Storage bucket → `backups/` → `minecraft-<UTC시각>.tar.gz`와 `.sha256` 객체두개 및 생성시각/크기확인 → SSH 에서 `/etc/cron.d/minecraft-backup` 읽기.
2. 판정·한계·보조 증거: 기대 cron `15 2 * * * root /usr/local/sbin/minecraft-backup`이며 원문 0 */4 아님. `.checks.backup_hash_and_recoverability`는 tar 읽기/hash 검사; 새 VM 복구실기아님.

## Task 6. 서버 유지보수하기

### SSH로 서버에 접속하여 중지하고 VM 종료하기

1. 화면 열기·값 대조: VM 현재상태와 정제 `.boot_count_before`/`.boot_count_after`(증가), `.checks.maintenance_recovery`를대조.
2. 판정·한계·보조 증거: 정상검증끝에는 RUNNING. 원문중지상태를맞추려고 Stop 버튼누르지 않음.

### 시작·종료 스크립트로 서버 유지보수 자동화하기

1. 화면 열기·값 대조: VM 상세 metadata 에서 startup-script/shutdown-script 가있음확인 → `.checks.shutdown_startup_hooks`와 동일 UUID/재부팅후서비스증거대조.
2. 판정·한계·보조 증거: 원문 startup-script-url/shutdown-script-url 대신 inline 고정스크립트. metadata 존재만으로실행완료판정금지.

## Task 7. Review

### 검토할 세부 항목

1. VM/disk/방화벽/backup 의같은 run 소유권과 위 7 개 checks 를대조. 이미 destroy 되었다면 월드·VM 을확인용재생성하지 않는다.
2. 위 화면별 확인 값과 로컬 정제 증거의 상태·실행 시각을 각각 비교합니다. 미수행·수동 경계를 통과로 바꾸지 않습니다. 삭제했다면 현재 목록 부재와 삭제 전 증거를 나눠 기록합니다.

## 출처·검증 범위

원문: [보존된 실습 06](../../references/google-cloud-labs-ko/labs/06.Working%20with%20Virtual%20Machines_KR.md). 2026-08-26 에 원문 하위 제목과 현재 코드의 대조를 수행했습니다(observed). 메뉴의 공식 설명은 Phase 요약의 근거 링크를 참고합니다. 실제 콘솔 클릭·Cloud 통합 성공은 별도 검증입니다.
