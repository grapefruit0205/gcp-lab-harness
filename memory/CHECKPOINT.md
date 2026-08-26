# Checkpoint — Phase 06 공개 접속 plan 승인 대기 — 2026-08-26

## The story so far

observed: 기존 Minecraft 서버가 Java 1.20.4로 응답하지만 firewall source가 제한돼 외부 상태 조회가 timeout된다. D-020에 따라 TCP 25565의 `0.0.0.0/0` 공개를 지원하도록 Terraform·execute·verify·공통 정책과 테스트를 수정했다. SSH는 IAP-only, bucket은 비공개다. Python 12개·Terraform mock 4개·Phase 06 gate·Phase 01–06 offline 검사를 통과했다. 기존 run의 saved plan은 firewall source-only update 1개이며 실제 apply는 아직 하지 않았다.

## Decided

- D-020: 사용자가 게임 포트 공개, Terraform 반영, 한국어 commit·push와 재적용을 요청했다.
- 기존 VM·월드·고정 IP 유지, 생성·삭제·재시작 없음. D-017의 exact saved-plan SHA 승인 절차는 유지한다.

## Waiting on the user

- ignored `artifacts/runs/run-p06-708435/phase-06/updates/public-25565.u0yUiD/public-25565.tfplan`의 승인. SHA256 `642c5674a85abec922ce5f1ac08c3a1b4be485e8153459f9a5ce9f51ff098536`, 추가 0·변경 1·삭제 0. 사용자에게 비동기 질문을 보냈다.

## Next first action

사용자가 위 SHA의 plan을 승인했는지 확인하고, 승인되면 `network-policy.py update`와 저장 hash를 다시 검사한 뒤 해당 plan만 기존 run에 apply한다.

## Tried

- gcloud/git는 인증 캐시·.git 쓰기 권한이 필요했다. 중단 후 권한이 초기화되어 필요한 경로·네트워크 권한을 다시 요청했다.
- 신규 create plan의 firewall direction은 provider가 unknown으로 두므로 Terraform에 INGRESS/disabled=false를 명시하고 실제 신규 plan으로 정책 회귀 검증했다. 승인 요청된 기존 update plan의 실질 변경은 그대로 source_ranges 하나다.
- 신규 생성용 apply helper는 실패 시 destroy를 시도하므로 기존 서버의 firewall 변경에 사용하지 않는다. 전체 cloud verifier 역시 stop/start를 포함하므로 재실행하지 않는다.
