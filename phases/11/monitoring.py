#!/usr/bin/env python3
"""Monitoring 대상별 구성·최근 실제 성공과 비활성화 전이를 검사한다."""
from datetime import datetime, timedelta, timezone
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import urllib.parse

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "lib/harness"))
from advanced import API, latest_uptime_ok, write_json


def check_configuration(dashboard, policy, group, uptime, names, run_id, instance_ids):
    compact = lambda value: re.sub(r"\s+", "", value)
    metric = 'metric.type="compute.googleapis.com/instance/cpu/utilization" AND resource.type="gce_instance"'
    expected_filters = {compact(f'{metric} AND resource.labels.instance_id="{i}"') for i in instance_ids[:2]}
    conditions = [c.get("conditionThreshold", {}) for c in policy.get("conditions", [])]
    if len(expected_filters) != 2 or policy.get("combiner") != "AND" or len(conditions) != 2 or any(
        c.get("thresholdValue") != 0.2 or c.get("duration") != "60s" or c.get("comparison") != "COMPARISON_GT"
        for c in conditions) or {compact(c.get("filter", "")) for c in conditions} != expected_filters:
        raise ValueError("서로 다른 VM1/2·AND·20%·60초 alert 조건 불일치")
    if compact(group.get("filter", "")) != compact(f'resource.metadata.user_labels.run="{run_id}"'):
        raise ValueError("Monitoring group run 필터 불일치")
    resource = uptime.get("resourceGroup", {})
    http = uptime.get("httpCheck", {})
    if uptime.get("period") != "60s" or resource.get("resourceType") != "INSTANCE" or resource.get("groupId") not in (
        names["group"], names["group"].rsplit("/", 1)[-1]) or http.get("port") != 80 or http.get("path") != "/" or http.get("useSsl", False):
        raise ValueError("uptime 대상 group·HTTP80/경로/주기 불일치")
    filters = [dataset.get("timeSeriesQuery", {}).get("timeSeriesFilter", {})
               for tile in dashboard.get("mosaicLayout", {}).get("tiles", [])
               for dataset in tile.get("widget", {}).get("xyChart", {}).get("dataSets", [])]
    expected_chart = compact(f'{metric} AND metadata.user_labels.run="{run_id}"')
    if not any(compact(item.get("filter", "")) == expected_chart and
               item.get("aggregation", {}).get("alignmentPeriod") == "60s" and
               item.get("aggregation", {}).get("perSeriesAligner") == "ALIGN_MEAN" for item in filters):
        raise ValueError("dashboard 현재 run CPU/60초 평균 차트 누락")


def run(run_dir, project):
    api = API()
    run_id = run_dir.parent.name
    outputs = json.loads(subprocess.run(["terraform", f"-chdir={run_dir / 'work'}", "output", "-json"],
                                       check=True, capture_output=True, text=True).stdout)
    names = {key: outputs[f"{key}_name"]["value"] for key in ("dashboard", "policy", "group", "uptime")}
    base = f"https://monitoring.googleapis.com/v3/projects/{project}"
    def get_name(name):
        # Terraform dashboard id는 projects/... 형식; 다른 리소스 name도 동일하게 정규화.
        return api.request("GET", "https://monitoring.googleapis.com/v3/" + name)
    dashboard, policy, group, uptime = [get_name(names[key]) for key in ("dashboard", "policy", "group", "uptime")]
    check_configuration(dashboard, policy, group, uptime, names, run_id, outputs["instance_ids"]["value"])
    expected = set(str(value) for value in outputs["instance_ids"]["value"])
    end = time.monotonic() + 600
    cpu = checks = None
    while time.monotonic() < end:
        members = api.pages("https://monitoring.googleapis.com/v3/" + names["group"] + "/members", "members")
        actual = {m.get("labels", {}).get("instance_id") for m in members["members"]}
        now = datetime.now(timezone.utc)
        def series(filter_text):
            query = urllib.parse.urlencode({"filter": filter_text, "interval.startTime": (now - timedelta(minutes=10)).isoformat(),
                                           "interval.endTime": now.isoformat()})
            return api.pages(f"{base}/timeSeries?{query}", "timeSeries")
        cpu = series(f'metric.type="compute.googleapis.com/instance/cpu/utilization" AND resource.type="gce_instance" AND metadata.user_labels.run="{run_id}"')
        checks = series(f'metric.type="monitoring.googleapis.com/uptime_check/check_passed" AND metric.labels.check_id="{names["uptime"].rsplit("/", 1)[-1]}"')
        cpu_ids = {s.get("resource", {}).get("labels", {}).get("instance_id") for s in cpu.get("timeSeries", []) if s.get("points")}
        if actual == expected and cpu_ids == expected and latest_uptime_ok(checks, expected):
            break
        time.sleep(15)
    else:
        raise ValueError("VM3개 exact membership/CPU point/최근 uptime true가 제한 시간 내 수렴하지 않음")
    before = run_dir / "evidence/alert-before-disable.json"
    if policy.get("enabled") is True:
        write_json(before, {"name": names["policy"], "enabled": True})
        api.request("PATCH", "https://monitoring.googleapis.com/v3/" + names["policy"] + "?updateMask=enabled", {"enabled": False})
    elif not before.exists() or json.loads(before.read_text()) != {"name": names["policy"], "enabled": True}:
        raise ValueError("enabled→disabled 전이 증거 없음; replan/apply로 baseline부터 실행")
    if get_name(names["policy"]).get("enabled") is not False:
        raise ValueError("alert 비활성화 readback 실패")
    details = ["nginx VM3개와 현재 CPU 측정값", "실제 dashboard CPU chart 구성", "서로 다른 VM의20%/60초 AND 조건; 이메일 미발송",
               "VM3개 exact group membership", "VM3개 모든 수집 checker의 최신 uptime boolValue=true",
               "저장 baseline과 실제 enabled=false 전이", "Monitoring 구성·시계열·비활성화 증거 검토"]
    write_json(run_dir / "evidence/phase-11-machine.json", {"phase": "11", "run_id": run_id,
        "tasks": {f"task-{i}": {"status": "passed", "detail": d} for i, d in enumerate(details, 1)},
        "cpu_instances": len(expected), "uptime_series": len(checks["timeSeries"]),
        "risks": ["이메일 채널 생성·전송과 UI Metrics Explorer 조작은 수동 경계; machine pass가 이를 대신하지 않음", "MCP 연결은 선택형 별도 검증"]})


if __name__ == "__main__":
    try:
        run(Path(sys.argv[1]), os.environ["GCP_PROJECT_ID"])
    except Exception as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
