# Phase 08 — Task 하위 항목별 콘솔 확인

[공통 준비](../console-checks.md) · [Phase 요약](../phases/phase-08-cloud-storage.md)

확인 안내이며 실제 Cloud 성공 기록이 아닙니다. `<RUN_ID>`·`<PROJECT_ID>`는 본인의 실행 값입니다. 읽기 전용으로 확인하며 생성·편집 저장·삭제·비밀번호 재설정은 하지 않습니다. 현재 값과 과거 검증 증거를 구분합니다. 로컬 증거는 `artifacts/runs/<RUN_ID>/phase-08/evidence/phase-08-machine.json`입니다.

원문 `08.Cloud Storage_KR.md`. bucket `gcp-lab-p08-<RUN_ID>`. 자동화는자체 fixture, 메모리 CSEK/API, lifecycle/versioning 처음부터설정. 검증끝엔임시공개회수·setup2/3 모든암호화세대삭제·키폐기. **이상태를과거원문중간화면과혼동하면안됨.**

## Task 1. 준비하기

### Cloud Storage 버킷 생성하기

1. 화면 열기·값 대조: Storage → runbucket → 구성의 savedregion·Standard → 권한에서 Fine-grained(균일액세스미사용) 확인 → 보호에서 softdelete0·versioning 상태확인.
2. 판정·한계·보조 증거: PAP 는조직정책과함께판정;실습위해조직정책완화금지.

### CURL로 샘플 파일을 다운로드하고 사본 2개 만들기

1. 화면 열기·값 대조: bucket 객체 setup.html 상세와정제 fixture_sha256 을로컬 phases/08/fixture.html 과대조.
2. 판정·한계·보조 증거: Hadoop 공개 HTML 이아닌자체고정 fixture. setup2/3 은최종삭제되므로없어도정상;원문다운로드/로컬 cp 실행주장금지.

## Task 2. 접근 제어 목록(ACLs)

### 버킷으로 파일을 복사하고 접근 제어 목록 구성하기

1. 화면 열기·값 대조: 객체 setup.html → 권한 → allUsers READER 가없는최종상태확인 → task-2/private→임시 public→회수증거를읽는다.
2. 판정·한계·보조 증거: 버킷 IAM 과객체 ACL 을혼동하지않음. `public_acl=policy-prevented`이면공개성공단계미수행.

### Cloud Console에서 파일 확인하기

1. 화면 열기·값 대조: setup.html 행의공개액세스표시와객체권한에서현재비공개확인.
2. 판정·한계·보조 증거: 원문의 Public link 는중간상태다. 검증완료후 Public link 를다시보려고공개권한추가금지.

### 로컬 파일을 삭제하고 Cloud Storage에서 다시 복사하기

1. 화면 열기·값 대조: task-2 의인증읽기/익명읽기와 fixturehash 왕복결과를대조.
2. 판정·한계·보조 증거: 콘솔은로컬삭제·재다운로드이력을보이지않음. 파일을삭제하거나기존파일에덮어쓰기하지않는다.

## Task 3. 고객 제공 암호화 키(CSEK)

### CSEK 키 생성하기

1. 화면 열기·값 대조: task-3 의키값없는 AES256 metadata/복호화 hash 검증결과확인.
2. 판정·한계·보조 증거: 실제키는메모리에서생성후폐기;콘솔에키를입력/복원/출력하지않음.

### gcloud storage 키 저장소 구성하기

1. 화면 열기·값 대조: task-3 의 API 등가구현설명과전역 key_store_path 미사용경계를확인한다.
2. 판정·한계·보조 증거: 자동화는 YAML 키저장소를만들지않음. 본인 gcloud 설정을바꾸거나새키파일을만들지않는다.

### 나머지 setup 파일 업로드(암호화)하고 Cloud Console에서 확인하기

1. 화면 열기·값 대조: 버킷객체목록을이름 setup2.html/setup3.html 로필터 → 모든버전보기에서도없고`.encrypted_generations_remaining=0`인지대조.
2. 판정·한계·보조 증거: customer-encrypted 중간화면은현재없음. task-3 의 metadata 검증을과거근거로사용.

### 로컬 파일 삭제 후 새 파일을 복사하고 암호화 확인하기

1. 화면 열기·값 대조: task-3 의두객체최초복호화 hash 가 fixture 와일치한기록읽기.
2. 판정·한계·보조 증거: 키/객체가제거됐으므로콘솔로재다운로드불가가정상. 키없음으로생기는실패를현재오류로오해하지않음.

## Task 4. CSEK 키 순환하기

### 새 CSEK 키 생성하고 키 저장소 갱신하기

1. 화면 열기·값 대조: task-4 에서서로 다른키두개로검증됐다는고정검사항목확인.
2. 판정·한계·보조 증거: 키내용/키저장소는콘솔대상아님. 이전키를복원하려하지않음.

### 파일 1의 키를 다시 쓰고 기존 복호화 키를 잠시 제거하기

1. 화면 열기·값 대조: task-4 의 setup2generation 고정 rewrite 완료/신규 generation·신키허용/구키거부기록대조.
2. 판정·한계·보조 증거: 객체이름존재만으로키회전입증불가;전역키설정은자동화가변경하지않음.

### setup2와 setup3 다운로드하기

1. 화면 열기·값 대조: task-4 의행렬: setup2 신키성공·구키거부, setup3 구키성공·신키거부를각각확인.
2. 판정·한계·보조 증거: 일반 400 만으로틀린키거부판정하지않으며올바른키대조성공도필요. 최종현재객체로재시험하지않음.

### setup3의 키도 순환하고 구성 정리하기

1. 화면 열기·값 대조: task-4 에서 setup3 신키 rewrite/성공과전체암호화세대정리확인 → 버킷모든버전에서 setup2/3 부재대조.
2. 판정·한계·보조 증거: 원문키보존방식과달리일회성데이터를삭제후키폐기. 운영데이터키폐기절차로일반화금지.

## Task 5. 라이프사이클 관리 사용 설정하기

### 버킷의 현재 라이프사이클 정책 확인하기

1. 화면 열기·값 대조: bucket → 수명주기 → 현재규칙목록열기 → Delete/age31 있음확인.
2. 판정·한계·보조 증거: 자동화는처음부터규칙설정했으므로원문의‘처음엔없음’화면을기대하지않음.

### JSON 라이프사이클 정책 파일 생성하기

1. 화면 열기·값 대조: 같은수명주기규칙상세에서 action Delete·condition Age31 일을읽고 Terraform 정책과대조.
2. 판정·한계·보조 증거: 자동화에는별도 life.json 생성필요없음. 로컬파일있음은 Cloud 정책반영증거아님.

### 정책 설정 및 확인하기

1. 화면 열기·값 대조: 수명주기화면의 31 일규칙과 task-5 readback 결과일치확인.
2. 판정·한계·보조 증거: 실제 31 일후객체삭제를검증한것아님.확인 목적으로 age 낮추지않음.

## Task 6. 버전 관리 사용 설정하기

### 버킷의 버전 관리 상태를 확인하고 버전 관리 사용 설정하기

1. 화면 열기·값 대조: bucket → 보호/구성 → Object Versioning Enabled 확인 → 객체 setup.html → 버전기록열기.
2. 판정·한계·보조 증거: softdelete 와다름. 자동화는처음부터 versioningon 이며 30 초전파대기를거친증거사용;설정토글금지.

### 버킷에서 샘플 파일의 여러 버전 만들기

1. 화면 열기·값 대조: setup.html 버전기록에서세 generation 의크기/생성시각확인: 최초가크고 5 줄줄인세대,또 5 줄줄인최신세대순으로작아야함.
2. 판정·한계·보조 증거: 버전생성을위해현재파일수정/업로드하지않는다. 원문줄삭제동작의로컬과정은콘솔에서보이지않음.

### 파일의 모든 버전 나열하기

1. 화면 열기·값 대조: 객체의 Live/Noncurrent 버전을모두표시 → generation3 개와 `.versions.count=3`, `.versions.original_generation`대조.
2. 판정·한계·보조 증거: UI 정렬첫줄이원본이라는가정금지. snapshot 후새변경이있다면현재세대수와검증당시수구분.

### 가장 오래된 원본 버전의 파일을 다운로드하고 복구 확인하기

1. 화면 열기·값 대조: 저장 original_generation 의크기와최신크기를대조하고`.versions.recovered_sha256`가`.fixture_sha256`와같은지읽기.
2. 판정·한계·보조 증거: recovered.txt 는로컬복구파일로 bucket 에없어도정상.콘솔 Restore 버튼은 live 객체를변경하므로누르지않음.

## Task 7. 디렉터리를 버킷과 동기화하기

### 중첩 디렉터리를 만들고 버킷과 동기화하기

1. 화면 열기·값 대조: bucket 객체 → firstlevel → setup.html 확인 → secondlevel → setup.html 확인.
2. 판정·한계·보조 증거: expectedset 는 `firstlevel/setup.html`, `firstlevel/secondlevel/setup.html`정확 2 개. 폴더는객체 prefix 표현이며클라우드파일시스템디렉터리생성증거와구분.

### 결과 확인하기

1. 화면 열기·값 대조: 두객체상세에서경로·크기확인 → `.sync_sha256`두키/hash 가현재 fixture 최신내용과일치한정제근거대조.
2. 판정·한계·보조 증거: 확인 작업에서 rsync 재실행금지. 내용무결성은크기만으로판정불가.

## Task 8. Review

### 검토할 세부 항목

1. CSEK 생성/회전, ACL private/public, 31 일 Delete, softdelete 와 versioning 구분/원본복구, 재귀 sync 의다섯범주를 task1–7 및`.lab_completion.public_acl_exercised`와대조. `.lab_completion.complete=false`/destroy_pending 은 machine 검증성공과전체종료가다름을뜻한다.
2. 위 화면별 확인 값과 로컬 정제 증거의 상태·실행 시각을 각각 비교합니다. 미수행·수동 경계를 통과로 바꾸지 않습니다. 삭제했다면 현재 목록 부재와 삭제 전 증거를 나눠 기록합니다.

## 출처·검증 범위

원문: [보존된 실습 08](../../references/google-cloud-labs-ko/labs/08.Cloud%20Storage_KR.md). 2026-08-26 에 원문 하위 제목과 현재 코드의 대조를 수행했습니다(observed). 메뉴의 공식 설명은 Phase 요약의 근거 링크를 참고합니다. 실제 콘솔 클릭·Cloud 통합 성공은 별도 검증입니다.
