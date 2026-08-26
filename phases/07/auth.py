#!/usr/bin/env python3
"""사용자별 계정 등록·Google 로그인·OAuth identity 확인. 비밀번호는 수집하지 않는다."""
import argparse
import hashlib
import importlib.util
import json
import os
import re
from pathlib import Path
import subprocess
import sys
import tempfile

spec = importlib.util.spec_from_file_location("iam_probe", Path(__file__).with_name("iam-probe.py"))
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)


def validate_users(value):
    if not isinstance(value, dict) or value.get("identity_mode") != "two-users" or not all(probe.human_email(value.get(k)) for k in ("user1", "user2")):
        raise ValueError("identity_mode=two-users 및 실제 사용자 이메일 두 개가 필요합니다.")
    if value["user1"].lower() == value["user2"].lower():
        raise ValueError("계정 1과 계정 2는 서로 달라야 합니다.")
    if any(value[k] != value[k].lower() for k in ("user1", "user2")):
        raise ValueError("계정 이메일은 소문자로 입력하세요.")
    return value


def load_users(path):
    return validate_users(json.loads(Path(path).read_text()))


def save_users(path, users):
    """완전한 입력만 원자적으로 저장한다. 중단/검증 실패로 기존 설정을 깨지 않는다."""
    validate_users(users)
    path = Path(path)
    if path.is_symlink() or (path.exists() and not path.is_file()):
        raise ValueError("계정 설정 경로는 심볼릭 링크가 아닌 일반 파일이어야 합니다.")
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".phase-07-users.", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            if os.name != "nt":
                os.fchmod(stream.fileno(), 0o600)
            json.dump({key: users[key] for key in ("identity_mode", "user1", "user2")}, stream, indent=2)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def active_user():
    try:
        result = subprocess.run(["gcloud", "auth", "list", "--filter=status:ACTIVE", "--format=value(account)"],
                                capture_output=True, text=True, check=False, timeout=15)
    except (OSError, subprocess.SubprocessError):
        return ""
    account = result.stdout.strip().lower()
    return account if result.returncode == 0 and probe.human_email(account) else ""


def setup_users(path, user1=None, user2=None, interactive=None, input_fn=None):
    interactive = sys.stdin.isatty() if interactive is None else interactive
    input_fn = input if input_fn is None else input_fn
    path = Path(path)
    # 손상된 기존 파일을 임의 초기화하지 않는다.
    previous = load_users(path) if path.exists() else {}
    if not interactive and (user1 is None or user2 is None):
        raise ValueError("터미널에서 auth.sh --setup을 실행하거나 --setup --user1 <관리자 이메일> --user2 <실습 이메일>를 지정하세요.")
    selected = {"identity_mode": "two-users"}
    for key, explicit, title in (("user1", user1, "User1 관리자 계정"), ("user2", user2, "User2 실습 계정")):
        if explicit is None:
            default = previous.get(key, "") or (active_user() if key == "user1" else "")
            value = input_fn(f"{title} 이메일" + (f" [{default}]" if default else "") + ": ").strip() or default
        else:
            value = explicit.strip()
        selected[key] = value.lower()
    validate_users(selected)
    save_users(path, selected)
    print("PASS: 계정 설정 저장 완료. 비밀번호/토큰은 이 파일에 저장하지 않습니다.")
    return selected


def check_auth_overrides():
    for key in ("CLOUDSDK_AUTH_ACCESS_TOKEN", "CLOUDSDK_AUTH_ACCESS_TOKEN_FILE",
                "CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE", "CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT"):
        if os.environ.get(key):
            raise ValueError("gcloud 인증 override를 해제하세요: " + key)
    for setting in ("auth/impersonate_service_account", "auth/access_token_file", "auth/credential_file_override"):
        result = subprocess.run(["gcloud", "config", "get-value", setting], capture_output=True, text=True, check=False, timeout=15)
        if result.returncode or result.stdout.strip() not in ("", "(unset)"):
            raise ValueError("gcloud 인증 override 설정을 해제하세요: " + setting)


def authenticated_user(account, key, allow_login=False, force_login=False):
    if not force_login:
        try:
            return probe.user_token(account)
        except probe.ProbeError as error:
            if not allow_login:
                raise ValueError(f"{key}: {error} 터미널에서 auth.sh --setup을 실행하세요.") from error
    print(f"{key}: Google 로그인 화면에서 이 계정으로 직접 인증하세요: {account}", file=sys.stderr)
    # --no-activate: gcloud 활성 계정/ADC를 바꾸지 않는다. Google이 OAuth 자격 증명을 관리한다.
    result = subprocess.run(["gcloud", "auth", "login", account, "--no-activate"], check=False)
    if result.returncode:
        raise ValueError(f"{key} 브라우저 인증이 완료되지 않았습니다. auth.sh --setup으로 다시 이어갈 수 있습니다.")
    try:
        return probe.user_token(account)
    except probe.ProbeError as error:
        raise ValueError(f"{key}: 로그인 후 OAuth identity 확인 실패. 선택한 Google 계정을 확인하세요.") from error


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", required=True)
    parser.add_argument("--validate-only", action="store_true")
    parser.add_argument("--only", choices=["user1", "user2"])
    parser.add_argument("--project")
    parser.add_argument("--bucket")
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--setup", action="store_true", help="두 사용자 이메일 입력/저장 후 필요한 로그인 연결")
    modes.add_argument("--ensure", action="store_true", help="plan 준비: 터미널이면 누락 설정/로그인 연결, 비대화형이면 실패")
    modes.add_argument("--login", choices=["user1", "user2"], help="지정한 계정의 Google 로그인")
    parser.add_argument("--user1", help="--setup에 사용할 관리자 이메일")
    parser.add_argument("--user2", help="--setup에 사용할 실습 이메일")
    parser.add_argument("--no-login", action="store_true", help="--setup에서 로컬 설정만 저장")
    args = parser.parse_args()
    if (args.user1 is not None or args.user2 is not None or args.no_login) and not args.setup:
        parser.error("--user1/--user2/--no-login은 --setup과 함께 사용하세요.")
    if (args.setup or args.ensure or args.login) and (args.validate_only or args.only or args.project or args.bucket):
        parser.error("계정 준비/로그인과 읽기 전용 검증 옵션을 함께 사용할 수 없습니다.")
    if args.project and not re.fullmatch(r"[a-z][a-z0-9-]{4,28}[a-z0-9]", args.project):
        raise ValueError("project ID 형식이 올바르지 않습니다.")
    if args.bucket and not re.fullmatch(r"[a-z0-9][a-z0-9._-]{1,61}[a-z0-9]", args.bucket):
        raise ValueError("bucket 이름 형식이 올바르지 않습니다.")
    interactive = sys.stdin.isatty()
    if args.setup:
        users = setup_users(args.config, args.user1, args.user2, interactive=interactive)
        if args.no_login:
            print("Cloud IAM 변경/브라우저 로그인은 수행하지 않았습니다. 다음: auth.sh --setup")
            return
    elif args.ensure and not Path(args.config).exists() and interactive:
        users = setup_users(args.config, interactive=True)
    else:
        if not Path(args.config).exists():
            raise ValueError("계정 설정이 없습니다. 터미널에서 auth.sh --setup으로 두 계정을 추가하세요.")
        users = load_users(args.config)
    if args.validate_only:
        print("PASS: 실제 사용자 두 계정 설정")
        return
    check_auth_overrides()
    identities = {}
    keys = [args.only] if args.only else ["user1", "user2"]
    if args.login:
        keys = [args.login] + [key for key in keys if key != args.login]
    for key in keys:
        token = authenticated_user(users[key], key, allow_login=args.setup or (args.ensure and interactive) or args.login == key,
                                   force_login=args.login == key)
        identities[key] = {"principal_sha256": hashlib.sha256(users[key].encode()).hexdigest(),
                           "token_source": "user-oauth", "verified": True}
        if args.project:
            permissions = ["resourcemanager.projects.get", "resourcemanager.projects.getIamPolicy",
                           "resourcemanager.projects.setIamPolicy", "compute.instances.create",
                           "compute.instances.list", "storage.buckets.list"]
            if key == "user1":
                permissions += ["serviceusage.services.enable", "iam.serviceAccounts.create", "iam.serviceAccounts.actAs",
                                "iap.tunnelInstances.accessViaIAP", "compute.instances.osLogin"]
            code, response = probe.request(f"https://cloudresourcemanager.googleapis.com/v1/projects/{args.project}:testIamPermissions",
                                           token, "POST", {"permissions": permissions})
            actual = response.get("permissions", []) if isinstance(response, dict) else None
            if code != 200 or not isinstance(response, dict) or "error" in response or not isinstance(actual, list) or not all(isinstance(p, str) for p in actual):
                raise ValueError(f"{key}의 프로젝트 권한 조회 실패; 인증/조직 정책을 확인하세요.")
            if key == "user1" and set(permissions) - set(actual):
                raise ValueError("User1의 관리자/VM/IAP/API 권한 부족: " + ", ".join(sorted(set(permissions) - set(actual))))
            if key == "user2" and actual:
                raise ValueError("User2에 기존/상속 권한이 있습니다. 기존 권한을 자동 제거하지 않으므로 별도 실습 계정을 사용하세요.")
            identities[key]["project_baseline_checked"] = True
        if args.bucket:
            permissions = ["storage.objects.get", "storage.objects.list", "storage.objects.create"]
            query = probe.urllib.parse.urlencode({"permissions": permissions}, doseq=True)
            code, response = probe.request(f"https://storage.googleapis.com/storage/v1/b/{args.bucket}/iam/testPermissions?{query}", token)
            actual = response.get("permissions", []) if isinstance(response, dict) else None
            if code != 200 or not isinstance(response, dict) or "error" in response or not isinstance(actual, list) or not all(isinstance(p, str) for p in actual):
                raise ValueError(f"{key}의 실제 버킷 권한 조회 실패")
            if key == "user1" and set(permissions) - set(actual):
                raise ValueError("User1의 실습 버킷 객체 권한 부족")
            if key == "user2" and actual:
                raise ValueError("User2에 기존/상속 Storage 권한이 있습니다. 자동 제거하지 않습니다.")
            identities[key]["bucket_baseline_checked"] = True
    print(json.dumps({"identity_mode": "two-users", "identities": identities}, sort_keys=True))
    if args.setup or args.ensure:
        print("PASS: 두 계정 인증 확인. 프로젝트 계정 추가·역할 전이는 새 plan 승인 후 apply/verify 흐름이 수행합니다.")


if __name__ == "__main__":
    try:
        main()
    except (EOFError, KeyboardInterrupt):
        print("중단: 계정 입력/로그인을 완료하지 않았습니다. auth.sh --setup으로 다시 시작하세요.", file=sys.stderr)
        sys.exit(130)
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        print("FAIL: " + str(error), file=sys.stderr)
        sys.exit(1)
