# Checkpoint — Phase 07 Notion·개인별 계정 반영 — 2026-08-26 14:08

## The story so far

사용자 지정 Notion 본문을 실제로 읽고 Phase 07을 A/B 실습으로 재대조했다. B에게 workload-only actAs와 project Compute Instance Admin을 임시 부여하고 **B가 VM 생성**, A가 SSH·IAM 변경·정리를 수행하도록 수정했다. Viewer 회수 후 기존 sample 읽기 거부, workload Creator 전환 후 읽기 거부, B 임시 역할 4개 회수와 A 보존 검사를 추가했다. Terraform baseline은 8개다.

clone한 사람은 `./bin/gcp-lab-harness accounts setup`에서 자신의 두 계정을 입력한다. 최초 A 제안값도 그 환경의 활성 gcloud 사용자뿐이다. 개인 계정 설정/프로젝트 설정/credentials는 Git에서 제외한다. 승인된 run의 계정은 saved inputs로 고정한다.

observed: Python 84개, Terraform mock 8개, fmt/validate, Bash syntax, Phase gate, Phase 01–15 offline와 controller, 개인정보·원문/Phase 06 소스 보존 검사를 통과했다. 문서 리허설은 인증 경계 전 차단 막힘이 없었고 비차단 `accounts setup --help` 문제를 발견해 수정·회귀 검사했다. 실제 B 인증은 아직 없고 새 plan/apply/Cloud E2E는 실행하지 않았다. 관련 커밋·푸시는 D-026으로 승인됐으며 현재 최종 검토/게시 전이다.

## Decided

- D-026: Notion 현재 본문 기준 재수정·관련 커밋·푸시·apply 요청. Notion 자체와 보존 원문은 수정하지 않는다.
- D-027/D-025: 특정 개인 로그인에 고정하지 않고 각 clone 사용자가 자신의 실제 A/B를 준비한다.
- D-024/D-017: 두 실제 사용자 인증과 새로운 exact saved-plan SHA 승인 후에만 Cloud 변경한다. 과거 승인 SHA를 재사용하지 않는다.
- B Compute 역할은 기존 VM에도, 프로젝트 Storage 역할은 기존 버킷에도 적용됨을 문서/action plan에 경고했다. 자동 요청은 run 소유 리소스에 한정한다. 기존 Minecraft는 변경하지 않는다.
- 리소스 최종 destroy는 별도 승인 대상이다. IAM 검증만으로 Notion 전체 정리가 완료됐다고 하지 않는다.

## Waiting on the user

계정 B의 Google 브라우저 인증이 필요하다. 저장소에서 `./bin/gcp-lab-harness accounts setup`을 실행하면 자신의 기존 설정을 유지/교체하고 미인증 계정 로그인을 이어간다. 이후 생성한 새 plan의 범위·정확한 SHA를 제시하고 적용 승인을 받는다.

## Next first action

`cd /home/grapefruit/gcp-lab-harness && git diff --check && git status --short`로 게시 대상 최종 검토 후 D-026 범위의 Phase 07 변경만 한국어 커밋·일반 push하고 원격 SHA를 대조한다.

## Tried

- SA 두 개 가장이나 A의 VM 생성 성공은 실제 B의 Notion Task 6 성공을 대신하지 못한다.
- JSON 수동 편집 안내만으로는 개인별 계정 등록 자동화가 아니다. 입력/저장/Google 로그인/identity 확인을 연결했다.
- B 미로그인을 전체 인증 성공으로 처리하거나 과거 plan 승인을 재사용하지 않는다.
- HTTP403 단독은 IAM 거부, VM insert HTTP200은 최종 생성 성공의 증거가 아니다. 실제 permission/operation/RUNNING identity를 검사한다.
- 과거 a9d2는 최종 Storage 거부 판정 실패 후 소유 리소스 13개와 VM/bootdisk를 정리했다. 새 실제 사용자 경로의 Cloud E2E 증거가 아니다.
