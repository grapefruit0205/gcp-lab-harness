# Goal — Google Cloud 실습 자동화 하네스

## 목적

한국어 실습 15개를 Google Cloud 실습 계정에서 CLI로 계획·실행·검증·정리할 수 있는 안전하고 반복 가능한 도구로 만든다. Ubuntu Bash의 Command Code `cmd` runner와 VS Code Codex Extension verifier를 분리하고 Phase별 한국어 Git 이력을 남긴다.

## 현재 지형

- 입력: 정리된 한국어 Markdown 실습 15개와 이미지 자산
- 실행 표면: Bash, Command Code CLI `cmd`, gcloud, Terraform, Git (`gh`는 원격 관리용 선택 도구)
- 현재 관찰: Command Code 1.32.2 설치·계정 인증 완료, Codex Extension용 Codex CLI 0.149.1, Git 2.43.0, jq 1.7, Bash 5.2 설치됨
- 현재 결손: gcloud, Terraform 미설치; GitHub CLI는 선택 도구로 미설치
- 외부 제약: Marketplace CLI 지원은 제품별, Billing 데이터는 비동기, 예산은 사용 상한이 아님

## 전체 골격

1. Foundation A: 도구·계정·인증·비용 경계
2. Foundation B: 하네스 상태 머신·증거·handoff
3. Phase 01–15: 원본 Lab과 1:1인 Cloud adapter
4. 전체 E2E, 잔여 리소스 검사, release

## 완료 증거

- Phase 문서 15개와 모든 Lab/Task coverage manifest
- `plan -> apply -> verify -> destroy` 계약의 기계 판독 결과
- 깨끗한 전용 프로젝트에서 전체 Phase 통합 실행
- destroy 후 run 소유 잔여 리소스 0
- 비밀정보·state의 Git 유입 0
- VS Code Codex Extension review의 P0/P1 0과 사용자 승인
- Phase별 한국어 commit과 GitHub push

## 중단 조건

- 허용 프로젝트, 결제 계정, 예산 한도가 확정되지 않으면 Cloud apply를 시작하지 않는다.
- 리소스 소유권을 증명할 manifest가 없으면 자동 destroy하지 않는다.
- Marketplace 상품의 공식 CLI 배포 경로가 없으면 해당 항목을 blocked로 표시한다.

## Foundation B 동원 — 2026-08-25

| 구분 | 기존 자산 | 이번 적용 |
|---|---|---|
| 상태 계약 | `docs/foundation/harness-core.md`, D-008~D-010 | 15개 Phase cursor와 허용 전이를 JSON으로 영속화 |
| 승인 계약 | Extension approval schema | plan/diff/evidence SHA-256 결합과 stale approval 차단 |
| 복구 계약 | `resume --run <id>` 설계 | 현재 Phase 상태에서 다음 동작을 결정론적으로 출력 |
| 안전 경계 | Q-002, Foundation A 중단 조건 | Cloud adapter와 실제 `run-all`은 계속 차단 |
| 검증 | 최소 테스트 선호, offline 계약 | 단일 Bash fixture로 전이·승인·반려·resume 확인 |

Foundation B 컨트롤러는 구현됐고, 다음 기반 작업은 Foundation A 도구 설치·계정 preflight 및 실제 supervisor 연결이다.
