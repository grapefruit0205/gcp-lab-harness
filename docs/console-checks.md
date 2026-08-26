# Phase 완료 후 콘솔에서 확인하기

이 안내는 자신의 계정으로 저장소를 clone해 실습하는 사용자를 위한 것이다. 자동 검증의 `passed`, 사용자가 콘솔에서 확인한 결과, 최종 destroy 완료는 서로 다르다. **각 Phase 완료 보고에는 해당 Phase의 모든 Task에 대한 메뉴 경로·확인 대상·통과 기준·한계/보조 확인을 함께 제공한다.**

## 안내를 여는 방법

[Phase 01–15 목록](phases/README.md)에서 해당 문서를 열고 `Task별 콘솔 확인` 표를 읽는다. 또는 저장소 최상위의 Linux/Git Bash 터미널에서 다음을 실행한다. `09`를 해당 두 자리 Phase 번호로 바꾼다.

```bash
python3 scripts/console-checks.py --phase 09
```

이 명령은 로컬 Markdown만 읽는다. 로그인·Cloud 조회·apply·verify·destroy를 실행하지 않으며 성공 상태도 만들지 않는다. PowerShell에서는 설치된 Python에 맞게 `python` 명령을 사용해도 된다. Extension review 준비와 단일 모델 review 준비/완료 출력에도 같은 안내가 연결된다. 이 연결의 실제 Windows 실행은 별도 검증 대상이다.

## 콘솔에서 공통으로 확인할 것

1. [Google Cloud Console](https://console.cloud.google.com/)에 **자신의 계정**으로 로그인한다. 위쪽 프로젝트 선택기에서 이번 실행의 프로젝트를 선택한다. README나 과거 실행자의 프로젝트를 복사하지 않는다.
2. 이번 실행의 run ID를 확인하고 리소스 **이름**에서 검색한다. 라벨을 지원하는 리소스는 `harness=gcp-lab-harness`, `phase=NN`, `run=<RUN_ID>`도 대조한다. 모든 리소스가 같은 라벨 필터를 지원하지는 않는다. BigQuery dataset ID는 run의 하이픈이 밑줄로 바뀐다.
3. 메뉴명이 다르면 상단 검색에 `VM instances`, `Cloud SQL`, `Cloud Storage`, `VPC networks`, `IAM`, `Cloud NAT`, `Cloud Router`, `VPN`, `Load balancing`, `Monitoring`, `BigQuery`를 입력해 같은 서비스로 이동한다. 프로젝트·리전·시간 필터가 맞는지 먼저 확인한다.
4. 각 Phase 표의 통과 기준과 실제 값을 대조한다. **확인 작업에서는 생성·수정·역할 부여·비밀번호 재설정·부하 발생 버튼을 누르지 않는다.** 예상했던 객체가 없을 때는 실행 단계에서 이미 회수/삭제하도록 설계된 항목인지 먼저 본다.
5. 권한 오류·API 조회 오류·잘못된 필터 때문에 빈 목록이 나올 수 있다. 단순히 빈 화면이라고 삭제 완료로 결론 내리지 않는다. 허용된 관리자 계정의 조회와 정제된 destroy evidence를 함께 확인한다.

## 콘솔만으로 부족한 항목

- VM의 RUNNING은 WordPress/Minecraft/Jenkins나 DB 쿼리 성공을 뜻하지 않는다. 애플리케이션 화면·허용된 읽기 전용 guest 검사·기계 evidence를 추가로 확인한다.
- IAM의 **현재** 역할은 중간 단계의 허용→거부·역할 회수 이력을 입증하지 않는다. Phase 07은 검증 후 임시 역할을 회수하므로 단계별 정제 evidence와 현재 baseline을 함께 본다.
- Phase 08 CSEK 키/암호화 세대, Phase 09 HTTP probe는 검증 후 제거된다. 다시 공개하거나 비밀을 복구해서 재현하지 않는다.
- 로그/메트릭은 실행 시간과 리소스로 필터링한다. 그래프/로그가 없으면 데이터 지연·보존 기간·권한도 점검한다. 로컬 셸 지속성·Terraform 멱등성처럼 콘솔에 대응 화면이 없는 작업은 로컬 검증 기록으로 구분한다.

보조 증거는 해당 실행의 `artifacts/runs/<RUN_ID>/phase-NN/manifest.json`과 `evidence/` 아래 정제 JSON이다. JSON 필드는 Phase마다 다르므로 안내 표의 Task 번호와 실제 파일을 대조한다. 이 경로는 로컬 전용이며 GitHub clone에 실행 증거가 포함되지는 않는다. 비밀번호·토큰·Terraform state·원시 로그를 복사하거나 게시하지 않는다.

## destroy 전후의 보고

가능하면 리소스가 있는 검증 직후에 콘솔 확인법을 안내한다. 사용자가 바로 destroy를 요청하면 이를 지연시키거나 별도의 재생성을 하지 않는다. 삭제 후에는 다음과 같이 구분한다.

| 구분 | 보고할 내용 |
|---|---|
| 삭제 전 검증 | 실제 실행한 Task·성공/실패·증거 시각 |
| 현재 콘솔 확인 | 남아 있는 리소스 또는 해당 run 리소스 부재 |
| 보조 확인 | 콘솔로 입증할 수 없는 과거 전이/DB·네트워크 결과와 증거 경로 |
| 종료 정리 | 삭제된 대상·정확한 잔여·재시도 조건·다른 Phase 보존 여부 |

예를 들어 Phase 09에서는 SQL 인스턴스, VM2, 디스크2, 전용 방화벽/서비스 계정의 부재를 확인한다. VPC의 **Private services access/할당된 IP 범위/비공개 연결**에 해당 run 항목이 남으면 전체 cleanup은 미완료다. 공통 API가 활성 상태인 것과 run 리소스 잔여는 다르다. 삭제된 서비스 주소는 더 이상 접속 주소로 안내하지 않는다.

## 로컬 리허설 — 여기까지만 실행

문서/안내 기능을 확인하려는 독자는 저장소 최상위에서 아래만 실행하고 종료한다. 실제 실습을 재실행하지 않는다.

```bash
python3 scripts/console-checks.py --check-all
python3 scripts/console-checks.py --phase 09
python3 tests/test-console-checks.py
```

이 검사는 15개 문서와 원본 Task 번호의 누락·중복·빈 기준·보고 연결을 검사한다. Cloud 성공이나 실제 콘솔 클릭 전 과정 성공의 증거는 아니다.

## 메뉴 근거와 한계

2026-08-26에 원본 실습과 공식 메뉴 설명을 대조했다. 메뉴 언어/배치는 바뀔 수 있고 계정 권한에 따라 보이는 항목이 다르다. 각 Phase 표 아래의 공식 문서를 참고한다. 이 문서를 만들며 15개 실습을 다시 apply하거나 모든 콘솔 화면을 직접 조작하지 않았다.

VM 구성·상태 확인은 [VM 상세 문서](https://docs.cloud.google.com/compute/docs/instances/view-vm-details), 프로젝트의 현재 접근 권한은 [IAM 접근 보기](https://docs.cloud.google.com/iam/docs/granting-changing-revoking-access), SQL의 DB 목록은 [Cloud SQL 데이터베이스 관리](https://docs.cloud.google.com/sql/docs/mysql/create-manage-databases)를 따른다. NAT 로그의 부재를 통신 부재로 단정하지 않는 제한은 [NAT 로그 문서](https://docs.cloud.google.com/nat/docs/monitoring)에 명시돼 있다.
