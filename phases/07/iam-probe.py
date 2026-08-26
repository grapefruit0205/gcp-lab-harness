#!/usr/bin/env python3
"""Phase 07의 제한된 API probe. 토큰/응답 본문은 증거에 기록하지 않는다."""

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request


class ProbeError(RuntimeError):
    pass


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def request(url, token=None, method="GET", body=None, metadata=False):
    headers = {"Metadata-Flavor": "Google"} if metadata else {}
    if token:
        headers["Authorization"] = "Bearer " + token
    if isinstance(body, dict):
        body = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    elif body is not None:
        headers["Content-Type"] = "text/plain"
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.build_opener(NoRedirect).open(req, timeout=25) as response:
            code, raw = response.status, response.read()
    except urllib.error.HTTPError as error:
        code, raw = error.code, error.read()
    except (urllib.error.URLError, TimeoutError, OSError) as error:
        raise ProbeError("API transport 실패; IAM 거부 증거가 아님") from error
    try:
        return code, json.loads(raw)
    except (ValueError, UnicodeDecodeError):
        return code, raw


def error_text(payload):
    return json.dumps(payload, sort_keys=True) if isinstance(payload, dict) else ""


def infra_denial(payload):
    text = error_text(payload).lower()
    return any(term in text for term in (
        "access_token_scope_insufficient", "insufficient authentication scopes",
        "insufficientpermissions", "service_disabled", "accessnotconfigured",
        "has not been used", "vpc_service_controls", "security_policy_violated",
        "organization's policy", "billing_disabled", "invalid authentication",
    ))


def exact_denial(code, payload, permission, permissions=None):
    """인증/scope/API 실패를 제외하고, 해당 permission의 403만 통과한다."""
    if code != 403 or not isinstance(payload, dict) or infra_denial(payload):
        return False
    if re.search(r"(?<![A-Za-z0-9_.])" + re.escape(permission) + r"(?![A-Za-z0-9_.])",
                 error_text(payload)):
        return True
    # Resource Manager의 일반 403은 같은 principal의 testIamPermissions로 보강한다.
    return isinstance(permissions, list) and all(isinstance(p, str) for p in permissions) and permission not in permissions


def human_email(value):
    return isinstance(value, str) and re.fullmatch(r"[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}", value) and not value.lower().endswith(".gserviceaccount.com")


def user_token(account):
    if not human_email(account):
        raise ProbeError("실제 Google 사용자 이메일만 허용합니다. SA 가장은 대체 경로가 아닙니다.")
    # --account보다 우선하는 외부 token/credential override를 허용하지 않는다.
    for key in ("CLOUDSDK_AUTH_ACCESS_TOKEN", "CLOUDSDK_AUTH_ACCESS_TOKEN_FILE",
                "CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE", "CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT"):
        if os.environ.get(key):
            raise ProbeError("gcloud 인증 override를 해제해야 실제 사용자 두 계정을 검증할 수 있습니다.")
    result = subprocess.run(
        ["gcloud", "auth", "print-access-token", "--quiet", "--account=" + account],
        capture_output=True, text=True, timeout=45, check=False)
    if result.returncode or not result.stdout.strip():
        raise ProbeError("지정된 사용자 로그인이 필요합니다. auth.sh로 브라우저 인증하세요.")
    token = result.stdout.strip()
    code, identity = request("https://www.googleapis.com/oauth2/v2/userinfo", token)
    if code != 200 or not isinstance(identity, dict) or identity.get("email", "").lower() != account.lower() or \
            identity.get("verified_email") is not True:
        raise ProbeError("OAuth 사용자 identity 검증 실패; 다른 계정/가장 token을 사용하지 않습니다.")
    return token


def token_for(args):
    if args.guest:
        base = "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/"
        code, email = request(base + "email", metadata=True)
        if code != 200 or not isinstance(email, bytes) or email.decode().strip() != args.actor:
            raise ProbeError("guest에 연결된 service account가 승인된 workload와 다름")
        code, scopes = request(base + "scopes", metadata=True)
        if code != 200 or not isinstance(scopes, bytes) or \
                "https://www.googleapis.com/auth/cloud-platform" not in scopes.decode().splitlines():
            raise ProbeError("guest cloud-platform scope 누락; IAM 검증 불가")
        code, value = request(base + "token", metadata=True)
        if code != 200 or not isinstance(value, dict) or not value.get("access_token"):
            raise ProbeError("guest metadata token 발급 실패")
        return value["access_token"]
    return user_token(args.actor)


def vm_body(args):
    return {
        "name": args.vm,
        "machineType": f"zones/{args.zone}/machineTypes/e2-micro",
        "labels": {"harness": "gcp-lab-harness", "phase": "07", "run": args.run},
        "disks": [{"boot": True, "autoDelete": True, "type": "PERSISTENT",
                   "initializeParams": {"sourceImage": args.image, "diskName": args.vm,
                                        "diskSizeGb": "10",
                                        "labels": {"harness": "gcp-lab-harness", "phase": "07", "run": args.run},
                                        "diskType": f"zones/{args.zone}/diskTypes/pd-standard"}}],
        "networkInterfaces": [{"subnetwork":
            f"projects/{args.project}/regions/{args.region}/subnetworks/p07-subnet-{args.run}"}],
        "serviceAccounts": [{"email": args.workload,
                             "scopes": ["https://www.googleapis.com/auth/cloud-platform"]}],
        "tags": {"items": ["p07-iam-probe"]},
        "metadata": {"items": [{"key": "enable-oslogin", "value": "TRUE"},
                               {"key": "block-project-ssh-keys", "value": "TRUE"}]},
        "shieldedInstanceConfig": {"enableSecureBoot": True},
    }


def operation(args):
    compute = f"https://compute.googleapis.com/compute/v1/projects/{args.project}"
    storage = f"https://storage.googleapis.com/storage/v1/b/{args.bucket}"
    operations = {
        "project": (f"https://cloudresourcemanager.googleapis.com/v1/projects/{args.project}",
                    "GET", None, "resourcemanager.projects.get"),
        "api-ready": (f"https://cloudresourcemanager.googleapis.com/v1/projects/{args.project}",
                      "GET", None, "resourcemanager.projects.get"),
        "bucket-list": (f"https://storage.googleapis.com/storage/v1/b?project={args.project}",
                        "GET", None, "storage.buckets.list"),
        "object-list": (storage + "/o", "GET", None, "storage.objects.list"),
        "read": (storage + "/o/sample.txt?alt=media", "GET", None, "storage.objects.get"),
        "compute": (compute + "/aggregated/instances?maxResults=1", "GET", None,
                    "compute.instances.list"),
        "vm-status": (compute + f"/zones/{args.zone}/instances/{args.vm}", "GET", None,
                      "compute.instances.get"),
        "write": (f"https://storage.googleapis.com/upload/storage/v1/b/{args.bucket}/o?"
                  "uploadType=media&name=sample2.txt&ifGenerationMatch=0", "POST",
                  f"Phase 07 IAM fixture {args.run}\n".encode(), "storage.objects.create"),
        "create-vm": (compute + f"/zones/{args.zone}/instances", "POST", vm_body(args),
                      args.permission),
        "actas": (f"https://iam.googleapis.com/v1/projects/{args.project}/serviceAccounts/"
                  f"{args.workload}:testIamPermissions", "POST",
                  {"permissions": ["iam.serviceAccounts.actAs"]}, "iam.serviceAccounts.actAs"),
        "compute-create-permission": (f"https://cloudresourcemanager.googleapis.com/v1/projects/"
                                     f"{args.project}:testIamPermissions", "POST",
                                     {"permissions": ["compute.instances.create"]}, "compute.instances.create"),
        "policy-read": (f"https://cloudresourcemanager.googleapis.com/v1/projects/{args.project}:getIamPolicy",
                        "POST", {}, "resourcemanager.projects.getIamPolicy"),
        "policy-edit-permission": (f"https://cloudresourcemanager.googleapis.com/v1/projects/{args.project}:testIamPermissions",
                                   "POST", {"permissions": ["resourcemanager.projects.setIamPolicy"]},
                                   "resourcemanager.projects.setIamPolicy"),
    }
    return operations[args.operation]


def vm_operation_result(args, token, initial, http_status):
    """HTTP 접수와 최종 성공/실패를 분리하고 정확한 run의 operation만 조회한다."""
    name = initial.get("name", "") if isinstance(initial, dict) else ""
    if not isinstance(name, str) or not re.fullmatch(r"[a-zA-Z0-9-]+", name):
        raise ProbeError("VM 생성 operation 식별 실패")
    zone_path = f"/compute/v1/projects/{args.project}/zones/{args.zone}"
    zone_urls = ["https://" + host + zone_path for host in ("www.googleapis.com", "compute.googleapis.com")]
    instance_urls = [url + "/instances/" + args.vm for url in zone_urls]
    endpoint = "https://compute.googleapis.com" + zone_path
    deadline, payload = time.monotonic() + 300, initial
    while True:
        if not isinstance(payload, dict) or payload.get("name") != name or \
                payload.get("operationType") != "insert" or payload.get("user") != args.actor or \
                payload.get("zone") not in zone_urls or payload.get("targetLink") not in instance_urls or \
                payload.get("status") not in ("PENDING", "RUNNING", "DONE"):
            raise ProbeError("VM 생성 operation identity/status 불일치")
        if payload["status"] == "DONE":
            break
        if time.monotonic() >= deadline:
            raise ProbeError("VM 생성 operation 시간 초과; 완료로 처리하지 않음")
        time.sleep(5)
        code, payload = request(endpoint + "/operations/" + name, token)
        if code != 200:
            raise ProbeError("VM 생성 operation 조회 실패; IAM 거부로 처리하지 않음")

    evidence = {"http_status": http_status, "check": "compute-operation",
                "operation_status": "DONE", "operation_sha256": hashlib.sha256(name.encode()).hexdigest()}
    if not payload.get("error") and not payload.get("httpErrorStatusCode"):
        if args.expect == "deny":
            raise ProbeError("거부되어야 할 VM 생성 작업이 성공함; run 소유 리소스 정리 필요")
        return dict(evidence, permission=args.permission, result="allowed")

    error = payload.get("error")
    errors = error.get("errors", []) if isinstance(error, dict) else []
    exact_actas_error = (
        payload.get("httpErrorStatusCode") in (400, 403) and isinstance(errors, list) and len(errors) == 1 and
        isinstance(errors[0], dict) and errors[0].get("code") == "SERVICE_ACCOUNT_ACCESS_DENIED" and
        isinstance(errors[0].get("message"), str) and
        f"'{args.workload}'" in errors[0]["message"] and f"User: '{args.actor}'" in errors[0]["message"] and
        re.search(r"(?<![A-Za-z0-9_.])iam\.serviceAccountUser(?![A-Za-z0-9_.])", errors[0]["message"]) and
        not infra_denial(payload))
    if not exact_actas_error:
        raise ProbeError("VM 생성 operation 실패; 기대한 actAs 거부가 아님")
    # 실패한 비동기 작업이 VM을 남겼다면 재시도하거나 기대 거부로 통과시키지 않는다.
    instance_code, _ = request(endpoint + "/instances/" + args.vm, token)
    if instance_code != 404:
        raise ProbeError("실패한 VM 생성 작업의 리소스 부재를 확인하지 못함")
    if args.expect == "allow":
        # terminal IAM 실패 + VM 부재에서만 bounded IAM 전파 재시도를 허용한다.
        return None
    if args.permission != "iam.serviceAccounts.actAs":
        raise ProbeError("다른 permission의 비동기 거부; 기대한 IAM matrix를 입증하지 못함")
    check_url = (f"https://iam.googleapis.com/v1/projects/{args.project}/serviceAccounts/"
                 f"{args.workload}:testIamPermissions")
    check_code, check = request(check_url, token, "POST", {"permissions": [args.permission]})
    permissions = check.get("permissions", []) if isinstance(check, dict) else None
    if check_code != 200 or not isinstance(check, dict) or "error" in check or not isinstance(permissions, list) or \
            not all(isinstance(p, str) for p in permissions) or args.permission in permissions:
        raise ProbeError("비동기 actAs 거부의 testIamPermissions 보강 실패")
    return dict(evidence, permission=args.permission, result="denied", permission_check="testIamPermissions",
                operation_http_error_status=payload["httpErrorStatusCode"],
                operation_error_code="SERVICE_ACCOUNT_ACCESS_DENIED", instance_absent=True)


def evaluate(args, token):
    url, method, body, permission = operation(args)
    code, payload = request(url, token, method, body)
    if args.operation == "api-ready":
        # 사용자 OAuth의 성공이 신규 SA의 API consumer 활성화를 증명하지는 않는다.
        if "SERVICE_DISABLED" in error_text(payload) or code in (429, 500, 502, 503, 504):
            return None
        if code not in (200, 403) or not isinstance(payload, dict) or infra_denial(payload):
            raise ProbeError("Resource Manager API 준비 검사 실패; IAM 권한 증거와 별도")
        return {"http_status": code, "result": "ready", "check": "api-readiness-only"}
    if infra_denial(payload):
        raise ProbeError("scope/API/조직 정책 오류; IAM 기대 거부가 아님")
    if args.operation == "create-vm" and 200 <= code < 300:
        return vm_operation_result(args, token, payload, code)
    if args.operation in ("actas", "compute-create-permission", "policy-edit-permission"):
        permissions = payload.get("permissions", []) if isinstance(payload, dict) else None
        if code != 200 or not isinstance(payload, dict) or "error" in payload or not isinstance(permissions, list) or \
                not all(isinstance(p, str) for p in permissions):
            raise ProbeError("testIamPermissions 조회 자체 실패; permission 부재로 처리하지 않음")
        allowed = permission in permissions
        if allowed == (args.expect == "allow"):
            return {"http_status": 200, "permission": permission,
                    "result": "allowed" if allowed else "denied", "check": "testIamPermissions"}
        return None
    if args.expect == "deny":
        permissions = None
        if args.operation == "project" and code == 403:
            check_code, check = request(url + ":testIamPermissions", token, "POST",
                                       {"permissions": [permission]})
            if check_code == 200 and isinstance(check, dict):
                permissions = check.get("permissions", [])
        elif args.operation in ("read", "write", "object-list") and code == 403:
            check_url = (f"https://storage.googleapis.com/storage/v1/b/{args.bucket}/iam/testPermissions?"
                         + urllib.parse.urlencode({"permissions": permission}))
            check_code, check = request(check_url, token)
            if check_code == 200 and isinstance(check, dict) and "error" not in check:
                permissions = check.get("permissions", [])
        if exact_denial(code, payload, permission, permissions):
            return {"http_status": code, "permission": permission, "result": "denied"}
        if args.operation == "write" and 200 <= code < 300:
            raise ProbeError("거부되어야 할 생성 요청이 수락됨; 즉시 중단하고 run 소유 리소스만 정리 필요")
        if code == 403:
            raise ProbeError("다른 permission의 거부; 기대한 IAM matrix를 입증하지 못함")
        if code in (200, 201, 429, 500, 502, 503, 504):
            return None
        raise ProbeError(f"예상 밖 HTTP {code}; 권한 거부로 처리하지 않음")
    if 200 <= code < 300:
        if args.operation == "vm-status":
            if not isinstance(payload, dict) or payload.get("name") != args.vm or \
                    payload.get("zone", "").rsplit("/", 1)[-1] != args.zone or \
                    payload.get("machineType", "").rsplit("/", 1)[-1] != "e2-micro" or \
                    payload.get("labels", {}) != {"harness": "gcp-lab-harness", "phase": "07", "run": args.run} or \
                    payload.get("serviceAccounts") != [{"email": args.workload, "scopes": ["https://www.googleapis.com/auth/cloud-platform"]}]:
                raise ProbeError("생성 VM의 이름/존/유형/소유권/workload identity 불일치")
            interfaces = payload.get("networkInterfaces")
            if not isinstance(interfaces, list) or len(interfaces) != 1 or not isinstance(interfaces[0], dict) or interfaces[0].get("accessConfigs") or \
                    interfaces[0].get("ipv6AccessConfigs") or interfaces[0].get("externalIpv6") or \
                    not interfaces[0].get("subnetwork", "").endswith(f"/projects/{args.project}/regions/{args.region}/subnetworks/p07-subnet-{args.run}"):
                raise ProbeError("생성 VM의 private subnet/external IP 계약 불일치")
            if payload.get("status") in ("PROVISIONING", "STAGING"):
                return None
            if payload.get("status") != "RUNNING":
                raise ProbeError("생성 VM이 RUNNING이 아님")
            return {"http_status": code, "permission": permission, "result": "allowed", "vm_status": "RUNNING",
                    "workload_principal_sha256": hashlib.sha256(args.workload.encode()).hexdigest(), "private_vm": True}
        if args.operation == "project" and (not isinstance(payload, dict) or payload.get("projectId") != args.project):
            raise ProbeError("project baseline의 identity 불일치")
        if args.operation == "bucket-list" and (not isinstance(payload, dict) or args.bucket not in
                [item.get("name") for item in payload.get("items", [])]):
            raise ProbeError("Viewer baseline에 run bucket이 없음")
        if args.operation == "read" and payload != f"Phase 07 IAM fixture {args.run}\n".encode():
            raise ProbeError("sample.txt 내용이 fixture와 다름")
        if args.operation == "object-list" and (not isinstance(payload, dict) or "sample.txt" not in
                [item.get("name") for item in payload.get("items", [])]):
            raise ProbeError("객체 목록에 fixture가 없음")
        if args.operation == "policy-read" and (not isinstance(payload, dict) or not isinstance(payload.get("bindings"), list)):
            raise ProbeError("IAM policy 조회 응답이 유효하지 않음")
        if args.operation == "write" and (not isinstance(payload, dict) or
                                           payload.get("name") != "sample2.txt" or
                                           not payload.get("generation")):
            raise ProbeError("업로드 응답의 object/generation 증거가 없음")
        return {"http_status": code, "permission": permission, "result": "allowed"}
    if code in (403, 429, 500, 502, 503, 504):
        return None
    raise ProbeError(f"예상 밖 HTTP {code}; IAM 전파 지연으로 처리하지 않음")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("project", "run", "zone", "region", "actor"):
        parser.add_argument("--" + name, required=True)
    parser.add_argument("--guest", action="store_true")
    parser.add_argument("--operation", choices=["project", "api-ready", "bucket-list", "object-list", "read", "write", "compute", "vm-status", "create-vm", "actas", "compute-create-permission", "policy-read", "policy-edit-permission"], required=True)
    parser.add_argument("--expect", choices=["allow", "deny"], required=True)
    parser.add_argument("--permission", choices=["compute.instances.create", "iam.serviceAccounts.actAs"], default="compute.instances.create")
    parser.add_argument("--image", default="")
    parser.add_argument("--wait", type=int, default=600)
    args = parser.parse_args()
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]{6,18}[a-z0-9]", args.run):
        raise ProbeError("invalid run ID")
    if not re.fullmatch(r"[a-z][a-z0-9-]{4,28}[a-z0-9]", args.project):
        raise ProbeError("invalid project ID")
    if not re.fullmatch(r"[a-z]+-[a-z]+[0-9]+", args.region) or args.zone not in [args.region + "-" + z for z in "abcdef"]:
        raise ProbeError("invalid region/zone")
    args.workload = f"p07-w-{args.run}@{args.project}.iam.gserviceaccount.com"
    if (args.guest and args.actor != args.workload) or (not args.guest and not human_email(args.actor)):
        raise ProbeError("local은 실제 사용자, guest는 run workload SA만 허용합니다.")
    if not 0 <= args.wait <= 600:
        raise ProbeError("wait 범위는 0~600초")
    args.bucket = "gcp-lab-p07-" + args.run
    args.vm = "p07-probe-" + args.run
    if args.operation == "create-vm" and (args.guest or not re.fullmatch(
            r"https://www.googleapis.com/compute/v1/projects/debian-cloud/global/images/debian-12-[a-z0-9-]+", args.image)):
        raise ProbeError("VM 생성은 local actor와 immutable Debian 12 image만 허용")
    deadline = time.monotonic() + args.wait
    while True:
        # 가장 인증 실패는 evaluate에 전달하지 않아 기대 거부로 오인하지 않는다.
        token = token_for(args)
        result = evaluate(args, token)
        if result is not None:
            result.update(operation=args.operation, expected=args.expect,
                          principal_sha256=hashlib.sha256(args.actor.encode()).hexdigest(),
                          token_source="metadata" if args.guest else "user-oauth")
            print(json.dumps(result, sort_keys=True))
            return
        if time.monotonic() >= deadline:
            raise ProbeError("IAM 전파 대기 제한 초과; PASS로 처리하지 않음")
        time.sleep(min(10, max(0, deadline - time.monotonic())))


if __name__ == "__main__":
    try:
        main()
    except (ProbeError, subprocess.SubprocessError) as exc:
        print("FAIL: " + (str(exc) if isinstance(exc, ProbeError) else "gcloud 인증 시간 초과"), file=sys.stderr)
        sys.exit(1)
