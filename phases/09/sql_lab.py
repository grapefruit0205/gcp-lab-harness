#!/usr/bin/env python3
"""Phase 09 준비·SQL/guest 검증·잔여 조회. HTTP/CLI 오류 원문과 비밀은 출력하지 않는다."""
import argparse
import hashlib
import ipaddress
import json
import os
from pathlib import Path
import re
import secrets
import shlex
import signal
import subprocess
import sys
import tempfile
import time
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode, urlsplit
from urllib.request import Request, HTTPRedirectHandler, build_opener

from guest_install import REASONS, STAGES

HERE = Path(__file__).resolve().parent
SERVICES = {"sqladmin.googleapis.com", "servicenetworking.googleapis.com", "iap.googleapis.com"}
TYPES = {
    "google_compute_network.sql", "google_compute_subnetwork.sql",
    "google_compute_global_address.private_services", "google_service_networking_connection.private_services",
    "google_compute_firewall.iap", "google_compute_firewall.http",
    "google_service_account.proxy", "google_service_account.private",
    "google_project_iam_member.proxy_client", "google_sql_database_instance.wordpress",
    "google_sql_database.wordpress", "google_compute_instance.proxy", "google_compute_instance.private",
} | {'google_project_service.required["' + service + '"]' for service in SERVICES}


class LabError(Exception):
    pass


def require(value, message):
    if not value:
        raise LabError(message)


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(dir=path.parent, prefix=".p09-")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump(value, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *args):
        return None


def api(method, url, data=None):
    require(urlsplit(url).scheme == "https" and
            urlsplit(url).netloc in {"sqladmin.googleapis.com", "www.googleapis.com", "cloudresourcemanager.googleapis.com"},
            "API endpoint 범위 밖")
    token = os.environ.get("GOOGLE_OAUTH_ACCESS_TOKEN")
    require(token, "사용자 OAuth token 없음")
    body = json.dumps(data).encode() if data is not None else None
    request = Request(url, data=body, method=method,
                      headers={"Authorization": "Bearer " + token, "Content-Type": "application/json"})
    try:
        with build_opener(NoRedirect()).open(request, timeout=30) as response:
            content = response.read(2 * 1024 * 1024 + 1)
        require(len(content) <= 2 * 1024 * 1024, "API 응답 크기 초과")
        return json.loads(content)
    except HTTPError as error:
        # 원문/임의 문자열은 출력하지 않는다. 다음 장애에서도 안전한 분류는 남긴다.
        category, status, reason = 'unknown', 'unknown', 'unknown'
        try:
            raw = error.read(65537)
            payload = json.loads(raw) if len(raw) <= 65536 else {}
            details = payload.get('error', {}) if isinstance(payload, dict) else {}
            if isinstance(details, dict):
                if details.get('status') in {'INVALID_ARGUMENT', 'PERMISSION_DENIED', 'NOT_FOUND',
                                             'FAILED_PRECONDITION', 'INTERNAL', 'UNAVAILABLE'}:
                    status = details['status']
                errors = details.get('errors', [])
                for item in errors if isinstance(errors, list) else []:
                    if isinstance(item, dict) and item.get('reason') in {'invalid', 'badRequest', 'forbidden',
                                                                       'notFound', 'backendError', 'conditionNotMet'}:
                        reason = item['reason']
                message = details.get('message', '')
                message = message if isinstance(message, str) else ''
                # 비밀 내용에 password/role 같은 단어가 있어도 오류 원인으로 오분류하지 않는다.
                for secret_value in [token, data.get('password') if isinstance(data, dict) else None]:
                    if isinstance(secret_value, str) and secret_value:
                        message = message.replace(secret_value, '')
                message = message.lower()
                if 'password' in message and 'role' in message:
                    category = 'password-role-combination'
                elif 'type' in message and ('required' in message or 'must' in message):
                    category = 'user-type-required'
                elif 'role' in message and ('does not exist' in message or 'not found' in message):
                    category = 'role-not-found'
                elif 'system user' in message:
                    category = 'system-user-role-denied'
        except (ValueError, OSError, TypeError):
            pass
        raise LabError(f"API HTTP {error.code}; status={status}; reason={reason}; category={category}; 원문 생략") from None
    except (URLError, TimeoutError, OSError):
        raise LabError("API 네트워크/시간 초과; 성공이나 리소스 부재로 처리하지 않음") from None


def run_command(command, *, data=None, timeout=120):
    try:
        result = subprocess.run(command, input=data, capture_output=True, timeout=timeout, check=False)
    except (OSError, subprocess.SubprocessError):
        raise LabError("CLI/guest 시작 실패 또는 시간 초과; 원문 생략") from None
    require(result.returncode == 0, f"CLI/guest 실행 실패(exit={result.returncode}); 비밀 보호를 위해 원문 생략")
    require(len(result.stdout) <= 4 * 1024 * 1024, "CLI 응답 크기 초과")
    return result.stdout


def cloud(inputs, *arguments):
    return json.loads(run_command(["gcloud", *arguments, "--project=" + inputs["project_id"],
                                   "--account=" + inputs["runner"], "--format=json", "--quiet"]))


def validate_inputs(inputs):
    require(bool(re.fullmatch(r"[a-z0-9][a-z0-9-]{6,18}[a-z0-9]", inputs.get("run_id", ""))), "run ID 오류")
    require(bool(re.fullmatch(r"[a-z][a-z0-9-]{4,28}[a-z0-9]", inputs.get("project_id", ""))), "project ID 오류")
    require(bool(re.fullmatch(r"[a-z]+-[a-z]+[0-9]", inputs.get("region", ""))), "region 오류")
    require(inputs.get("zone", "").startswith(inputs["region"] + "-"), "zone/region 불일치")
    cidr = ipaddress.ip_network(inputs["client_source_cidr"], strict=True)
    require(cidr.version == 4 and cidr.prefixlen == 32 and cidr.network_address.is_global, "클라이언트 공개 IPv4 /32만 허용")
    require(bool(re.fullmatch(r"[^ \t\r\n@]+@[^ \t\r\n@]+\.[^ \t\r\n@]+", inputs.get("runner", ""))) and
            not inputs["runner"].endswith(".gserviceaccount.com"), "실제 사용자 계정 필요")
    for name, item in read_json(HERE / "assets.json").items():
        require(inputs[name + "_url"] == item["url"] and inputs[name + "_sha256"] == item["sha256"],
                "승인 artifact lock 불일치")


def prepare(args):
    cidr = args.cidr
    if not cidr:
        cidr = run_command(["curl", "--proto", "=https", "--fail", "--silent", "--show-error",
                            "--max-time", "15", "https://checkip.amazonaws.com/"]).decode().strip() + "/32"
    inputs = dict(project_id=args.project, region=args.region, zone=args.zone, run_id=args.run,
                  runner=args.account, client_source_cidr=cidr)
    for name, item in read_json(HERE / "assets.json").items():
        # 공식 HTTPS에서 가져온 바이트를 고정 hash와 비교. 비밀/실행 artifact를 state에 넣지 않음.
        digest = hashlib.sha256()
        with tempfile.TemporaryDirectory(prefix="p09-artifact-") as directory:
            path = Path(directory) / "download"
            run_command(["curl", "--proto", "=https", "--proto-redir", "=https", "--tlsv1.2", "--fail",
                         "--location", "--silent", "--show-error", "--max-time", "180",
                         "--max-filesize", "134217728", item["url"], "-o", str(path)], timeout=200)
            with path.open("rb") as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                    digest.update(chunk)
        require(digest.hexdigest() == item["sha256"], "설치 파일 SHA256 불일치: " + name)
        inputs[name + "_url"], inputs[name + "_sha256"] = item["url"], item["sha256"]
    validate_inputs(inputs)
    return inputs


def expected_names(inputs):
    run, project = inputs["run_id"], inputs["project_id"]
    return {
        "vm": {f"wordpress-proxy-{run}", f"wordpress-private-{run}"},
        "disk": {f"wordpress-proxy-{run}", f"wordpress-private-{run}"},
        "network": {f"p09-net-{run}"}, "subnet": {f"p09-subnet-{run}"},
        "address": {f"p09-psa-{run}"}, "firewall": {f"p09-iap-ssh-{run}", f"p09-http-{run}"},
        "sa": {f"p09-p-{run}@{project}.iam.gserviceaccount.com", f"p09-d-{run}@{project}.iam.gserviceaccount.com"},
        "sql": {f"wordpress-db-{run}"},
    }


def inventory(inputs, *, sql_enabled=True):
    commands = {"vm": ["compute", "instances", "list"], "disk": ["compute", "disks", "list"],
                "network": ["compute", "networks", "list"], "subnet": ["compute", "networks", "subnets", "list"],
                "address": ["compute", "addresses", "list"], "firewall": ["compute", "firewall-rules", "list"],
                "sa": ["iam", "service-accounts", "list"], "sql": ["sql", "instances", "list"]}
    names, result = expected_names(inputs), {}
    for kind, command in commands.items():
        if kind == "sql" and not sql_enabled:
            continue
        rows = cloud(inputs, *command)
        require(isinstance(rows, list), "리소스 목록 형식 오류")
        result[kind] = [row for row in rows if row.get("email" if kind == "sa" else "name") in names[kind]]
    return result


def preflight(inputs):
    enabled = cloud(inputs, "services", "list", "--enabled")
    enabled = {row["config"]["name"] for row in enabled}
    require({"compute.googleapis.com", "iam.googleapis.com", "cloudresourcemanager.googleapis.com",
             "serviceusage.googleapis.com", "oslogin.googleapis.com"} <= enabled, "기본 Compute/IAM/OS Login API 준비 필요")
    rows = inventory(inputs, sql_enabled="sqladmin.googleapis.com" in enabled)
    require(not any(rows.values()), "기존 run 이름 리소스와 충돌")
    permissions = ["compute.instances.create", "compute.networks.create", "compute.firewalls.create",
                   "iam.serviceAccounts.create", "iam.serviceAccounts.actAs", "resourcemanager.projects.setIamPolicy",
                   "serviceusage.services.enable", "cloudsql.instances.create"]
    allowed = api("POST", "https://cloudresourcemanager.googleapis.com/v1/projects/" +
                  inputs["project_id"] + ":testIamPermissions", {"permissions": permissions})
    require(set(permissions) <= set(allowed.get("permissions", [])), "Phase09 생성·API·IAM 권한 부족")
    region = cloud(inputs, "compute", "regions", "describe", inputs["region"])
    quotas = {q["metric"]: q for q in region.get("quotas", [])}
    for metric, needed in (("CPUS", 4), ("IN_USE_ADDRESSES", 2)):
        require(metric in quotas and quotas[metric]["limit"] - quotas[metric]["usage"] >= needed,
                "Compute region quota 부족: " + metric)


def guard_plan(plan, inputs):
    validate_inputs(inputs)
    resources = {r["address"]: r for r in plan.get("resource_changes", []) if r.get("mode") != "data"}
    require(set(resources) == TYPES and all(r["change"]["actions"] in (["create"], ["update"], ["no-op"])
                                           for r in resources.values()),
            "승인 범위는 전용 리소스16개 create/update/no-op; 삭제/교체 금지")
    limit = int(os.environ.get('GCP_MAX_RESOURCES_PER_PHASE', '16'))
    require(sum(r['change']['actions'] != ['no-op'] for r in resources.values()) <= limit, '리소스 상한 초과')
    after = {address: row["change"]["after"] for address, row in resources.items()}
    for address, row in after.items():
        require(row.get("project", inputs["project_id"]) == inputs["project_id"], "다른 project resource")
        if address.startswith("google_project_service."):
            require(row["service"] in SERVICES and row["disable_on_destroy"] is False, "공통 API 삭제 금지")
    sql = after["google_sql_database_instance.wordpress"]
    settings = sql["settings"][0]
    require(sql["name"] == "wordpress-db-" + inputs["run_id"] and sql["region"] == inputs["region"] and
            sql["database_version"] == "MYSQL_8_0" and sql["deletion_protection"] is False, "SQL plan 불일치")
    require(settings["tier"] == "db-custom-1-3840" and settings["edition"] == "ENTERPRISE" and
            settings["disk_size"] == 10 and settings["disk_autoresize"] is False and
            settings["availability_type"] == "ZONAL" and
            settings["backup_configuration"][0]["enabled"] is False, "SQL 비용/backup 범위 불일치")
    require(settings["ip_configuration"][0]["ipv4_enabled"] is True and
            not settings["ip_configuration"][0].get("authorized_networks"), "SQL Authorized Networks 금지")
    require(after["google_compute_firewall.http"]["source_ranges"] == [inputs["client_source_cidr"]] and
            after["google_compute_firewall.iap"]["source_ranges"] == ["35.235.240.0/20"], "firewall source 불일치")
    for name in ("proxy", "private"):
        vm = after["google_compute_instance." + name]
        require(vm["name"] == f"wordpress-{name}-" + inputs["run_id"] and vm["zone"] == inputs["zone"] and
                vm["machine_type"] == "e2-micro", "VM 범위 불일치")
    require(after["google_project_iam_member.proxy_client"]["role"] == "roles/cloudsql.client", "과도한 SA 역할")


def guard_state(state, inputs):
    root = state.get("values", {}).get("root_module", {})
    require(not root.get("child_modules"), "예상 밖 child module")
    plan_names = {
        "google_compute_network.sql": "p09-net-", "google_compute_subnetwork.sql": "p09-subnet-",
        "google_compute_global_address.private_services": "p09-psa-",
        "google_compute_firewall.iap": "p09-iap-ssh-", "google_compute_firewall.http": "p09-http-",
        "google_sql_database_instance.wordpress": "wordpress-db-",
        "google_compute_instance.proxy": "wordpress-proxy-", "google_compute_instance.private": "wordpress-private-",
    }
    for row in root.get("resources", []):
        if row.get("mode") == "data":
            continue
        address, value = row["address"], row["values"]
        require(address in TYPES and value.get("project", inputs["project_id"]) == inputs["project_id"], "state 소유 범위 밖")
        if address in plan_names:
            require(value["name"] == plan_names[address] + inputs["run_id"], "state resource name 불일치")
        elif address.startswith("google_service_account."):
            prefix = "p09-p-" if address.endswith(".proxy") else "p09-d-"
            require(value["account_id"] == prefix + inputs["run_id"], "state SA 불일치")
        elif address == "google_project_iam_member.proxy_client":
            require(value["role"] == "roles/cloudsql.client" and
                    value["member"] == "serviceAccount:p09-p-" + inputs["run_id"] + "@" +
                    inputs["project_id"] + ".iam.gserviceaccount.com", "state IAM 불일치")
        elif address == "google_sql_database.wordpress":
            require(value["name"] == "wordpress" and value["instance"] == "wordpress-db-" + inputs["run_id"], "state DB 불일치")
        elif address == "google_service_networking_connection.private_services":
            require(value["network"].endswith("/projects/" + inputs["project_id"] + "/global/networks/p09-net-" + inputs["run_id"]) or
                    value["network"] == "projects/" + inputs["project_id"] + "/global/networks/p09-net-" + inputs["run_id"], "state PSA 불일치")
        elif address.startswith("google_project_service."):
            require(value["service"] in SERVICES and value["disable_on_destroy"] is False, "state 공통 API 삭제 위험")


def identities(rows, inputs):
    result = {}
    labels = {"harness": "gcp-lab-harness", "phase": "09", "run": inputs["run_id"]}
    for kind, items in rows.items():
        for row in items:
            name = row.get("email") if kind == "sa" else row["name"]
            if kind in {"vm", "sql"}:
                actual = row.get("settings", {}).get("userLabels", {}) if kind == "sql" else row.get("labels", {})
                require(all(actual.get(k) == v for k, v in labels.items()), "Cloud run 소유 label 불일치")
            unique = row.get("uniqueId") or row.get("id") or row.get("createTime")
            require(unique, "리소스 identity 누락: " + kind)
            result[kind + ":" + name] = str(unique)
    return result


def resource_keys(address, inputs):
    run, project = inputs['run_id'], inputs['project_id']
    fixed = {
        'google_compute_network.sql': ['network:p09-net-' + run],
        'google_compute_subnetwork.sql': ['subnet:p09-subnet-' + run],
        'google_compute_global_address.private_services': ['address:p09-psa-' + run],
        'google_compute_firewall.iap': ['firewall:p09-iap-ssh-' + run],
        'google_compute_firewall.http': ['firewall:p09-http-' + run],
        'google_sql_database_instance.wordpress': ['sql:wordpress-db-' + run],
    }
    for role, prefix in (('proxy', 'p'), ('private', 'd')):
        fixed['google_compute_instance.' + role] = [kind + ':wordpress-' + role + '-' + run for kind in ('vm', 'disk')]
        fixed['google_service_account.' + role] = ['sa:p09-' + prefix + '-' + run + '@' + project + '.iam.gserviceaccount.com']
    return fixed.get(address, [])


def planned_created_keys(plan, inputs):
    return {key for row in plan.get('resource_changes', []) if row['change']['actions'] == ['create']
            for key in resource_keys(row['address'], inputs)}


def allowed_recreated(inputs, run_dir, current):
    baseline_path = run_dir / 'plan-baseline.json'
    receipt_path = run_dir / 'apply-started.json'
    if not baseline_path.exists() or not receipt_path.exists():
        return set()
    receipt = read_json(receipt_path)
    require(receipt['bundle_sha256'] == hashlib.sha256((run_dir / 'plan-bundle.json').read_bytes()).hexdigest(),
            '현재 계획 apply 시작 기록 없음')
    baseline = read_json(baseline_path)
    # 살아남은 리소스는 고유 identity를 그대로 유지해야 한다.
    require(all(current.get(key) == value for key, value in baseline['identities'].items()), '기존 리소스 identity 변경/누락')
    state = json.loads(run_command(['terraform', '-chdir=' + str(run_dir / 'work'), 'show', '-json']))
    guard_state(state, inputs)
    state_keys = {key for row in state.get('values', {}).get('root_module', {}).get('resources', [])
                  for key in resource_keys(row['address'], inputs)}
    # 승인된 create 대상이면서 apply가 state에 기록한 항목만 새 identity를 허용한다.
    return set(baseline['created_keys']) & state_keys


def baseline_identities(run_dir):
    path = run_dir / 'plan-baseline.json'
    if not path.exists():
        return {}
    expected = [a['target'] for a in read_json(run_dir / 'action-plan.json')['actions'] if a['id'] == 'plan-baseline']
    require(expected == [hashlib.sha256(path.read_bytes()).hexdigest()], 'baseline 승인 hash 불일치')
    return read_json(path)['identities']


def owned(inputs, run_dir, *, record=False):
    rows = inventory(inputs)
    current = identities(rows, inputs)
    path = run_dir / "resource-identities.json"
    if path.exists():
        recorded = read_json(path)
        changed = {key for key, value in current.items() if recorded.get(key) != value}
        if changed:
            saved = baseline_identities(run_dir)
            changed -= {key for key in changed if saved.get(key) == current[key]}
        if changed:
            require(changed <= allowed_recreated(inputs, run_dir, current), '승인/state 밖 동명 재생성; 중단')
    elif record:
        require(set(current) <= allowed_recreated(inputs, run_dir, current), 'apply 승인/state 기록 없는 리소스')
    if record:
        require(all(len(rows[k]) == len(v) for k, v in expected_names(inputs).items()), "apply resource inventory 누락")
        write_json(path, current)
    return rows


def destroyed(inputs, run_dir):
    rows = inventory(inputs)
    require(not any(rows.values()), "Phase09 리소스 잔여; PSA는 Cloud SQL 삭제 후 최대4일 대기 가능")
    policy = cloud(inputs, "projects", "get-iam-policy", inputs["project_id"])
    accounts = expected_names(inputs)["sa"]
    for binding in policy.get("bindings", []):
        for member in binding.get("members", []):
            require(not any(member == "serviceAccount:" + email or
                            member.startswith("deleted:serviceAccount:" + email + "?uid=") for email in accounts),
                    "run SA IAM binding 잔여")
    write_json(run_dir / "evidence/phase-09-destroyed.json",
               {"phase": "09", "run_id": inputs["run_id"], "remaining_owned_resources": 0,
                "common_apis_retained": sorted(SERVICES)})


def wait_sql_operation(base, operation, deadline, stage):
    require(isinstance(operation, dict) and bool(re.fullmatch(r'[a-zA-Z0-9-]+', operation.get('name', ''))),
            'SQL ' + stage + ' operation name 오류')
    while True:
        if operation.get('status') == 'DONE':
            require(not operation.get('error'), 'SQL ' + stage + ' operation 실패; 원문 생략')
            return
        require(time.monotonic() < deadline, 'SQL ' + stage + ' operation timeout')
        time.sleep(3)
        operation = api('GET', base + '/operations/' + operation['name'])


def set_password(inputs, password):
    base = "https://sqladmin.googleapis.com/v1/projects/" + inputs["project_id"]
    users_url = base + '/instances/wordpress-db-' + inputs['run_id'] + '/users'
    # Google provider는 생성 직후 기본 root@%를 삭제한다. 비밀번호 갱신만으로
    # 계정/권한 준비가 끝났다고 판단하지 않고, 없는 계정은 insert로 생성한다.
    listing = api('GET', users_url)
    require(isinstance(listing, dict) and isinstance(listing.get('items', []), list) and
            not listing.get('nextPageToken'), 'SQL 사용자 목록 불완전; 권한 변경 중단')
    roots = [row for row in listing.get('items', []) if row.get('name') == 'root' and row.get('host') == '%']
    require(len(roots) <= 1 and all(row.get('type', 'BUILT_IN') == 'BUILT_IN' for row in roots),
            '예상 밖 root 계정 형식; 권한 변경 중단')
    user = {'name': 'root', 'host': '%', 'type': 'BUILT_IN'}
    deadline = time.monotonic() + 600
    if roots:
        # 공식 assign-roles 요청처럼 type을 명시한다. 역할과 비밀번호를 한 요청에 섞지 않는다.
        # update는 body.databaseRoles를 무시한다. query로 추가하며 기존 역할을 회수하지 않는다.
        url = users_url + '?' + urlencode({'name': 'root', 'host': '%',
                                           'databaseRoles': ['cloudsqlsuperuser'], 'revokeExistingRoles': 'false'}, doseq=True)
        try:
            operation = api('PUT', url, user)
            wait_sql_operation(base, operation, deadline, 'root-role')
        except LabError as error:
            raise LabError('SQL root-role: ' + str(error)) from None
        require(time.monotonic() < deadline, 'SQL root-password 시작 전 timeout')
        url = users_url + '?' + urlencode({'name': 'root', 'host': '%'})
        try:
            operation = api('PUT', url, {**user, 'password': password})
            wait_sql_operation(base, operation, deadline, 'root-password')
        except LabError as error:
            raise LabError('SQL root-password: ' + str(error)) from None
        mode = 'updated'
    else:
        # 신규 insert는 계정/비밀번호/초기 역할을 함께 생성한다. 기존 사용자는 절대 덮어쓰지 않는다.
        try:
            operation = api('POST', users_url, {**user, 'password': password, 'databaseRoles': ['cloudsqlsuperuser']})
            wait_sql_operation(base, operation, deadline, 'root-create')
        except LabError as error:
            raise LabError('SQL root-create: ' + str(error)) from None
        mode = 'created'
    return mode


def guest(inputs, vm, command, data=None):
    require(vm in expected_names(inputs)["vm"], "guest 대상 범위 밖")
    return run_command(["gcloud", "compute", "ssh", vm, "--project=" + inputs["project_id"],
                        "--account=" + inputs["runner"], "--zone=" + inputs["zone"],
                        "--tunnel-through-iap", "--ssh-flag=-T", "--quiet", "--command=" + command],
                       data=data, timeout=360)


def wait_guest(inputs, vm, command, seconds=900):
    deadline = time.monotonic() + seconds
    while True:
        try:
            return guest(inputs, vm, command)
        except LabError:
            require(time.monotonic() < deadline, "guest readiness timeout")
            time.sleep(10)


def wp_config(password, db_host, public_ip):
    require(bool(re.fullmatch(r"[0-9a-f]{64}", password)), "비밀번호 형식 오류")
    ipaddress.IPv4Address(db_host)
    require(ipaddress.IPv4Address(public_ip).is_global, "frontend 외부 IP 오류")
    values = {"DB_NAME": "wordpress", "DB_USER": "root", "DB_PASSWORD": password, "DB_HOST": db_host,
              "WP_HOME": "http://" + public_ip, "WP_SITEURL": "http://" + public_ip, "DB_CHARSET": "utf8mb4"}
    values.update({key: secrets.token_hex(32) for key in
                   ("AUTH_KEY", "SECURE_AUTH_KEY", "LOGGED_IN_KEY", "NONCE_KEY", "AUTH_SALT",
                    "SECURE_AUTH_SALT", "LOGGED_IN_SALT", "NONCE_SALT")})
    return ("<?php\n" + "".join(f"define('{key}','{value}');\n" for key, value in values.items()) +
            "$table_prefix='wp_';\ndefine('WP_DEBUG',false);\ndefine('DISALLOW_FILE_MODS',true);\n" +
            "if (!defined('ABSPATH')) { define('ABSPATH', __DIR__ . '/'); }\nrequire_once ABSPATH . 'wp-settings.php';\n")


INSTALL_CONFIG = (HERE / 'guest_install.py').read_text(encoding='utf-8')


def install_guest(inputs, run_dir, vm, payload):
    role = 'proxy' if vm == 'wordpress-proxy-' + inputs['run_id'] else 'private'
    require(vm in expected_names(inputs)['vm'], 'guest 대상 범위 밖')
    evidence = run_dir / ('evidence/guest-install-' + role + '.json')
    diagnostic = {'stage': 'transport', 'reason': 'no-valid-result', 'exit_code': None}
    try:
        raw = guest(inputs, vm, 'sudo -n python3 -c ' + shlex.quote(INSTALL_CONFIG), json.dumps(payload).encode())
        try:
            result = json.loads(raw)
        except (ValueError, UnicodeError):
            raise LabError('guest 진단 JSON 오류; 원문 생략') from None
        require(isinstance(result, dict) and set(result) in ({'stage', 'reason', 'exit_code'}, {'stage', 'reason', 'exit_code', 'mysql_errno'}) and
                isinstance(result['stage'], str) and result['stage'] in STAGES and
                isinstance(result['reason'], str) and result['reason'] in REASONS and
                (result['exit_code'] is None or type(result['exit_code']) is int and -128 <= result['exit_code'] <= 255) and
                ('mysql_errno' not in result or result['stage'] == 'db-ready' and
                 type(result['mysql_errno']) is int and 0 <= result['mysql_errno'] <= 65535),
                'guest 진단 허용 목록 불일치; 원문 생략')
        diagnostic = result
        require(result == {'stage': 'complete', 'reason': 'ok', 'exit_code': 0},
                f"guest {role}: stage={result['stage']}, reason={result['reason']}, exit={result['exit_code']}, mysql_errno={result.get('mysql_errno')}")
    finally:
        write_json(evidence, {'phase': '09', 'run_id': inputs['run_id'], 'role': role, **diagnostic})


def verify(inputs, run_dir):
    require((run_dir / "resource-identities.json").exists(), "apply identity 기록 없음")
    require((run_dir / "database-initialized.json").exists(), "apply 직후 root 비밀번호 초기화 기록 없음")
    journal = run_dir / "verification-started.json"
    from recovery import archive
    archive(run_dir, 'verification-attempts', ['verification-started.json', 'evidence/guest-install-proxy.json',
                                            'evidence/guest-install-private.json', 'evidence/phase-09-machine.json'])
    rows = owned(inputs, run_dir)
    require(len(rows["sql"]) == 1 and len(rows["vm"]) == 2, "SQL/VM inventory 누락")
    sql = rows["sql"][0]
    require(sql["state"] == "RUNNABLE" and sql["databaseVersion"] == "MYSQL_8_0" and
            sql["region"] == inputs["region"] and not sql["settings"]["ipConfiguration"].get("authorizedNetworks"),
            "SQL 상태/경로 불일치")
    require(sql["settings"]["tier"] == "db-custom-1-3840", "SQL tier drift")
    addresses = {row["type"]: row["ipAddress"] for row in sql["ipAddresses"]}
    require("PRIMARY" in addresses and "PRIVATE" in addresses and
            ipaddress.IPv4Address(addresses["PRIVATE"]).is_private, "SQL public/private IP 누락")
    vms = {row["name"]: row for row in rows["vm"]}
    proxy, direct = "wordpress-proxy-" + inputs["run_id"], "wordpress-private-" + inputs["run_id"]
    ips = {}
    for vm, row in vms.items():
        require(row["status"] == "RUNNING" and row["zone"].endswith("/" + inputs["zone"]), "VM 상태/zone 불일치")
        ips[vm] = row["networkInterfaces"][0]["accessConfigs"][0]["natIP"]
    write_json(journal, {"phase": "09", "run_id": inputs["run_id"]})
    print("CHECK: SQL root password (memory/API)", flush=True)
    password = secrets.token_hex(32)
    set_password(inputs, password)
    print("CHECK: guest readiness and WordPress config", flush=True)
    wait_guest(inputs, proxy, "test -f /var/lib/p09-wordpress-ready && systemctl is-active apache2 cloud-sql-proxy >/dev/null")
    wait_guest(inputs, direct, "test -f /var/lib/p09-wordpress-ready && systemctl is-active apache2 >/dev/null")
    for vm, host in ((proxy, "127.0.0.1"), (direct, addresses["PRIVATE"])):
        print('CHECK: WordPress installer ' + ('proxy' if vm == proxy else 'private'), flush=True)
        payload = {"run_id": inputs['run_id'], "config": wp_config(password, host, ips[vm]), "install": vm == proxy,
                   "url": "http://" + ips[vm], "admin_password": secrets.token_hex(32),
                   "db_host": host, "db_password": password}
        install_guest(inputs, run_dir, vm, payload)
    password = None
    print("CHECK: proxy/direct SQL shared marker", flush=True)
    wp = "cd /var/www/html && sudo -u www-data wp "
    marker = "phase09-" + inputs["run_id"]
    queries = ["CREATE TABLE IF NOT EXISTS harness_probe (id INT PRIMARY KEY, marker VARCHAR(64))",
               "INSERT INTO harness_probe VALUES (1, '" + marker + "') ON DUPLICATE KEY UPDATE marker=VALUES(marker)"]
    # WordPress의 DB 연결을 그대로 사용한다. mysql 하위 프로세스의 비밀번호 인자를 만들지 않는다.
    code = "global $wpdb; " + " ".join("if (false === $wpdb->query(" + json.dumps(query) + ")) { exit(1); }" for query in queries)
    guest(inputs, proxy, wp + "eval " + shlex.quote(code))
    code = 'global $wpdb; echo $wpdb->get_var("SELECT marker FROM harness_probe WHERE id=1");'
    require(guest(inputs, direct, wp + "eval " + shlex.quote(code)).decode().strip() == marker,
            "private direct SQL marker 불일치")
    unit = guest(inputs, proxy, "systemctl cat cloud-sql-proxy.service").decode()
    require("--address=127.0.0.1 --port=3306" in unit and "--private-ip" not in unit and
            sql["connectionName"] in unit, "Proxy public-default/connection 불일치")
    print("CHECK: both WordPress HTTP bodies and SQL-backed probes", flush=True)
    probe_name = "harness-" + inputs["run_id"] + ".php"
    probe = ("<?php require __DIR__.'/wp-load.php'; header('Content-Type: application/json');"
             "header('Cache-Control: no-store'); global $wpdb; echo json_encode(array('marker'=>"
             "$wpdb->get_var('SELECT marker FROM harness_probe WHERE id=1'),'path'=>basename(__FILE__)));")
    deployed = []
    try:
        for vm in (proxy, direct):
            deployed.append(vm)  # 응답 유실도 finally 회수 대상
            installer = ("import sys,os; from pathlib import Path; p=Path('/var/www/html/" + probe_name + "'); data=sys.stdin.buffer.read(); "
                         "assert not p.is_symlink(); "
                         "existing=p.exists(); assert not existing or p.read_bytes()==data; "
                         "f=None if existing else os.open(p,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o644); "
                         "os.write(f,data) if f is not None else None; os.close(f) if f is not None else None")
            guest(inputs, vm, "sudo python3 -c " + shlex.quote(installer), probe.encode())
            for path, is_probe in (("/", False), ("/" + probe_name, True)):
                url = "http://" + ips[vm] + path
                try:
                    with build_opener(NoRedirect()).open(url, timeout=30) as response:
                        require(response.status == 200, "WordPress HTTP200 필요")
                        body = response.read(1024 * 1024)
                except (HTTPError, URLError, OSError):
                    raise LabError("WordPress HTTP 직접 응답 실패; redirect를 성공으로 처리하지 않음") from None
                if is_probe:
                    require(json.loads(body) == {"marker": marker, "path": probe_name}, "HTTP SQL-backed marker 불일치")
                else:
                    require(b"GCP Lab" in body and b"wp-content" in body, "WordPress 본문 확인 실패")
    finally:
        failed = False
        for vm in deployed:
            try:
                # 응답 유실/재시도에서도 내용이 정확히 같은 본인 probe만 삭제한다.
                removal = ("import sys; from pathlib import Path; p=Path('/var/www/html/" + probe_name + "'); "
                           "data=sys.stdin.buffer.read(); assert not p.is_symlink(); "
                           "assert not p.exists() or p.read_bytes()==data; p.unlink(missing_ok=True)")
                guest(inputs, vm, "sudo python3 -c " + shlex.quote(removal), probe.encode())
            except LabError:
                failed = True
        require(not failed, "임시 HTTP probe 회수 실패; 환경 보존 후 해당 probe만 점검 필요")
    owned(inputs, run_dir)
    tasks = ["MySQL8 Enterprise 1vCPU/3.75GB RUNNABLE·WordPress DB SQL query",
             "두 VM 고정 artifact/Apache/PHP WordPress HTTP200 본문",
             "Auth Proxy localhost/public-default connection",
             "Proxy SQL marker 생성과 HTTP read",
             "Private IP 직접 SQL·별도 frontend HTTP에서 동일 marker read",
             "6개 Task 데이터 경로 검토; 최종 destroy는 별도"]
    result = {"phase": "09", "run_id": inputs["run_id"],
              "tasks": {f"task-{i}": {"status": "passed", "detail": detail} for i, detail in enumerate(tasks, 1)},
              "lab_completion": {"complete": False, "destroy_pending": True},
              "risks": ["DB secret는 guest wp-config에 유지; 로컬 파일/argv/Git에는 저장하지 않음",
                        "Cloud SQL 삭제 뒤 PSA 정리는 최대4일 지연 가능; 자동 비용 중지/정시 삭제 보장 없음"]}
    write_json(run_dir / "evidence/phase-09-machine.json", result)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=["prepare", "preflight", "identity", "guard-plan", "guard-state",
                                             "record", "owned", "verify", "destroyed"])
    for argument in ("project", "region", "zone", "run", "account", "cidr", "run-dir", "plan", "inputs"):
        parser.add_argument("--" + argument)
    args = parser.parse_args()
    if args.operation == "identity":
        user = api("GET", "https://www.googleapis.com/oauth2/v2/userinfo")
        require(user.get("verified_email") is True and user.get("email", "").lower() == args.account.lower(), "실제 OAuth identity 불일치")
        return
    if args.operation == "prepare":
        print(json.dumps(prepare(args)))
        return
    if args.operation == "preflight":
        inputs = json.load(sys.stdin)
        validate_inputs(inputs)
        preflight(inputs)
        return
    run_dir = Path(args.run_dir) if args.run_dir else None
    inputs = read_json(args.inputs or run_dir / "work/phase-09.auto.tfvars.json")
    validate_inputs(inputs)
    if args.operation == "guard-plan":
        guard_plan(read_json(args.plan), inputs)
    elif args.operation == "guard-state":
        guard_state(json.load(sys.stdin), inputs)
    elif args.operation == "record":
        owned(inputs, run_dir, record=True)
        # apply 완료와 verify 사이에도 기본 root 비밀번호를 방치하지 않는다.
        user_mode = set_password(inputs, secrets.token_hex(32))
        write_json(run_dir / "database-initialized.json", {"phase": "09", "run_id": inputs["run_id"],
                                                          "root_password_initialized": True, "password_persisted": False,
                                                          "root_user_mode": user_mode,
                                                          "requested_database_role": "cloudsqlsuperuser"})
    elif args.operation == "owned":
        owned(inputs, run_dir)
    elif args.operation == "destroyed":
        destroyed(inputs, run_dir)
    elif args.operation == "verify":
        verify(inputs, run_dir)


if __name__ == "__main__":
    os.umask(0o077)
    try:
        import resource
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    except ImportError:
        pass
    def interrupted(signum, frame):
        raise LabError("중단 신호; 리소스/state/로그 보존 후 진단 필요")
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    try:
        main()
    except (LabError, OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print("FAIL: " + (str(error) if isinstance(error, LabError) else "입력/실행 오류; 원문 생략"), file=sys.stderr)
        sys.exit(1)
