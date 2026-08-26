# Checkpoint — Phase10–12/14/15 통과·Phase13 자동 축소 대기 — 2026-08-26 23:22

## The story so far

현재 위임 D047의 계정/project에서 Phase10·11·12·14·15 apply/실제 Task 검증 통과. Phase13 p13-260826-2243도 최종 f5c0dead…로 NAT만 갱신한 apply0 뒤 실제 baseline2→확장(첫 관측3, 별도 snapshot4), backend marker4·LB로그20 확인했다. 23:09:50 부하 종료 후 verifier session47754가 baseline2 복귀를 기다린다. 리소스 수를 수동 조작하지 않는다.

Phase14 최종9af07dc…18no-op apply/verify0. persistent p14-php-index.conf로 재시작 시 원본 conf 덮어쓰기와 분리한 PHP 설정을 수렴시켰다. backend2 HEALTHY·VIP60응답/두hostname/clientIP 보존 통과. 실제 reboot 검증은 하지 않았다. 최종54회귀/TF mock9/전체 make test-offline 통과. Phase14 안내 zero-context 리허설5명령도통과(Cloud/UI 미실행). 최신 게시88cbe39 이후 변경은 미커밋이다.

## Decided

- D047: 이번 Phase10–15는 저장계획/SHA/소유권/비용 검사 후 재질문 없이 실행; 완료 후 새 실행으로 승계하지 않음.
- D045: 관련 변경·증거 요약을 한국어 commit/push, 비밀·개인 설정·state·원시로그 제외.
- D036/D037: 실패 리소스/state/로그 보존, 전체destroy 금지. 이전Phase08/09·다른run 유지.
- D043/D044: Task·하위 항목 콘솔 안내 및 실제/수동 경계 분리. Phase12 의도적 터널1개 삭제·Task8 정리 제외.

## Waiting on the user

없음. Q014 legacy/Q019 catalog/Q012·020 PSA는 범위 밖. Q024 Phase11 향후 cleanup inventory의 dashboard v3→v1 보완은 다음 명시적 종료 시 필요하며 현재 apply/verify 통과와 별개다.

## Next first action

`cd /home/grapefruit/gcp-lab-harness && jq . artifacts/runs/p13-260826-2243/phase-13/evidence/autoscale-progress.json && tail -n 8 artifacts/phase13-nat-cloud-verify.log`를 실행하고 session47754 종료·실제 MIG2 복귀를 확인한 뒤 최종 기록/커밋/푸시한다.

## Tried

- P13 stopped VM 직렬조회→not-ready; 중지 전 receipt/동일builder 재수집, recovered_after_image=true로 시점 구분.
- P13 NAT64포트/동시100→timeout·OUT_OF_RESOURCES893;8192포트·keepalive·journal/fail-fast로 보완.
- P14 INTERNAL 기본UTILIZATION→API400;CONNECTION 명시로 생성 성공.
- P14 gcloud value(instance)→zone/VM404;원시JSON URL·소유권 검증으로 수정.
- P14 DirectoryIndex 누적→기본HTML;disabled→index.php 별도 영구conf/설정검사/reload/실제PHP로 복구. VM/template교체 없음.
- P10 AVRO 논리형·P11필터/정렬/API버전 오류는 동일state 보존 복구로 실기 통과.
