# Checkpoint — Phase 07 apply 완료·IAM 실습 검증 중 — 2026-08-26

## The story so far

observed: 사용자 승인 D-021에 따라 run `p07-260826-72bd`의 exact bundle을 apply했다. Terraform 12 added·0 changed·0 destroyed로 완료됐고 manifest는 applied다. `verify.sh --applied` read-only topology 검사와 Terraform 재plan exit 0/no changes도 통과했다. 현재 `execute.sh verify`가 실제 IAM 실습을 수행 중이다. 전체 Cloud 실습 통과는 아직 선언하지 않는다. 실제 저장소는 `/home/grapefruit/gcp-lab-harness`다.

## Decided

- D-021: 사용자는 bundle SHA `cbadfcca92660a44a40653665e8ad1bc35cb61895b5699eb1467b0908ddd095e`의 apply·IAM 검증을 “ㅇㅇ”로 승인했다. 승인 기록은 ignored run의 `user-plan-approval.json`에 있다.
- 임시 권한은 실습 종료 시 회수한다. 실패 시 run 소유 리소스만 자동 cleanup한다. 성공 뒤 최종 destroy·commit·push는 승인 범위 밖이다.
- Phase 06 서버·월드·고정 IP를 보존한다. 승인 후 실행 코드를 바꾸면 source hash guard가 거부하므로 중간에 임의 수정하지 않는다.

## Waiting on the user

없음. 승인된 IAM 실습이 진행 중이다.

## Next first action

`tail -n 30 /home/grapefruit/gcp-lab-harness/artifacts/runs/p07-260826-72bd/phase-07/verify.log`로 현재 검증 단계와 오류를 확인한다.

## Tried

- 중간 후보 `p07-260826-c4b7`은 fixture redaction guard 문제로 중단, `p07-260826-f8e2`는 코드 보완 전 source SHA라 stale이다. 두 run은 apply하지 않았다.
- provider가 fixture content도 sensitive 처리하므로 원문 plan을 파일로 저장하지 않고 guard로 pipe한다.
- 현재 apply 로그·승인본 plan backup·no-drift plan/log·read-only 증거는 최종 run의 ignored artifacts에 보존되어 있다.
- IAM 실습 실패 시 verifier의 자동 rollback/destroy가 실행될 수 있다. 완료/잔여 여부는 manifest와 `verification-cleanup.log`에서 확인하며 인증 실패를 잔여 0으로 취급하지 않는다.
