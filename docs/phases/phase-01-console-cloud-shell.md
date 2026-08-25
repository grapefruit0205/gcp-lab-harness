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
