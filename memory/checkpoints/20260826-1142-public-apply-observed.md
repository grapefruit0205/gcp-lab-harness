# Checkpoint — Phase 06 공개 접속 적용·외부 캐시 갱신 확인 중 — 2026-08-26

## The story so far

observed: 사용자 승인된 saved plan으로 Minecraft TCP 25565만 전체 IPv4에 공개했다. apply는 추가 0·변경 1·삭제 0이며 VM·disk·고정 IP와 마지막 시작 시각이 유지됐다. SSH는 IAP-only, bucket은 비공개다. 직접 Minecraft status는 Java 1.20.4/protocol 765로 응답했고 Terraform 재plan은 변경 0이었다. 외부 상태 사이트의 변경 전 실패 캐시 만료 후 재조회를 진행 중이다. 코드 commit `eeefeeb`는 이미 origin/main에 반영됐다.

## Decided

- D-020: 사용자가 게임 포트 공개, Terraform 반영, 한국어 commit·push와 재적용을 요청했다.
- 기존 VM·월드·고정 IP 유지, 생성·삭제·재시작 없음. D-017의 exact saved-plan SHA 승인 절차는 유지한다.
- 사용자가 SHA `642c5674a85abec922ce5f1ac08c3a1b4be485e8153459f9a5ce9f51ff098536` plan을 승인했고 그 plan만 적용했다.

## Waiting on the user

없음. 실제 게임 클라이언트 로그인은 이번 자동 검증 범위 밖이다.

## Next first action

ignored `artifacts/runs/run-p06-708435/phase-06/updates/public-25565.u0yUiD/external-status.fresh.json`의 online/ping 값을 확인하고 runtime 증거와 이 기록을 마무리한다.

## Tried

- gcloud/git는 인증 캐시·.git 쓰기 권한이 필요했다. 중단 후 권한이 초기화되어 필요한 경로·네트워크 권한을 다시 요청했다.
- 신규 create plan의 firewall direction은 provider가 unknown으로 두므로 Terraform에 INGRESS/disabled=false를 명시하고 실제 신규 plan으로 정책 회귀 검증했다. 승인 요청된 기존 update plan의 실질 변경은 그대로 source_ranges 하나다.
- 신규 생성용 apply helper는 실패 시 destroy를 시도하므로 기존 서버의 firewall 변경에 사용하지 않는다. 전체 cloud verifier 역시 stop/start를 포함하므로 재실행하지 않는다.
- 외부 사이트가 변경 전의 5분 실패 캐시를 반환해 응답의 cacheexpire 이후 재조회한다. 이 캐시를 현재 서버 미기동 증거로 취급하지 않는다.
- HTTPS push는 인증정보가 없어 실패했다. 기존 `github-gcp-lab-harness` SSH alias의 전용 키와 직접 SSH 저장소 URL을 사용하면 push할 수 있다.
