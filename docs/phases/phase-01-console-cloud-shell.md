# Phase 01 — Google Cloud Console 및 Cloud Shell

- 원본: `references/google-cloud-labs-ko/labs/01.Working with the Google Cloud Console and Cloud Shell_KR.md`
- 비용 위험: 낮음
- 주요 서비스: Cloud Storage, Cloud Shell에 대응하는 Bash·gcloud 환경

## 목적

Google Cloud 프로젝트와 CLI 인증을 확인하고 버킷·객체 작업, 셸 환경 변수와 프로필 지속성을 재현한다. Console·Cloud Shell UI 탐색은 자동 완료로 가장하지 않고 관찰 가능한 Cloud 상태와 CLI 동등 작업을 검증한다.

## 범위와 원본 매핑

| 원본 Task | 분류 | 자동화·증거 |
|---|---|---|
| Task 1. Cloud console을 사용하여 버킷 생성하기 | cli-equivalent | 고유 버킷 생성, 위치·스토리지 클래스 describe JSON |
| Task 2. Cloud Shell 액세스하기 | manual-boundary | `gcloud info`, 활성 계정·프로젝트·셸 도구 preflight; UI 자체는 수동 경계로 기록 |
| Task 3. Cloud Shell을 사용하여 Cloud Storage 버킷 생성하기 | cli-equivalent | 두 번째 버킷 생성과 API 목록 일치 |
| Task 4. Cloud Shell의 추가 기능 살펴보기 | cli-equivalent | fixture 업로드, 객체 hash·크기·다운로드 hash 비교 |
| Task 5. Cloud Shell에서 지속 상태 만들기 | cli-equivalent | 격리된 임시 HOME에서 환경 변수와 profile 재로딩 검증 |
| Task 6. Google Cloud 인터페이스 정리하기 | automated | run 소유 객체·버킷 삭제와 잔여 inventory 0 |

## Task별 콘솔 확인

[공통 확인법](../console-checks.md)을 먼저 읽고 자신의 프로젝트·해당 run만 선택한다. 아래는 **확인 기준**이지 이번 실행의 성공 기록이 아니다. 원본 Task 이름은 위 매핑과 대응한다.

| Task | 콘솔 경로·대상 | 통과 기준 | 한계·보조 확인 |
|---|---|---|---|
| 1 | Cloud Storage → 버킷 → 이름에 해당 run이 있는 console 버킷 | 위치·스토리지 클래스가 승인 계획과 같음 | Terraform 생성은 콘솔의 생성 버튼을 눌렀다는 증거가 아님 |
| 2 | 콘솔 상단 Cloud Shell 활성화 → 터미널 | 본인 계정과 선택 프로젝트가 맞고 셸이 열림 | 수동 UI 경계. 로컬 Bash preflight 통과와 별개이며 로그인/프로젝트를 임의 변경하지 않음 |
| 3 | Cloud Storage → 버킷 → 해당 run의 shell 버킷 | console용과 별개인 두 번째 버킷이 존재 | 로컬 CLI 동등 작업 결과이며 실제 Cloud Shell에서 생성했는지는 별도 |
| 4 | 해당 버킷 → 객체 → 업로드 fixture 상세 | 객체 이름·크기와 다운로드 내용이 fixture와 일치 | 바이트 무결성은 로컬 다운로드 SHA-256 evidence로 보조 |
| 5 | Cloud Shell → 터미널; 로컬 검증의 profile evidence | 격리된 셸에서 재로딩 후 환경 변수 값이 유지됐다는 증거 | 자동화는 임시 HOME 사용. 실제 사용자 Cloud Shell 프로필에 같은 값이 남아 있어야 하는 것은 아님 |
| 6 | 삭제 승인 후 Cloud Storage → 버킷 | 해당 run 두 버킷과 객체가 없고 삭제 inventory가 0 | 검증 직후에는 남아 있는 것이 정상. 다른 run 버킷/soft-delete 보존과 구분 |

메뉴 확인 근거(2026-08-26): [Cloud Storage 버전별 객체 확인](https://docs.cloud.google.com/storage/docs/using-versioned-objects). 화면 언어/버전에 따라 상단 검색으로 같은 서비스에 접근한다. 실제 UI 클릭 전 과정 검증은 별도다.

## 구현 작업

1. 활성 계정, 허용 프로젝트, API, 기본 리전을 읽기 전용으로 점검한다.
2. 충돌하지 않는 이름의 버킷 두 개와 작은 fixture 객체를 plan에 기록한다.
3. 저장된 plan 승인 후 생성·업로드·다운로드를 실행하고 SHA-256을 비교한다.
4. 실제 사용자 profile을 건드리지 않는 임시 HOME에서 `.bashrc` 지속성 검사를 수행한다.
5. Console·Cloud Shell 고유 UI 항목은 coverage manifest에 `manual-boundary`로 보존한다.

## 실행 계약

`cmd`가 Phase 문서와 공통 prompt를 받아 `preflight -> plan -> apply -> machine-verify`를 실행한다. `cmd` 실행에는 모델·effort 선택 인수를 전달하지 않고 현재 계정의 고정 모델을 상속한다. machine verification 뒤 상태는 `waiting_extension_review`이며 cleanup·Git 작업은 아직 하지 않는다.

## 검증 게이트

- 두 버킷의 프로젝트·위치·이름이 plan과 일치한다.
- 객체 업로드 전후 hash와 다운로드 후 hash가 일치한다.
- 새 Bash 프로세스에서 profile 기반 환경 변수가 재현된다.
- VS Code Codex Extension은 diff, coverage, Cloud Storage read-only 조회를 검토한다.
- Extension 보고 후 사용자가 명시적으로 승인해야 cleanup으로 전이한다.

## 안전·비용 가드레일

- 버킷 이름은 run ID를 포함하고 허용 프로젝트 밖에서는 생성하지 않는다.
- fixture는 작게 제한하며 public access와 보존 정책을 만들지 않는다.
- 실제 `$HOME`이나 기존 Cloud Shell profile을 수정하지 않는다.
- manifest에 등록된 객체와 버킷만 삭제한다.

## 완료 조건

- Task 1–6이 모두 coverage manifest에 분류되어 있다.
- 기계 검사와 Extension 검토가 통과하고 사용자 승인이 기록되어 있다.
- cleanup 후 Phase 01 소유 Cloud 리소스가 0이다.

## Command Code·Extension handoff 지시

Command Code는 원본 Task 누락을 확인하고 machine verification까지만 수행한다. Extension은 파일을 수정하지 않고 저장소 gate와 read-only Cloud 조회를 실행해 결과와 미실행 경계를 사용자에게 보고한다. 사용자의 명시적 승인 없이 승인 파일을 만들지 않는다.

## Git 종료 조건

정제 evidence만 stage하여 `Phase 01: Console과 Cloud Shell 자동화 및 검증 완료`로 커밋하고 같은 SHA를 `origin`에 push한다. remote SHA 확인 전에는 Phase 02를 시작하지 않는다.
