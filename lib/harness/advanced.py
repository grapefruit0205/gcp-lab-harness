#!/usr/bin/env python3
"""Phase10–15 공통 무결성/API/판정. Cloud 쓰기는 명시 action에서만 호출한다."""
from __future__ import annotations

import argparse
import hashlib
import ipaddress
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[2]


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest() if Path(path).exists() else "absent"


def write_json(path, value):
    path = Path(path)
    temporary = path.with_suffix(path.suffix + ".tmp")
    with temporary.open("w", encoding="utf-8") as stream:
        os.chmod(temporary, 0o600)
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write("\n")
    temporary.replace(path)


def source_hash(phase):
    files = [p for p in (ROOT / "phases" / phase).rglob("*")
             if p.is_file() and not any(x in p.parts for x in (".terraform", "__pycache__"))
             and (p.suffix in (".sh", ".py", ".tf", ".sql", ".json", ".hcl"))]
    files += [ROOT / "lib/harness" / name for name in
              ("advanced.py", "safe-adapter.sh", "phase-adapter.sh", "terraform.sh", "config.sh", "common.sh")]
    files += [ROOT / "scripts" / name for name in
              ("phase-contract.py", "sanitize-terraform-plan.jq", "preflight-gcp.sh")]
    return hashlib.sha256("\n".join(f"{p.relative_to(ROOT)}:{digest(p)}" for p in sorted(files)).encode()).hexdigest()


def work_hash(work):
    files = [p for p in Path(work).rglob("*") if p.is_file() and
             not any(x in p.parts for x in (".terraform", "__pycache__")) and
             (p.suffix in (".tf", ".sh", ".hcl") or p.name.endswith(".tf.json"))]
    return hashlib.sha256("\n".join(f"{p.relative_to(work)}:{digest(p)}" for p in sorted(files)).encode()).hexdigest()


def binding(run, phase):
    run = Path(run)
    return {"source": source_hash(phase), "work": work_hash(run / "work"),
            "inputs": digest(run / "work" / f"phase-{phase}.auto.tfvars.json"),
            "config": digest(ROOT / "config/harness.env"),
            "account": hashlib.sha256(os.environ["CLOUDSDK_CORE_ACCOUNT"].encode()).hexdigest()}


def guard_plan(plan, allowed, project, run, limit, recovery=False, destroy=False):
    changes = [c for c in plan.get("resource_changes", []) if c.get("mode", "managed") == "managed"]
    if (not changes and not destroy) or len(changes) > limit:
        raise ValueError("계획 리소스 수가 0 또는 상한 초과")
    permitted = [("delete",), ("no-op",)] if destroy else [("create",), ("no-op",)]
    if recovery and not destroy:
        permitted.append(("update",))
    for c in changes:
        change = c["change"]
        if c["type"] not in allowed or tuple(change["actions"]) not in permitted:
            raise ValueError(f"허용되지 않은 type/action: {c['address']} {change['actions']}")
        for value in (change.get("before"), change.get("after")):
            if not value:
                continue
            if value.get("project", project) != project:
                raise ValueError("계획 project 불일치")
            # 대시보드/group, router의 peer/interface는 부모와 state address로 소유권을 묶는다.
            name = value.get("name") or value.get("dataset_id") or value.get("account_id")
            if name and c["type"] not in ("google_compute_router_peer", "google_compute_router_interface",
                                          "google_monitoring_group", "google_monitoring_uptime_check_config",
                                          "google_monitoring_alert_policy", "terraform_data"):
                if run not in name and run.replace("-", "_") not in name:
                    raise ValueError(f"run 소유 이름이 아님: {c['address']}")


class APIError(RuntimeError):
    def __init__(self, status):
        self.status = status
        super().__init__(f"Google API HTTP {status}; 원문/토큰은 출력하지 않음")


class API:
    def request(self, method, url, body=None):
        parsed = urllib.parse.urlparse(url)
        if parsed.scheme != "https" or parsed.hostname not in (
            "monitoring.googleapis.com", "bigquery.googleapis.com", "storage.googleapis.com"):
            raise ValueError("허용되지 않은 Google API URL")
        command = ["gcloud", "auth", "print-access-token"]
        token = subprocess.run(command, check=True, capture_output=True, text=True, timeout=60).stdout.strip()
        request = urllib.request.Request(url, method=method,
                                         data=json.dumps(body).encode() if body is not None else None,
                                         headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"})
        # 인증 헤더를 다른 host로 redirect하지 않는다.
        class NoRedirect(urllib.request.HTTPRedirectHandler):
            def redirect_request(self, *args, **kwargs):
                return None
        try:
            with urllib.request.build_opener(NoRedirect).open(request, timeout=60) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            raise APIError(error.code) from None

    def pages(self, url, field):
        result, seen = [], set()
        current = url
        for _ in range(100):
            data = self.request("GET", current)
            items = data.get(field, [])
            if not isinstance(items, list):
                raise ValueError("API list 응답 형식 불일치")
            result.extend(items)
            token = data.get("nextPageToken")
            if not token:
                return {field: result}
            if token in seen:
                raise ValueError("API pagination token 반복")
            seen.add(token)
            parts = urllib.parse.urlsplit(url)
            query = dict(urllib.parse.parse_qsl(parts.query))
            query["pageToken"] = token
            current = urllib.parse.urlunsplit(parts._replace(query=urllib.parse.urlencode(query)))
        raise ValueError("API pagination 상한 초과")


def healthy_groups(data, expected_groups):
    if len(data) != len(expected_groups):
        return False
    by_group = {row.get("backend", "").rsplit("/", 1)[-1]: row for row in data}
    return set(by_group) == set(expected_groups) and all(
        row.get("status", {}).get("healthStatus") and
        all(h.get("healthState") == "HEALTHY" for h in row["status"]["healthStatus"])
        for row in by_group.values())


def latest_uptime_ok(data, expected_ids):
    ids = set()
    for series in data.get("timeSeries", []):
        instance = series.get("resource", {}).get("labels", {}).get("instance_id")
        if instance not in expected_ids:
            return False
        points = series.get("points", [])
        if not points:
            return False
        latest = max(points, key=lambda p: p.get("interval", {}).get("endTime", ""))
        if latest.get("value", {}).get("boolValue") is not True:
            return False
        ids.add(instance)
    return ids == set(expected_ids)


def inventory(phase, run, project):
    if phase == "10":
        try:
            API().request("GET", f"https://bigquery.googleapis.com/bigquery/v2/projects/{project}/datasets/billing_{run.replace('-', '_')}")
            return ["bigquery_dataset"]
        except APIError as error:
            if error.status == 404:
                return []
            raise
    families = ["networks", "subnets", "firewall-rules", "instances", "disks"]
    families += {"11": [], "12": ["routers", "vpn-gateways", "vpn-tunnels"],
                 "13": ["routers", "images", "instance-templates", "instance-groups", "backend-services",
                        "health-checks", "url-maps", "target-http-proxies", "addresses", "forwarding-rules"],
                 "14": ["routers", "instance-templates", "instance-groups", "backend-services",
                        "health-checks", "addresses", "forwarding-rules"], "15": []}[phase]
    remaining = []
    for family in families:
        result = subprocess.run(["gcloud", "compute", family, "list", f"--project={project}", "--format=json"],
                                check=True, capture_output=True, text=True, timeout=120)
        data = json.loads(result.stdout)
        if not isinstance(data, list):
            raise ValueError("Compute inventory list 형식 불일치")
        remaining.extend(f"{family}/{row['name']}" for row in data if run in row.get("name", "") or
                         row.get("labels", {}).get("run") == run)
    if phase == "11":
        base = f"https://monitoring.googleapis.com/v3/projects/{project}"
        for field in ("dashboards", "alertPolicies", "group", "uptimeCheckConfigs"):
            endpoint = "groups" if field == "group" else field
            data = API().pages(f"{base}/{endpoint}", field)
            remaining.extend(f"{endpoint}/{row['name']}" for row in data[field] if run in row.get("displayName", ""))
        data = json.loads(subprocess.run(["gcloud", "iam", "service-accounts", "list", f"--project={project}", "--format=json"],
                                        capture_output=True, text=True, check=True, timeout=120).stdout)
        remaining.extend(row["email"] for row in data if run in row.get("email", ""))
    return remaining


def finish_verify(run_dir, phase):
    manifest = json.loads((run_dir / "manifest.json").read_text())
    evidence = json.loads((run_dir / f"evidence/phase-{phase}-machine.json").read_text())
    if evidence.get("phase") != phase or evidence.get("run_id") != run_dir.parent.name:
        raise ValueError("검증 evidence phase/run 불일치")
    checks = []
    for task in manifest["source_tasks"]:
        result = evidence.get("tasks", {}).get(task["id"], {})
        status = result.get("status")
        if status != "passed" and not (status == "manual-boundary" and task["classification"] == "manual-boundary"):
            raise ValueError(f"Task 검증 실패/누락: {task['id']}")
        checks.append({"id": task["id"], "status": status, "evidence": result["detail"]})
    manifest.update(status="verified", checks=checks)
    write_json(run_dir / "manifest.json", manifest)
    write_json(run_dir / "command-code-result.json", {
        "phase": f"phase-{phase}", "status": "waiting_extension_review",
        "summary": "자동 검증 완료; 수동 경계/종료 정리는 checks·risks와 구분",
        "session_id": f"gcp-harness-{run_dir.parent.name}-phase-{phase}",
        "commands_run": [f"phases/{phase}/execute.sh verify"],
        "checks": [{"name": c["id"], "status": "skipped" if c["status"] == "manual-boundary" else c["status"], "detail": c["evidence"]} for c in checks],
        "risks": evidence.get("risks", []), "next_action": "extension_review"})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("bind", "check", "guard", "api", "inventory", "health", "uptime", "finish"))
    parser.add_argument("--phase", choices=[str(n) for n in range(10, 16)])
    parser.add_argument("--run-dir", type=Path)
    parser.add_argument("--file", type=Path)
    parser.add_argument("--method", default="GET", choices=["GET", "POST", "PATCH"])
    parser.add_argument("--url")
    parser.add_argument("--field")
    parser.add_argument("--expected", nargs="+")
    parser.add_argument("--recovery", action="store_true")
    parser.add_argument("--destroy", action="store_true")
    args = parser.parse_args()
    if args.command == "finish":
        finish_verify(args.run_dir, args.phase)
    elif args.command in ("bind", "check"):
        current = binding(args.run_dir, args.phase)
        path = args.run_dir / "binding.json"
        if args.command == "bind":
            current["state"] = digest(args.run_dir / "work/terraform.tfstate")
            write_json(path, current)
        else:
            saved = json.loads(path.read_text())
            if any(saved.get(k) != v for k, v in current.items()):
                raise ValueError("승인 후 source/work/input/config/account 변경: 같은 state로 replan 필요")
            if args.recovery and saved["state"] != digest(args.run_dir / "work/terraform.tfstate"):
                raise ValueError("승인 후 state 변경: replan 필요")
    elif args.command == "guard":
        guard_plan(json.loads(args.file.read_text()), json.loads(os.environ["HARNESS_PHASE_ALLOWED_TYPES_JSON"]),
                   os.environ["GCP_PROJECT_ID"], args.run_dir.parent.name,
                   min(int(os.environ["HARNESS_PHASE_RESOURCE_LIMIT"]), int(os.environ["GCP_MAX_RESOURCES_PER_PHASE"])),
                   args.recovery, args.destroy)
    elif args.command == "api":
        api = API()
        data = api.pages(args.url, args.field) if args.field else api.request(
            args.method, args.url, json.loads(args.file.read_text()) if args.file else None)
        json.dump(data, sys.stdout)
    elif args.command == "inventory":
        data = inventory(args.phase, args.run_dir.parent.name, os.environ["GCP_PROJECT_ID"])
        if data:
            raise ValueError(f"run 소유 잔여 리소스 {len(data)}개; 진단 inventory로 확인")
        print("PASS: 조회 성공 및 run 소유 잔여 0 (공통 API 제외)")
    elif args.command in ("health", "uptime"):
        check = healthy_groups if args.command == "health" else latest_uptime_ok
        if not check(json.loads(args.file.read_text()), args.expected):
            raise ValueError(f"{args.command} 대상/실제 성공 값 불일치")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"FAIL: {error if not isinstance(error, subprocess.SubprocessError) else 'CLI 호출 실패; 부재로 취급하지 않음'}", file=sys.stderr)
        raise SystemExit(1)
