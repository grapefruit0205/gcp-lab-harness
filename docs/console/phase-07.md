# Phase 07 — Task 하위 항목별 콘솔 확인

[공통 준비](../console-checks.md) · [Phase 요약](../phases/phase-07-iam.md)

확인 안내이며 실제 Cloud 성공 기록이 아닙니다. `<RUN_ID>`·`<PROJECT_ID>`는 본인의 실행 값입니다. 읽기 전용으로 확인하며 생성·편집 저장·삭제·비밀번호 재설정은 하지 않습니다. 현재 값과 과거 검증 증거를 구분합니다. 로컬 증거는 `artifacts/runs/<RUN_ID>/phase-07/evidence/phase-07-machine.json`입니다.

원문 `07.Exploring IAM_KR.md`의 제목을 유지하되 D-026 사용자 Notion 본문이우선. 가상교육도메인/Username 공통비밀번호를사용하지 않는다. A 관리자/B 별도실사용자, **VM 생성 actor B**, SSH A. 최종검증은 임시역할을회수하므로중간권한이콘솔에없어도정상.

## Task 1. 두 사용자를 위한 설정하기

### 첫 번째 사용자로 Cloud console에 로그인하기

1. 화면 열기·값 대조: 일반브라우저/전용프로필 A → 우측계정아이콘 → 본인관리자계정확인 → 상단프로젝트선택이승인프로젝트인지확인.
2. 판정·한계·보조 증거: Qwiklabs 계정발급필요없음. OAuthidentity 검증은 tasks.task-1 와 user-identities 정제증거;토큰공유금지.

### 두 번째 사용자로 Cloud console에 로그인하기

1. 화면 열기·값 대조: 별도브라우저프로필/시크릿 B → 우측계정메뉴에서 A 와다른 B 확인.
2. 판정·한계·보조 증거: 같은시크릿창의탭만추가하면세션공유가될수있으므로분리프로필사용. 로그아웃이 B 계정삭제를유발한다는 Qwiklabs 규칙은개인계정에적용안됨.

## Task 2. IAM 콘솔 살펴보기

### IAM 콘솔로 이동하여 역할 살펴보기

1. 화면 열기·값 대조: A 로 IAM 및관리자 → IAM → B 검색; 역할설명은 IAM 및관리자 → 역할에서 Viewer/Storage Object Viewer 등의권한목록읽기.
2. 판정·한계·보조 증거: 최종 B 임시 Viewer 회수후 B 가 IAM 못읽는게정상. 과거조회허용/수정거부는 task-2 evidence; Grant Access/연필저장금지.

## Task 3. 액세스 테스트를 위한 리소스 준비하기

### 버킷을 생성하고 샘플 파일 업로드하기

1. 화면 열기·값 대조: A 로 CloudStorage → `gcp-lab-p07-<RUN_ID>` → 구성 US/Standard·권한 PAP/UBLA → 객체 sample.txt 내용 `Phase 07 IAM fixture <RUN_ID>`확인.
2. 판정·한계·보조 증거: 객체이름/내용만읽고업로드/이름변경하지않음.

### 프로젝트 Viewer 액세스 확인하기

1. 화면 열기·값 대조: task-3 의 B Viewer 단계 project/bucket 조회허용결과와 A 가확인한같은 bucket 명을대조.
2. 판정·한계·보조 증거: 완료후 B 조회가막힌것을실패로보지않음. 현재콘솔만으로과거 Viewer 조회성공입증불가.

## Task 4. 프로젝트 액세스 제거하기

### Username 2의 Project Viewer 역할 제거하기

1. 화면 열기·값 대조: A IAM 목록에서 B 의임시 roles/viewer 가없는지확인하고원래 baseline 권한과대조.
2. 판정·한계·보조 증거: 계정 B 자체를삭제하는작업아님. 타권한/상속권한이있다면임의회수금지.

### Username 2가 액세스 권한을 잃었는지 확인하기

1. 화면 열기·값 대조: tasks.task-4 와 revoked-project/revoked-buckets/revoked-storage-read 의거부결과를확인; A 에겐 sample.txt 가존재했는지대조.
2. 판정·한계·보조 증거: 인증만료/네트워크실패/객체삭제는권한거부증거가아님. 완료후 B 프로젝트화면거부는현재상태만입증.

## Task 5. 스토리지 액세스 추가하기

### 스토리지 권한 추가하기

1. 화면 열기·값 대조: IAM 의프로젝트역할설명에서 roles/storage.objectViewer 를찾아 scope 확인; task-5 의임시 project-level 권한단계증거읽기.
2. 판정·한계·보조 증거: 최종 rollback 후이역할없어야함. 특정 bucket 전용역할로설명하면원문/자동화와불일치;재부여금지.

### Username 2가 스토리지 액세스 권한을 갖는지 확인하기

1. 화면 열기·값 대조: task-5 에서 B 의 storage-list/read 허용·write/Compute/IAM 변경거부결과와같은 sample/objecthash 대조.
2. 판정·한계·보조 증거: ObjectViewer 는버킷목록 UI 전체조회권한과다름. 자동화는 B OAuthAPI 등가경로이며브라우저다운로드성공주장금지.

## Task 6. Service Account User 설정하기

### 서비스 계정 생성하기

1. 화면 열기·값 대조: A 로 IAM 및관리자 → 서비스계정 → 표시이름 `Phase 07 read-bucket-objects <RUN_ID>` → 이메일/고유 ID 확인 → IAM 에서전용 workload 의 ObjectViewer 확인.
2. 판정·한계·보조 증거: 서비스계정키를만들거나키목록을다운로드하지않음. 최종 workload 는 Viewer 복구상태.

### 서비스 계정에 사용자 추가하기

1. 화면 열기·값 대조: workloadSA 상세 → 권한/액세스권한을가진주구성원 → B 의임시 Service Account User 가회수된현재상태와 task-6 actAs 부여증거대조.
2. 판정·한계·보조 증거: 부여범위는이 SA 하나,project-wide 아님. altostrat.com 도메인부여하지않음.

### Compute Engine 액세스 권한 부여하기

1. 화면 열기·값 대조: A IAM → B 검색 → 임시 roles/compute.instanceAdmin.v1 회수확인 → task-6 부여 scope 와최종 task-8baseline 대조.
2. 판정·한계·보조 증거: 중간역할은프로젝트기존 VM 에도영향,runVM 에만권한이한정된게아님.현재없다고실습누락판정하지않음.

### Service Account User로 VM 생성하기

1. 화면 열기·값 대조: VM → `p07-probe-<RUN_ID>` → savedzone/e2-micro/Debian12/privateNIC/workloadSA/cloud-platformscope 확인 → 로그탐색기에서실행시각 VM 생성 AdminActivity actor 가 B 인지읽기.
2. 판정·한계·보조 증거: B 생성 operation 증거·actor 확인은필수. A SSH 성공을 B 생성증거로바꾸지않음. scope 가 full 이어도 SA IAM 이자동확대되는것아님.

## Task 7. Service Account User 역할 살펴보기

### Service Account User 사용하기

1. 화면 열기·값 대조: task-7 의 metadataSA identity → Compute 목록거부/read 허용/write 거부 → Creator 전환후 write 허용/read 거부를순서대로읽고 Storage sample2.txt 내용을 A 로확인.
2. 판정·한계·보조 증거: 현 IAMViewer 복구만으로전이를입증못함. B 사용자권한과 VM SA 권한구분,확인용재전환/토큰출력금지. Notion 추가요구인 Creator 의기존파일읽기거부도빠뜨리지않음.

## Task 8. Review

### 검토할 세부 항목

1. A IAM/SA 권한에서 B Viewer/ObjectViewer/Compute/actAs 가모두회수되고 workloadViewer·관리자 baseline 이보존됐는지 tasks.task-8 과세 baseline 정제근거를대조. VM/bucket 은 destroy 전남는 것이 정상이며 QwiklabsEndLab 없는개인계정에서자동계정삭제를기대하지않는다.
2. 위 화면별 확인 값과 로컬 정제 증거의 상태·실행 시각을 각각 비교합니다. 미수행·수동 경계를 통과로 바꾸지 않습니다. 삭제했다면 현재 목록 부재와 삭제 전 증거를 나눠 기록합니다.

## 출처·검증 범위

원문: [보존된 실습 07](../../references/google-cloud-labs-ko/labs/07.Exploring%20IAM_KR.md). 2026-08-26 에 원문 하위 제목과 현재 코드의 대조를 수행했습니다(observed). 메뉴의 공식 설명은 Phase 요약의 근거 링크를 참고합니다. 실제 콘솔 클릭·Cloud 통합 성공은 별도 검증입니다.
