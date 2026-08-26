# Checkpoint — Phase10–15 실제 검증 완료·최종 게시 준비 — 2026-08-26 23:27

## The story so far

D045/D047 범위의 Phase10–15 apply/기계 검증이 모두 통과했다. 최종 run은10 p10-260826-2106,11 p11-260826-2224,12 p12-260826-2236,13 p13-260826-2243,14/15 p14/p15-260826-2300이다. 상세SHA·결과는PRODUCT-TRUTH와실행안내에있다. Phase13은f5c0dead…NAT보완후확장/축소검증통과:목표합계2→첫확장3/후속4→2,marker4/LB로그20. 실제VM삭제는backend draining300초때문에잠시진행중이므로settled추가readback이남았다. Phase14는9af07dc…18no-op와정확한guest설정수렴으로VIP60/두backend/clientIP를통과했다.

최신54회귀/TFmock9/전체make test-offline·안내13tests/coverage통과. 여섯run모두source/work/input/config/account/applied binding일치. shared6lib/Phase08/09/원문변경0. 최신원격88cbe39 이후현재관련변경은미커밋으로D045최종게시가남았다.

## Decided

- D047: 이번범위의저장계획/SHA/소유권/비용검사후재질문없이실행. 결과게시후일회위임종료·새Cloud실행승계없음.
- D045: 관련변경만stage·한국어commit·main일반push·원격SHA검사. 비밀/개인설정/state/원시로그제외.
- D036/37: 실패리소스/state/로그보존·전체destroy없음. Phase12원문장애터널1개삭제·Phase13autoscale축소는실습범위.
- D043/44: Task·하위콘솔확인법연결,자동verified와수동UI/메일/종료정리구분. IPv6실제HTTP미검증·builder중지보존.

## Waiting on the user

없음. Q024 Phase11 향후cleanup dashboard API보완·Q014 legacy·Q012/020 이전PSA는별도. 현재리소스유지비용이계속발생한다.

## Next first action

`cd /home/grapefruit/gcp-lab-harness && gcloud compute instance-groups managed describe us-1-mig-p13-260826-2243 --region=us-central1 --project=kdt5-05 --format='json(targetSize,status.isStable,currentActions)'`로안정화를확인하고양쪽최종readback/기록후관련파일commit/push·원격SHA를확인한다.

## Tried

- P13 stoppedVM직렬조회not-ready→중지전receipt·동일ID후속재수집표시유지.
- P13 NAT64/동시100 timeout·드롭893→8192/keepalive/journal·실제scale검증통과.
- P14 INTERNAL UTILIZATION400→CONNECTION,표시transform VM404→원시JSON,DirectoryIndex누적→별도영구drop-in.
- P10 AVRO논리형·P11filter/alignment/API버전오류는동일state보존복구로통과.
- 최종binding직접dict비교는保存state추가필드때문에오판;공통5필드각각과applied receipt를대조해여섯run모두일치확인.
