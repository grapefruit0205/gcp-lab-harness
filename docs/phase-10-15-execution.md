# Phase 10–15 — 실행·확인·실패 복구

이 문서는 저장소를 clone한 사용자가 **자신의 Google 계정·프로젝트**로 실행하는 절차다. 현재 구현은 로컬 회귀·Terraform mock/정적 검증을 통과했지만, 이 개정본의 실제 Cloud apply·네트워크·메트릭 성공은 아직 검증하지 않았다. [수정 내역과 남은 한계](audits/phase-10-15-repair.md)를 먼저 읽는다.

## 1. 로컬 확인 — Cloud 리소스를 만들지 않음

저장소 최상위에서 실행한다. Python3, Bash, jq, Terraform 및 provider 설치를 위한 인터넷 연결이 필요하다. Terraform 요구 버전과 설치는 [README](../README.md)를 따른다.

```bash
python3 scripts/console-checks.py --check-all
python3 scripts/console-checks.py --phase 10 --task 4
python3 tests/test-console-checks.py
./tests/test-phases-10-15.sh
```

첫 두 명령은 Markdown만 읽는다. 마지막 명령은 mock provider를 사용하며 실제 프로젝트에 apply하지 않는다. 문서 리허설은 **여기서 종료**한다. 아래 단계는 실제 실습 실행자와 승인자가 진행한다.

## 2. 본인 계정·프로젝트 준비

1. [README의 GCP 인증·preflight](../README.md)를 따라 로컬 `config/harness.env`를 준비한다. 실제 값·토큰·state는 Git에 넣지 않는다.
2. `gcloud auth list --filter=status:ACTIVE --format='value(account)'`로 실행 계정을 읽는다. 과거 작성자의 이메일을 복사하지 않는다. 필요한 본인 계정 로그인은 본인이 수행한다.
3. `GCP_PROJECT_ID`와 `GCP_ALLOWED_PROJECTS`는 같은 실습 프로젝트여야 한다. 프로젝트의 billing·필요 API·권한·quota를 확인한다. 기존 사용자의 프로젝트를 기본값처럼 사용하지 않는다.
4. Phase10–15는 현재 gcloud 사용자의 단기 토큰으로 CLI/API/Terraform을 맞춘다. 서비스 계정 가장 설정은 지원하지 않으므로 감지되면 중단한다. 별도 ADC 계정이 있어도 그 계정으로 몰래 실행하지 않는다.
5. Phase12/13은 서로 다른 두 리전, Phase14는 **같은 리전의 서로 다른 두 zone**, Phase15는 서로 다른 두 리전의 zone이 필요하다. Phase14의 실제 `zone_two`는 저장 tfvars/output을 기준으로 읽는다.

공통 preflight의 옛 `GCP_CLEANUP_ON_FAILURE=true` 요구는 아직 남아 있다. **Phase10–15의 새 실행 경로는 이 값과 무관하게 실패 시 destroy하지 않는다.** Phase01–08의 옛 apply helper에는 이 보장이 없으므로 이 안내를 다른 Phase에 그대로 적용하지 않는다. Phase09는 별도 `recovery.sh`를 사용한다.

## 3. 저장 계획 생성 → 승인 → apply

예시는 Phase10이다. `p10-260826-a001`은 형식 예시일 뿐이며, 실제 실행에는 **기존 run과 겹치지 않는 새 ID**를 선택한다. 새 Phase 시작 전에는 clean tree와 `git pull --ff-only` 동기화가 필요하다. 현재 미커밋 변경을 자동으로 지우거나 stash하지 않는다.

```bash
./phases/10/execute.sh plan --run p10-260826-a001
```

이 명령은 읽기 조회와 Terraform plan을 실행하고 Cloud 리소스를 생성하지 않는다. 생성되는 로컬 경로는 `artifacts/runs/<RUN_ID>/phase-10/`이다.

- `phase-10-plan.json`: 정제된 리소스 변경 계획. 이름·프로젝트·개수·종류·비용을 검토한다.
- `action-plan.json`: Terraform 밖의 적재·쿼리·부하·alert 변경·VPN 장애 실험 등도 확인한다. **verify가 항상 읽기 전용인 것은 아니다.**
- `plan-bundle.json` 및 출력 `plan_sha256`: Terraform binary plan·action plan·소스/입력/계정 binding을 묶은 승인 대상이다.

승인자가 이 정확한 SHA와 대상·동작을 명시적으로 승인한 뒤에만 다음 형식을 사용한다. 아래 `승인받은_64자리_SHA`는 실제 승인값으로 바꾸는 자리이며 자동 승인 명령이 아니다.

```bash
./phases/10/execute.sh apply --run p10-260826-a001 --confirm-plan-sha 승인받은_64자리_SHA
./phases/10/execute.sh verify --run p10-260826-a001
```

승인 후 소스·입력·work·state·계정이 달라졌으면 실행을 거부한다. 코드를 고친 뒤에는 같은 run의 새 plan과 새 승인이 필요하다. 기존 run의 `harness.env`·계정·프로젝트는 고정이며, 다른 설정으로 실행하려면 기존 자원을 몰래 옮기지 말고 새 run을 계획한다.

검증 성공 시 Task 안내가 출력된다. `manifest.status=verified`는 자동 검사 통과이며 사용자의 콘솔 확인·수동 항목·최종 destroy까지 완료했다는 뜻은 아니다.

## 4. Task 아래 각 항목을 콘솔에서 확인

```bash
python3 scripts/console-checks.py --phase 10
python3 scripts/console-checks.py --phase 10 --task 4
```

번호를11–15로 바꾸면 해당 Phase가 나온다. [공통 콘솔 확인법](console-checks.md)과 `docs/console/phase-NN.md`에서 **원문 하위 제목 → 열 화면 → 읽을 값 → 통과/한계 → 증거** 순으로 확인한다. `<RUN_ID>`는 본인의 실행 값으로 바꾼다.

검증 증거는 로컬 `artifacts/runs/<RUN_ID>/phase-NN/evidence/phase-NN-machine.json`이다. 이 폴더는 GitHub clone에 포함되지 않는다. 실습을 아직 실행하지 않았다면 본인의 Cloud 성공 증거가 없는 것이 정상이다.

| Phase | 추가로 확인할 핵심 증거·경계 |
|---|---|
| 10 | `billing-jobs-*.json`의 job ID로 BigQuery 프로젝트 작업 기록 조회. 전체 행 수와 sample 크기 구분 |
| 11 | VM3개의 최신 uptime=true, 정확한 그룹 구성원, 서로 다른 VM의 AND 조건, alert 이전 true 증거와 현재 Off. 메일 수신은 별도 |
| 12 | `vpn-progress.json`의 baseline → REGIONAL/GLOBAL → 단일 터널 삭제 → 생존 경로. Task8은 정리 전 manual-boundary |
| 13 | image provenance, 두 리전 각각의 backend health, scale-out/in. 중지 builder·IPv6 미지원 환경·원문과의 차이를 별도 기록 |
| 14 | 각 backend 직접 응답 + VIP60회 성공·정확한 두 hostname·실제 client IP. 외부 브라우저에서 private VIP 접속은 확인 방법이 아님 |
| 15 | managed state4개와 data source 분리, 실제 VM 간 ping, 재plan 변경0. 콘솔에 Terraform 멱등성 PASS 화면은 없음 |

## 5. 실패하면 삭제하지 말고 같은 run으로 복구

```bash
./phases/10/execute.sh diagnose --run p10-260826-a001
```

`diagnosis.json`의 단계·exit code·`private_log` 경로와 해당 attempt 로그를 **로컬에서만** 읽는다. `diagnose`는 state 주소 목록을 보여주는 최소 진단 도구이며 장애 원인을 자동으로 모두 설명하지 않는다. 서비스별 job/serial/health 로그를 추가로 대조해야 한다. 원시 로그·state·VPN PSK·토큰은 채팅/Git에 붙여넣지 않는다.

코드 원인을 수정하고 로컬 검사를 통과시킨 뒤:

```bash
./phases/10/execute.sh replan --run p10-260826-a001
```

같은 state·tfvars를 보존하고 새 계획을 만든다. 이전 계획은 `plan-history.*`에 보존된다. 새 SHA의 명시 승인 후 `apply`, 이어 `verify`한다. 일반 복구의 delete/replace는 차단한다. 그런 변경이 필요하면 정확한 최소 대상·이유를 검토하고 별도 승인/구현을 받아야 한다. 보호를 우회하려고 state를 지우거나 전체 destroy하지 않는다.

최초 `plan`이 binding/state를 만들기 전에 실패한 경우에는 같은 `plan --run`을 재시도할 수 있다. 미완료 로컬 시도는 `phase-NN-plan-history.*`로 이동 보존된다. 기존 apply가 있는 run에는 이 경로를 쓰지 않는다. binding이 없는 구형 run도 자동 이관하지 않는다.

Phase12는 이미 tunnel0을 삭제한 단계에서 중단됐다면 같은 소스/binding의 `verify`가 단계 기록을 사용한다. 코드 수정으로 binding이 바뀌었다면 `replan → 새 승인 → apply`가 먼저다. 장애 실험 대상의 Cloud ID가 바뀌면 삭제를 거부한다.

## 6. 종료 정리도 별도 저장 계획으로

리소스는 실패/검증 직후 자동 삭제되지 않는다. **자동 만료 스케줄러는 없으며** VM·disk·VPN·LB·NAT 등의 비용이 남는다. 중지 VM도 disk 비용이 남는다.

```bash
./phases/10/execute.sh plan-destroy --run p10-260826-a001
```

삭제 계획의 정확한 대상과 새 SHA를 검토해 승인한 뒤:

```bash
./phases/10/execute.sh destroy --run p10-260826-a001 --confirm-plan-sha 승인받은_삭제계획_64자리_SHA
```

현재 run의 Terraform state에 속한 리소스만 대상으로 한다. 삭제 후 전체 관련 리전/zone inventory를 조회하며403·API 오류를 ‘0개’로 판정하지 않는다. 일부 삭제 실패 시 남은 state와 로그를 보존하고 같은 run에서 원인을 좁힌다. 다른 Phase·다른 run·이전 Phase09 PSA 잔여는 이 명령의 대상이 아니다.
