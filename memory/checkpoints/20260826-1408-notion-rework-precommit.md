# Checkpoint — Phase 07 각자 계정 등록 자동화 — 2026-08-26 13:48

## The story so far

사용자는 수동 실습 초기 상태만 만드는 제안을 거절하고 각자 자신의 계정을 추가할 수 있도록 자동화하라고 명확히 했다(D-025). 실제 User1/User2 계정과 workload SA 하나의 D-024 구조는 유지하며, 계정 입력부터 Google 로그인까지 연결하는 준비 진입점을 구현했다.

새 명령은 저장소 루트의 `./bin/gcp-lab-harness accounts setup`이다. 기존 이메일은 Enter로 유지/교체하고, 로그인은 재사용하거나 필요한 계정만 Google 브라우저로 연결한다. 직접 JSON 편집이나 IAM 콘솔 사전 추가는 필요 없다. setup은 로컬 설정/인증만, 실제 프로젝트 IAM 추가·역할 전이는 새 승인된 apply/verify 흐름이 처리한다. Phase 07 plan은 TTY에서 누락 준비를 연결하고 AI/CI 비대화형에서는 안내 후 중단한다. apply/verify/destroy는 기존 saved inputs를 사용해 계정 교체에 영향을 받지 않는다.

observed: Python 73 tests(실제 격리 CLI 등록/계정 교체/비대화형 중단, Linux PTY 입력 포함), Terraform mock 8 tests, validate/fmt, 개별 Bash syntax, Phase gate, Phase 07–15 offline suite 및 offline controller가 통과했다. 개인정보 Git 제외/mode600, 원문·Phase 06 소스 보존, diff check도 통과했다. 실제 accounts check는 User2 미인증으로 예상 중단했다. 새 Google 로그인/Cloud apply/E2E/commit/push는 하지 않았다.

문서 rehearsal 1회는 같은 모델의 맥락 없는 실행자가 CLI help와 offline 검사까지 실행해 수동 인증 경계 전 차단 막힘이 없음을 보고했다. 70→73 테스트 수 표기만 지적했고 최신 문서에 73을 반영해 재확인했다. 실제 사용자 로그인이나 Cloud 완료로 확대하지 않는다. 모든 실행 tool session은 종료됐다.

## Decided

- D-025: 사용하는 사람마다 자신의 관리자·실습 계정을 입력/추가하는 준비 흐름을 제공한다. 수동 준비 전용 모드로 목표를 바꾸지 않는다.
- D-024: 실제 사용자 두 개를 SA 가장으로 대체하지 않는다. 비밀번호/인증 코드는 사용자 본인이 Google에 입력한다. 가상 domain grant는 하지 않는다.
- 새 plan의 정확한 SHA 승인 전 Cloud 변경은 없다. 프로젝트는 기존 allowlist를 유지하며 새 프로젝트를 자동 생성하지 않는다.
- 기존 Minecraft 서버와 사용자 계정 설정을 보존했다. 원문과 Phase 06 소스는 수정하지 않았다.

## Waiting on the user

계정 2의 실제 Google 브라우저 인증이 남았다. 터미널에서 `cd /home/grapefruit/gcp-lab-harness && ./bin/gcp-lab-harness accounts setup`을 실행하면 기존 설정을 재사용해 로그인으로 연결한다. 새 Cloud 실행은 이후 새 plan SHA 승인이 필요하다.

## Next first action

사용자가 로그인 완료 또는 실행 재개를 요청하면 `cd /home/grapefruit/gcp-lab-harness && ./bin/gcp-lab-harness accounts check`로 두 실제 사용자 OAuth를 확인한 뒤 새 run/plan을 만든다. 이전 source의 승인 SHA를 재사용하지 않는다.

## Tried

- 사용자 요구를 수동 실습 초기 상태 준비만으로 좁힌 것은 잘못된 해석이었다. 각자의 계정을 추가하는 자동화가 요구사항이다.
- JSON 직접 편집 안내만으로는 사용자별 계정 준비 자동화가 아니다. 입력/기본값/등록/브라우저 로그인/재시도/plan 연동을 구현했다.
- 기존 SA 대체 run은 실제 사용자 실습 완료가 아니다. a9d2는 최종 Storage 거부 판정 실패 후 소유 리소스 13개와 VM/bootdisk cleanup, 잔여0/IAM복구/Minecraft동일로 종료됐다.
- 일반 HTTP403은 IAM 거부 증거가 아니며 VM insert HTTP200은 생성 완료가 아니다. 동일 identity permission 검사 및 최종 operation 검사 유지.
- Storage 객체 권한은 버킷 endpoint에서 검사하고 project Object Viewer의 project get/list 권한 가능성을 반영한다.
