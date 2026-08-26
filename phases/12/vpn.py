#!/usr/bin/env python3
"""VPN baseline→routing 전이→장애 주입의 중단 가능한 검증."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "lib/harness"))
from advanced import digest, write_json


def cloud(*args):
    result = subprocess.run(["gcloud", *args, f"--project={os.environ['GCP_PROJECT_ID']}", "--format=json", "--quiet"],
                            check=True, text=True, capture_output=True, timeout=180)
    return json.loads(result.stdout or "null")


def poll(check, seconds=600):
    end = time.monotonic() + seconds
    while time.monotonic() < end:
        if check():
            return
        time.sleep(10)
    raise ValueError("VPN/BGP/통신 수렴 timeout; state와 단계 보존")


def peer_routes_ok(status, expected):
    result = status.get("result", {})
    peers = result.get("bgpPeerStatus", [])
    routes = {r.get("destRange") for r in result.get("bestRoutes", [])}
    return len(peers) == 2 and all(p.get("status") == "UP" for p in peers) and set(expected) <= routes


def run(run_dir):
    run_id = run_dir.parent.name
    inputs = json.loads((run_dir / "work/phase-12.auto.tfvars.json").read_text())
    region, zone = inputs["region"], inputs["zone"]
    onprem_zone = inputs.get("onprem_zone", zone)
    vpc, onprem = f"vpc-demo-{run_id}", f"on-prem-{run_id}"
    outputs = json.loads(subprocess.run(["terraform", f"-chdir={run_dir / 'work'}", "output", "-json"], capture_output=True, text=True, check=True).stdout)
    ips = {k: outputs[k]["value"] for k in ("vpc_primary_ip", "vpc_secondary_ip", "onprem_ip")}
    path = run_dir / "evidence/vpn-progress.json"
    binding = digest(run_dir / "binding.json")
    progress = json.loads(path.read_text()) if path.exists() else {"stage": "new", "binding": binding}
    if progress["binding"] != binding:
        # 새 plan 적용은 이전 증거를 지우지 않고 새 baseline부터 요구한다.
        write_json(run_dir / f"evidence/vpn-progress-{progress['binding'][:12]}.json", progress)
        progress = {"stage": "new", "binding": binding}
    def stage(name):
        progress["stage"] = name
        write_json(path, progress)
    def tunnel_status(name):
        return cloud("compute", "vpn-tunnels", "describe", name, f"--region={region}").get("status")
    def ping(vm, vm_zone, ip):
        # ping 1=정상적인 미응답, SSH 255/인증/timeout은 expected failure가 아니다.
        script = f"ping -c 2 -W 3 '{ip}' >/dev/null 2>&1; rc=$?; printf 'PING_RC=%s\\n' \"$rc\""
        result = subprocess.run(["gcloud", "compute", "ssh", vm, f"--zone={vm_zone}", f"--project={inputs['project_id']}",
                                 "--tunnel-through-iap", "--quiet", f"--command={script}"], capture_output=True, text=True, timeout=60, check=True)
        if "PING_RC=0" in result.stdout:
            return True
        if "PING_RC=1" in result.stdout:
            return False
        raise ValueError("guest ping 진단 누락/명령 오류")
    if progress["stage"] == "new":
        poll(lambda: all(tunnel_status(f"{side}-tunnel{n}-{run_id}") == "ESTABLISHED" for side in ("vpc-demo", "on-prem") for n in (0, 1)), 900)
        poll(lambda: peer_routes_ok(cloud("compute", "routers", "get-status", f"{vpc.replace('vpc-demo-', 'vpc-demo-router1-')}", f"--region={region}"), ["192.168.1.0/24"]) and
             peer_routes_ok(cloud("compute", "routers", "get-status", f"on-prem-router1-{run_id}", f"--region={region}"), ["10.1.1.0/24", "10.2.1.0/24"]))
        progress["baseline_tunnels"] = 4
        progress["tunnel_ids"] = {f"{side}-tunnel{n}-{run_id}": str(cloud("compute", "vpn-tunnels", "describe", f"{side}-tunnel{n}-{run_id}", f"--region={region}")["id"])
                                  for side in ("vpc-demo", "on-prem") for n in (0, 1)}
        stage("baseline")
    if progress["stage"] == "baseline":
        cloud("compute", "networks", "update", vpc, "--bgp-routing-mode=REGIONAL")
        poll(lambda: ping(f"on-prem-instance1-{run_id}", onprem_zone, ips["vpc_primary_ip"]))
        poll(lambda: not ping(f"on-prem-instance1-{run_id}", onprem_zone, ips["vpc_secondary_ip"]))
        stage("regional-observed")
    if progress["stage"] == "regional-observed":
        cloud("compute", "networks", "update", vpc, "--bgp-routing-mode=GLOBAL")
        poll(lambda: ping(f"on-prem-instance1-{run_id}", onprem_zone, ips["vpc_secondary_ip"]))
        poll(lambda: ping(f"vpc-demo-instance1-{run_id}", zone, ips["onprem_ip"]))
        progress["regional_to_global"] = True
        stage("global-observed")
    fault = f"vpc-demo-tunnel0-{run_id}"
    if progress["stage"] == "global-observed":
        progress["deleted_tunnel"] = fault
        stage("fault-requested") # 삭제 요청 전에 기록해 중단 직후에도 같은 단계에서 재개한다.
    if progress["stage"] in ("fault-requested", "verified"):
        listed = cloud("compute", "vpn-tunnels", "list", f"--filter=name={fault}")
        if listed:
            if len(listed) != 1 or listed[0].get("name") != fault:
                raise ValueError("장애 주입 대상 tunnel 소유권 불일치")
            if str(listed[0].get("id")) != progress.get("tunnel_ids", {}).get(fault):
                raise ValueError("baseline 이후 tunnel identity 변경: 삭제하지 않음")
            cloud("compute", "vpn-tunnels", "delete", fault, f"--region={region}")
        poll(lambda: all(tunnel_status(f"{side}-tunnel1-{run_id}") == "ESTABLISHED" for side in ("vpc-demo", "on-prem")))
        poll(lambda: ping(f"on-prem-instance1-{run_id}", onprem_zone, ips["vpc_primary_ip"]))
        poll(lambda: ping(f"on-prem-instance1-{run_id}", onprem_zone, ips["vpc_secondary_ip"]))
        stage("verified")
    else:
        raise ValueError("알 수 없는 VPN 재개 단계")
    details = ["VPC와 두 리전 subnet/VM", "별도 on-prem VPC와 VM", "양쪽 HA gateway/router",
               "저장 baseline의 양쪽4터널 ESTABLISHED", "양쪽 BGP2세션 UP·예상 원격 prefix",
               "REGIONAL 교차리전 미응답→GLOBAL 성공 전이·양방향 ping", "tunnel0 삭제 후 살아 있는 경로의 두 리전 ping",
               "명시적 plan-destroy/destroy 승인 대기: 정리 완료 아님", "baseline/routing/failover 단계 증거"]
    write_json(run_dir / "evidence/phase-12-machine.json", {"phase": "12", "run_id": run_id,
        "tasks": {f"task-{i}": {"status": "manual-boundary" if i == 8 else "passed", "detail": d} for i, d in enumerate(details, 1)},
        "lab_completion": {"complete": False, "destroy_pending": True},
        "failover_probe": True, "regional_to_global": True,
        "risks": ["원문 장애 실험으로 tunnel0 하나가 삭제된 degraded 상태; 복원은 새 replan/apply 승인", "PSK/state는 ignored 경로에 보존·과금 지속"]})


if __name__ == "__main__":
    try:
        run(Path(sys.argv[1]))
    except Exception as error:
        print(f"FAIL: {error if not isinstance(error, subprocess.SubprocessError) else 'VPN CLI/guest 실패; 원문은 보존하고 전체 삭제하지 않음'}", file=sys.stderr)
        raise SystemExit(1)
