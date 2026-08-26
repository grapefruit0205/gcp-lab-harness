# Phase 08 — Cloud Storage

- 원본: `references/google-cloud-labs-ko/labs/08.Cloud Storage_KR.md`
- 상태: 구현·오프라인 검증 및 수정본의 실제 Cloud apply·Task 1–8 machine 검증 통과(2026-08-26, 성공 n=1). 첫 실패 run 정리는 완료했으며 성공 run의 최종 destroy는 대기 중이다.
- 대상: 저장소를 clone한 사용자. Linux Bash 또는 Windows PowerShell의 Git Bash 호환층 사용.
- 비용 위험: 중간. bucket·객체·API 사용 비용이 발생할 수 있다.

## 목적

원문의 ACL, CSEK, 키 순환, 31일 lifecycle, 객체 버전 복구, 재귀 동기화를 실행하고 데이터 hash까지 확인한다. 이전 Phase 리소스와 Phase 07의 두 사용자 설정은 필요하지 않다. 본인 계정 하나를 사용한다.

## 범위와 원본 매핑

| 원본 Task | 분류 | 자동화·증거 |
|---|---|---|
| Task 1. 준비하기 | cli-equivalent | 설정 리전의 전용 bucket, 자체 고정 HTML fixture와 SHA-256 |
| Task 2. 접근 제어 목록(ACLs) | automated | private ACL·인증 읽기·익명 거부, 임시 allUsers READER·익명 hash·즉시 회수 |
| Task 3. 고객 제공 암호화 키(CSEK) | cli-equivalent | 메모리의 키로 setup2/3 업로드, 암호화 metadata·복호화 hash |
| Task 4. CSEK 키 순환하기 | cli-equivalent | generation 고정 rewrite, setup2 신키 성공/구키 거부와 setup3 구키 성공/신키 거부 후 교체 |
| Task 5. 라이프사이클 관리 사용 설정하기 | cli-equivalent | Terraform의 31일 Delete 정책과 Storage API readback |
| Task 6. 버전 관리 사용 설정하기 | automated | 30초 대기, 원본·5줄씩 줄인 2세대, 3개 generation/크기 대조·원본 로컬 복구 hash |
| Task 7. 디렉터리를 버킷과 동기화하기 | automated | gcloud storage rsync --recursive, 2개 객체 집합·각 다운로드 hash |
| Task 8. Review | cli-equivalent | 구조화 evidence로 기능·정책 경계 검토, 최종 destroy 확인 |

### 원문과 자동화의 차이

원문은 Hadoop 공개 HTML을 내려받지만 자동화는 저장소의 공개 가능한 `phases/08/fixture.html`을 사용한다. 외부 문서 변경이나 연결 실패가 실습 데이터에 영향을 주지 않도록 fixture를 실행 코드 hash와 함께 승인에 묶었다. 외부 HTML 다운로드 자체를 재현한 것은 아니다.

CSEK는 원문의 YAML 키 저장소/CLI 대신 공식 Storage JSON API로 전달한다. 전역 gcloud 설정을 바꾸지 않고 키를 파일·환경 변수·명령 인자에 기록하지 않는다. API rewrite의 구키/신키 header와 완료 응답을 확인한다. 키 폐기 전 setup2/3의 **모든 암호화 세대**를 삭제하므로 검증 후 이 두 파일은 남지 않는다. Python 메모리 완전 소거나 OS swap 방지까지 보장하지 않는다.

Lifecycle과 versioning은 Terraform에서 먼저 설정하고 API로 읽어 확인한다. 콘솔 클릭, 정책의 비활성→활성 UI 전환, 실제 31일 경과 삭제는 검증하지 않는다. Task 6은 원문대로 오래된 generation을 `recovered.txt`로 복구하며 live 객체를 원본으로 덮어쓰지 않는다.

새 실습 bucket에만 `soft_delete_policy.retention_duration_seconds=0`을 명시한다. 일회성 CSEK 데이터가 키 폐기 후 7일간 남는 것을 방지하기 위한 차이이며 saved plan 승인 범위다. 이전 실습에서 이미 soft-delete된 데이터에는 영향이 없다. 조직 정책을 자동 완화하지 않는다.

## Task별 콘솔 확인

[공통 확인법](../console-checks.md)을 먼저 읽고 자신의 프로젝트·해당 run만 선택한다. 아래는 **확인 기준**이지 이번 실행의 성공 기록이 아니다. 원본 Task 이름은 위 매핑과 대응한다.

| Task | 콘솔 경로·대상 | 통과 기준 | 한계·보조 확인 |
|---|---|---|---|
| 1 | Cloud Storage → 버킷 → 해당 run 버킷 | 설정 리전과 fixture 이름/크기가 승인 계획과 같음 | 다른 run 버킷이나 Qwiklabs 제공 파일과 혼동하지 않음 |
| 2 | 버킷 → 객체 → fixture → 권한; 버킷 권한 | 검증 종료 후 임시 allUsers READER가 회수됨 | 임시 공개 동안의 익명 성공·회수 후 거부는 evidence. 공개 권한을 다시 열지 않음 |
| 3 | 버킷 → 객체; CSEK 단계 evidence | CSEK metadata·복호화 hash 성공 기록이 있음 | 보안상 setup2/3의 암호화 세대는 검증 중 제거됨. 콘솔에 안 보이는 것이 정상이고 키를 복원·입력하지 않음 |
| 4 | 동일 버킷과 키 순환 evidence | setup2/3의 구키·신키 성공/거부 조합이 모두 기록됨 | 현재 객체 화면으로 키 순환을 재현할 수 없음. 키값 없는 정제 증거로 확인 |
| 5 | 버킷 → 수명 주기(Lifecycle) | Age 31일의 Delete 규칙이 있음 | 정책 설정 확인이며 실제31일 경과 삭제를 관측한 것은 아님 |
| 6 | 버킷 → 보호(Protection)/버전 관리; 객체 → 버전 이력 | 버전 관리 사용, fixture의 세대/크기와 원본 복구 hash evidence 일치 | 다른 이름의 recovered.txt 로컬 복구는 콘솔에 없어도 정상. 키 폐기 객체와 구분 |
| 7 | 버킷 → 객체 → 동기화 경로 | 동기화한2개 객체의 경로·크기가 기대 집합과 같음 | 내용 무결성은 다운로드 hash evidence로 확인 |
| 8 | 버킷 정책·객체 + Task1–8 evidence | 임시 공개 회수·CSEK 세대 제거·버전·sync 결과를 대조 | 전체 종료는 별도 destroy 후 버킷 부재/잔여0 확인. 검증 성공과 구분 |

메뉴 확인 근거(2026-08-26): [수명 주기 정책 확인](https://docs.cloud.google.com/storage/docs/managing-lifecycles), [객체 버전 확인](https://docs.cloud.google.com/storage/docs/using-versioned-objects). 화면 언어/버전에 따라 상단 검색으로 같은 서비스에 접근한다. 실제 UI 클릭 전 과정 검증은 별도다.

## 구현 작업

`terraform/main.tf`는 bucket과 정책, `execute.sh`·`support.sh`는 승인/인증/소유권, `storage_lab.py`는 데이터 경로, `verify.sh`는 검증·실패 정리를 담당한다. 원본 보존 파일은 수정하지 않았다.

### 준비

저장소 루트에서 실행한다. 새 clone이면 [README의 설치·본인 계정 로그인·프로젝트 준비](../../README.md)를 먼저 마친다. 설정은 ignored `config/harness.env`의 프로젝트 allowlist·리전·billing·cleanup 값을 사용한다.

현재 활성 gcloud **실제 사용자 한 명**을 plan에 저장하고, 이후 apply/verify/destroy에서도 그 사용자로 OAuth identity를 확인한다. 다른 사람도 자신의 로그인으로 새 run을 만들 수 있다. 개인 이메일·프로젝트는 배포 소스에 고정하지 않는다. 기본 하네스 preflight는 사용자 ADC와 billing 연결도 검사한다.

필요한 권한은 실습 프로젝트의 bucket 생성/목록/조회/삭제, 객체·ACL 생성/조회/변경/삭제 및 기존 preflight의 프로젝트·결제 조회다. API 활성화나 IAM 부여를 자동 수행하지 않는다. SA 가장·인증 override, 기존 gcloud CSEK key_store_path, Terraform CLI/variable override가 있으면 조용히 바꾸지 않고 중단한다.

## 실행 계약

한 run의 `plan → apply → verify → destroy`를 따른다. 일반 `.sh` 실행을 다시 승인받는 별도 질문 루프는 없지만, **Cloud 변경은 저장된 bundle SHA 승인**을 요구한다. `verify`도 객체·ACL을 변경하는 실습이며 읽기 전용 명령이 아니다.

먼저 Cloud 리소스를 건드리지 않는 검사를 실행한다. Terraform init은 provider 설치를 위해 네트워크를 사용할 수 있다.

```bash
bash tests/test-phase-08.sh
./scripts/phase-gate.sh docs/phases/phase-08-cloud-storage.md
```

다음은 실제 Cloud 실행 명령이다. 아래 단계를 한꺼번에 붙여넣지 않는다. plan은 조회와 로컬 계획만 수행한다.

```bash
P08_RUN="p08-$(date +%y%m%d)-$RANDOM"
./phases/08/execute.sh plan --run "$P08_RUN"
```

출력된 run ID를 기록한다. `artifacts/runs/$P08_RUN/phase-08/`의 정제된 `phase-08-plan.json`, `action-plan.json`, `plan-bundle.json`에서 새 bucket 1개, 위치, 공개 가능한 fixture 하나의 임시 공개, 암호화 세대 삭제와 soft-delete=0을 확인한다. 승인할 때만 출력된 `plan_sha256` 전체를 입력한다.

```bash
read -r -p "검토 후 승인한 plan_sha256: " P08_PLAN_SHA
./phases/08/execute.sh apply --run "$P08_RUN" --confirm-plan-sha "$P08_PLAN_SHA"
```

apply가 성공했을 때만 실습을 검증한다.

```bash
./phases/08/execute.sh verify --run "$P08_RUN"
```

실습을 마치고 모든 객체/세대를 삭제할 때 다음을 실행한다. 복구용 백업을 만들지 않는다.

```bash
./phases/08/execute.sh destroy --run "$P08_RUN"
```

터미널을 다시 열었다면 `P08_RUN="기록한-run-id"`로 지정한다. 이미 시작한 verify를 같은 run으로 반복하지 않는다. 실패 후에는 해당 run을 정리하고 새 run으로 plan한다.

## 검증 게이트

- Terraform 단일 bucket/create-only·run/project/region·fine-grained·정책을 검사한다.
- plan 이후 코드/fixture/입력/actor가 달라지면 실행을 거부한다. bucket 소유 label·project·생성 시각과 destroy state 대상도 확인한다.
- 익명401/403은 같은 generation의 인증 다운로드가 전후 성공할 때만 접근 거부로 인정한다. 다운로드 오류가 일반 텍스트여도 판정할 수 있으며, 인증된 요청의401을 성공으로 바꾸지 않는다.
- CSEK 실패는 정확한 HTTP400 reason으로 판정한다. media 오류에 reason이 없으면 동일 generation·키의 checksum metadata 요청에서도 정확한 CSEK 거부를 확인한다. 인증·권한·네트워크·404 오류를 키 거부나 삭제 성공으로 처리하지 않는다.
- ACL 공개 grant의 응답만 유실돼도 finally에서 해당 generation을 private로 되돌리고 익명 거부를 재확인한다.
- 정책 JSON, 3개 generation/크기, 원본 복구 hash, rsync 객체 집합/다운로드 hash가 일치해야 한다.
- 모든 source Task의 기계 evidence와 사용자/Extension 검토는 별개다.

## 안전·비용 가드레일

Public Access Prevention이 공개 ACL을 차단하면 HTTP412와 PAP 메시지를 확인해 `policy-prevented`로 기록한다. 나머지 검사는 계속하지만 공개 성공 단계를 완료했다고 주장하지 않는다. `risks`와 `lab_completion.public_acl_exercised=false`를 함께 확인한다.

비밀이 포함될 수 있는 HTTP/CLI 오류 원문은 출력하지 않는다. 실행 artifact는 Git에서 제외하고 제한된 파일 권한을 사용한다. 프로세스 강제 종료·컴퓨터 전원 차단·인증 상실 때는 자동 정리를 보장할 수 없으며 남은 run을 직접 destroy해야 한다.

검증 실패/중단 시 run 소유 bucket을 자동 destroy하고 활성/soft-deleted 목록을 끝 페이지까지 확인한다. 정리 확인까지 실패하면 `cleanup_required`를 유지한다. **실패 cleanup이 성공해도 원래 verify는 실패 종료**한다. 같은 run의 동시 실행은 거부한다. 강제 종료 후 lock이 남으면 프로세스가 실제 종료됐는지 확인하고 관리자에게 해당 run lock 정리를 요청한다.

## 완료 조건

`artifacts/runs/<run-id>/phase-08/` 아래에서 확인한다.

- `evidence/phase-08-machine.json`: Task 1–8, fixture hash, generation 복구, sync hash, PAP 경계.
- `evidence/phase-08-destroyed.json`: 활성 bucket 0·soft-deleted bucket 0.
- `manifest.json`: 최종 `status=destroyed`, `cleanup.status=completed`, 잔여 0.
- `verification-cleanup.log`: 실패 시 정리 결과. Git에 올리지 않는다.

machine evidence는 **검증 시점 기록**으로 `lab_completion.complete=false`와 destroy 대기를 표시한다. 최종 종료 여부는 destroy evidence와 manifest를 함께 판정한다. bucket이 존재하는 동안에는 비용 0이나 전체 정리 완료를 주장하지 않는다.

## Command Code·Extension handoff 지시

Command Code는 모델 override 없이 같은 스크립트를 실행한다. Extension은 키 자체를 요청하지 않고 정제 plan·diff·metadata·hash·성공/거부 evidence를 판정한다. 자동 실패 cleanup은 승인된 실행 계약의 일부다. 정상 실습 종료와 Git 게시에는 사용자 승인 경계를 유지한다.

## Git 종료 조건

검증 후 사용자가 승인한 변경만 한국어로 commit하고 명시적 push 요청이 있을 때 게시한다. 코드 게시 여부, 실제 Cloud machine 검증 성공, 최종 destroy 완료 여부를 구분한다. 현재 성공 run의 bucket은 남아 있으므로 전체 정리 완료로 표시하지 않는다.

## 구현 근거

키 교체는 [공식 rewrite API](https://docs.cloud.google.com/storage/docs/json_api/v1/objects/rewrite), 오류 판정은 [공식 JSON API 오류표](https://docs.cloud.google.com/storage/docs/json_api/v1/status-codes), PAP 경계는 [공식 공개 접근 방지 문서](https://docs.cloud.google.com/storage/docs/public-access-prevention)를 기준으로 구현했다. 공급자 문서와 오프라인 mock 통과는 실제 계정의 Cloud E2E 증거를 대신하지 않는다.
