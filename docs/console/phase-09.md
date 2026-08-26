# Phase 09 — Task 하위 항목별 콘솔 확인

[공통 준비](../console-checks.md) · [Phase 요약](../phases/phase-09-cloud-sql.md)

확인 안내이며 실제 Cloud 성공 기록이 아닙니다. `<RUN_ID>`·`<PROJECT_ID>`는 본인의 실행 값입니다. 읽기 전용으로 확인하며 생성·편집 저장·삭제·비밀번호 재설정은 하지 않습니다. 현재 값과 과거 검증 증거를 구분합니다. 로컬 증거는 `artifacts/runs/<RUN_ID>/phase-09/evidence/phase-09-machine.json`입니다.

원문 `09.Implementing Cloud SQL_KR.md`의 절차 범위는 Task 1: 1–17번, Task 2: 1–9번, Task 3: 1–12번, Task 4: 1–8번, Task 5: 1–10번입니다. 하위 제목이 없는 Task도 번호 구간별로 나누어 확인합니다.

## Task 1. Cloud SQL 데이터베이스 생성하기

### 1–4: SQL 종류·에디션·이름·리전·버전

1. 화면 열기·값 대조: SQL → 인스턴스 → `wordpress-db-<RUN_ID>` → 개요에서정상상태/MySQL8.0/Enterprise/savedregion 확인.
2. 판정·한계·보조 증거: root 비밀번호를출력/재설정하지않음.삭제후목록부재와삭제전 task-1 증거를구분.

### 5–10: 머신·스토리지

1. 화면 열기·값 대조: SQL 상세 → 구성/개요 → `db-custom-1-3840`, 1vCPU·3.75GiB,10GB SSD 확인.
2. 판정·한계·보조 증거: 자동백업/자동증설/HA 는개인실습승인값기준. 성능슬라이더를조작/저장하지않고운영권장설정으로일반화하지않음.

### 11–17: Public/Private IP·PSA

1. 화면 열기·값 대조: SQL → 연결 → 네트워킹에서 public/private 주소둘다확인 → private network `p09-net-<RUN_ID>` → VPC Private services access 의할당범위`p09-psa-<RUN_ID>`/서비스연결확인.
2. 판정·한계·보조 증거: 원문 defaultVPC 아닌전용 VPC. AuthProxypublic 경로는 VM 외부 IP authorizednetworks 등록불필요. 삭제후 PSA 만남아도 SQL 서비스생존은아님.

## Task 2. 두 가상 머신에 WordPress 설치하기

### 1–3: VM2·Apache/PHP

1. 화면 열기·값 대조: Compute → `wordpress-proxy-<RUN_ID>` 및 `wordpress-private-<RUN_ID>` → Debian12/RUNNING/NIC 확인 → 허용 SSH 에서`systemctl is-active apache2`읽기.
2. 판정·한계·보조 증거: VM RUNNING≠Apache 준비. apt 설치/서비스재시작하지않음.

### 4–5: WordPress파일·권한

1. 화면 열기·값 대조: 삭제전 guest-install-proxy/private 정제증거에서설치단계 pass 와고정 artifact 버전/hash 를읽는다. 살아있는 VM 에서읽을때도 wp-config.php 전체출력금지.
2. 판정·한계·보조 증거: 자동화는 latest 아닌고정 artifact. 파일내용전체에 DB 비밀이있을수있으므로권한/secret 을콘솔스크린샷으로게시하지않음.

### 6–9: Apache기동·로컬HTTP·두외부화면

1. 화면 열기·값 대조: VM2 의현재 externalIP 를각각복사하여허용 client/32 에서`http://주소/`열기→WordPress 정상본문확인;삭제후 URL 안내금지.
2. 판정·한계·보조 증거: 완료후 setup-config.php 설치화면이아닌정상블로그가맞음. HTTP200 만으로 SQL 읽기입증불가.

## Task 3. 가상 머신에 프록시 구성하기

### 사전조건: API·Cloud SQL Client

1. 화면 열기·값 대조: API 및서비스 → 사용설정 API 에 CloudSQLAdmin 확인 → ProxyVM 연결 SA 를 IAM 에서검색 → roles/cloudsql.client 가전용 SA 에있었는지대조.
2. 판정·한계·보조 증거: API/역할을확인용새로부여하지않음. 현재 destroy 후전용 SA/IAM 부재정상.

### 1–3: Proxy v2설치

1. 화면 열기·값 대조: ProxyVM 기존허용 SSH 에서`cloud-sql-proxy --version`에준하는설치 binary 버전조회또는정제 artifact 증거를확인한다.
2. 판정·한계·보조 증거: 실제 binary 경로는 guest 설치코드와대조해사용. 임의 download/chmod 재실행금지.

### 4–8: SQL정상·connection name·wordpress DB

1. 화면 열기·값 대조: SQL 개요에서 connection name `project:region:instance`읽기 → 데이터베이스탭에서 wordpress 존재확인.
2. 판정·한계·보조 증거: DB 목록만으로 root 의 CREATE/SELECT 권한/WordPress 테이블존재입증불가. 사용자탭 root 존재와실제 SQLtask 증거를같이봐야함.

### 9–12: Proxy localhost실행

1. 화면 열기·값 대조: ProxyVM 기존 SSH 에서`systemctl is-active cloud-sql-proxy`active 확인 → 읽기전용포트목록에서 127.0.0.1:3306 확인 → task-3 의 connection name/public-default 근거대조.
2. 판정·한계·보조 증거: Proxy 는새네트워크경로를만들지않음. 프로세스존재만으로 SQL 로그인성공아님. argv/설정의비밀유출주의.

## Task 4. 애플리케이션을 Cloud SQL 인스턴스에 연결하기

### 1–4: Proxy프런트엔드·DB_HOST

1. 화면 열기·값 대조: ProxyVM externalIP 의정상 WordPress 본문과 task-4 의 DBnamewordpress/DB_HOST127.0.0.1 계약대조.
2. 판정·한계·보조 증거: 이미설치된화면에서 Let'sGo/설치버튼을다시누르지않음. root 비밀번호확인요구금지.

### 5–8: 설치·SQL쓰기·블로그

1. 화면 열기·값 대조: task-4 의 Proxy 경유 harness_probe marker 쓰기와 HTTP DB-backed 읽기결과를읽어동일 marker 대조.
2. 판정·한계·보조 증거: 검사후 probePHP 는제거된다. 과거 probeURL404 는지금 WordPress 실패의증거아님.

## Task 5. 내부 IP를 통해 Cloud SQL에 연결하기

### 1–4: SQLprivateIP·VM네트워크

1. 화면 열기·값 대조: SQL 연결의 privateIP 와 PrivateVM NIC 의전용 VPC 를대조하고 PSA 연결/라우트를확인.
2. 판정·한계·보조 증거: 프런트엔드 publicIP 와 DBprivateIP 는다른주소. 같은리전은권장이며같은리전만으로연결보장아님.

### 5–10: direct DB_HOST·기존설치·블로그

1. 화면 열기·값 대조: PrivateVM http 홈페이지에서같은 WordPress 사이트확인 → task-5 의 DB_HOST=SQLprivateIP/direct SQL 과동일 marker 읽기결과대조.
2. 판정·한계·보조 증거: 원문 AlreadyInstalled 화면을재현하려고설치재실행하지않음. private 직접연결자체가 IAM/TLS 자동보안은아님.

## Task 6. Review

### Review(298): 두데이터경로·정리

1. 화면 열기·값 대조: phase-09-machine tasks1–6/guest 두경로 증거를 읽습니다. **리소스 유지 중**이면 SQL/VM 의 현재 정상 상태를 위 Task 기준으로 확인합니다. **명시적 destroy 후**라면 SQL/VM/디스크/전용 SA/방화벽 부재와 VPC Private services access 의 연결/할당범위/VPC 잔여를 각각 확인합니다.
2. 판정·한계·보조 증거: 본인 run manifest 의 현재 상태가 기준입니다. destroy 후 PSA 가 남은 경우에만 cleanup_required 로 보고하며, 삭제 전 pass 와 구분합니다. 보존 중인 정상 run 에 부재/cleanup_required 를 요구하지 않습니다. 직접 peering 삭제/state 제거는 하지 않습니다.

## 출처·검증 범위

원문: [보존된 실습 09](../../references/google-cloud-labs-ko/labs/09.Implementing%20Cloud%20SQL_KR.md). 2026-08-26 에 원문 하위 제목과 현재 코드의 대조를 수행했습니다(observed). 메뉴의 공식 설명은 Phase 요약의 근거 링크를 참고합니다. 실제 콘솔 클릭·Cloud 통합 성공은 별도 검증입니다.
