# Private 부하 VM의 NAT 포트 부족

Checked: 2026-08-26. Label: observed(n=1 실제 run), 아래 수정 후 실기 포함.

Phase13 부하 VM의 HTTP curl/ab20·동시2는성공했지만ab5000·동시100은43요청후30초timeout이었다. 실제NAT mapping의32+32=64포트와해당instance의Monitoring `compute.googleapis.com/nat/dropped_sent_packets_count`에서 OUT_OF_RESOURCES893을관측했다. 기본방화벽차단으로단정하지않았고전체ingress를열지않았다. 기존부하unit은30초뒤exit1이었지만--collect후systemctl show는비활성기본값을보여journal을따로대조했다.

근거: ignored `artifacts/phase13-{load-diagnosis,load-http-diagnosis,ab100-diagnosis}.log`, `phase13-nat-{mapping-diagnosis,dropped-packets}.json`. 토큰/계정/주소원문은게시하지않는다.

공식 [NAT 포트 할당](https://docs.cloud.google.com/nat/docs/ports-and-addresses)은static allocation이고갈되어도자동으로VM별포트가증가하지않는다고설명한다. [NAT 측정항목](https://docs.cloud.google.com/nat/docs/monitoring)은OUT_OF_RESOURCES를주소/포트부족으로정의한다. [ab 옵션](https://httpd.apache.org/docs/2.4/programs/ab.html)의-k는연결재사용,-s는socket timeout,-t는시간제한이다.

수정: 부하VM전용NAT만min_ports_per_vm8192로확장,ab keepalive·동시100·350초/상위systemd360초한도. journal보존과scale-out전unit조기종료검사,재시도baseline자동수렴대기를추가했다. 다른NAT/기존실습/전체방화벽은변경하지않는다. 최종성공은실제scale-out/in증거로확정한다.

후속실측: f5c0dead…동일run NAT1update 재apply/verify가exit0이었다. baseline2→첫확장3(후속snapshot4)→목표2복귀,서로다른backend4·LB로그20을확인했다. `artifacts/runs/p13-260826-2243/phase-13/evidence/autoscale-progress.json`은stage verified/final_target_total2다. 포트수/keepalive를 함께 보완했으므로 어느 한 수정만의 효과나 모든부하조건의성공으로 일반화하지 않는다. 수정후 드롭카운터0 자체를 검증한 것은 아니다.
