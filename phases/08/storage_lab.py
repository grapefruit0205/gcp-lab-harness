#!/usr/bin/env python3
"""Phase 08 전용 Storage JSON API 실습. 토큰·CSEK·HTTP 원문은 출력하지 않는다."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import tempfile
import time
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlencode, urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener


class LabError(Exception):
    pass


def require(condition, message):
    if not condition:
        raise LabError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def write_json(path, data):
    path = Path(path)
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".result-", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump(data, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


class ApiError(LabError):
    def __init__(self, code, body):
        self.code = code
        self.json_error = False
        try:
            error = json.loads(body).get("error", {})
            self.reasons = {item.get("reason") for item in error.get("errors", [])}
            self.pap = code == 412 and "public access prevention" in error.get("message", "").lower()
            self.json_error = True
        except (ValueError, TypeError, AttributeError):
            self.reasons, self.pap = set(), False
        # 외부 reason/message를 그대로 반사하지 않는다. 진단 정보는 고정된 값만 출력한다.
        known = self.reasons & {"required", "forbidden", "accessDenied", "authError", "notFound", "invalid",
                                "conditionNotMet", "customerEncryptionKeyIsIncorrect", "resourceIsEncryptedWithCustomerEncryptionKey"}
        reason = ",".join(sorted(known)) or "unclassified"
        super().__init__(f"Storage API HTTP {code}; format={'json' if self.json_error else 'non-json'}; reason={reason}; 원문 생략")


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class Api:
    def __init__(self, token):
        require(bool(token), "OAuth token이 없습니다.")
        self.token = token
        self.opener = build_opener(NoRedirect())
        self.deadline = None

    def request(self, method, path, *, query=None, data=None, headers=None, anonymous=False, raw=False):
        url = path if path.startswith("https://") else "https://storage.googleapis.com" + path
        parsed = urlsplit(url)
        require(parsed.scheme == "https" and parsed.netloc in {"storage.googleapis.com", "www.googleapis.com"},
                "허용되지 않은 API endpoint")
        if query:
            url += "?" + urlencode(query)
        request_headers = {"Cache-Control": "no-cache", **(headers or {})}
        if not anonymous:
            request_headers["Authorization"] = "Bearer " + self.token
        if isinstance(data, dict):
            data = json.dumps(data).encode()
            request_headers["Content-Type"] = "application/json"
        remaining = self.deadline - time.monotonic() if self.deadline is not None else 25
        require(remaining > 0, "action plan 시간 제한 초과")
        try:
            with self.opener.open(Request(url, data=data, headers=request_headers, method=method), timeout=min(25, remaining)) as response:
                body = response.read(2 * 1024 * 1024 + 1)
                require(len(body) <= 2 * 1024 * 1024, "실습 응답 크기 상한 초과")
        except HTTPError as error:
            raise ApiError(error.code, error.read(65536)) from None
        except (URLError, TimeoutError, OSError):
            raise LabError("API 네트워크/TLS/시간 초과; 예상 거부나 리소스 부재로 처리하지 않음") from None
        if raw:
            return body
        try:
            return json.loads(body) if body else {}
        except ValueError:
            raise LabError("API JSON 응답 손상") from None

    def items(self, path, **query):
        items, seen = [], set()
        for _ in range(100):
            page = self.request("GET", path, query=query)
            require(isinstance(page, dict) and isinstance(page.get("items", []), list), "목록 응답 형식 오류")
            items.extend(page.get("items", []))
            token = page.get("nextPageToken")
            if not token:
                return items
            require(token not in seen, "반복된 pagination token")
            seen.add(token)
            query["pageToken"] = token
        raise LabError("목록 pagination 상한 초과")


def encryption_headers(key, source=False):
    if key is None:
        return {}
    require(len(key) == 32, "CSEK는 256bit여야 합니다.")
    prefix = "X-Goog-Copy-Source-Encryption-" if source else "X-Goog-Encryption-"
    return {prefix + "Algorithm": "AES256", prefix + "Key": base64.b64encode(key).decode(),
            prefix + "Key-Sha256": base64.b64encode(hashlib.sha256(key).digest()).decode()}


def key_denial(error):
    return error.code == 400 and bool(error.reasons & {
        "customerEncryptionKeyIsIncorrect", "resourceIsEncryptedWithCustomerEncryptionKey"})


def guard_plan(plan, inputs):
    changes = plan.get("resource_changes", [])
    require(len(changes) == 1, "단일 bucket 외 리소스가 plan에 있습니다.")
    item = changes[0]
    require(item.get("address") == "google_storage_bucket.lab" and item.get("type") == "google_storage_bucket"
            and item.get("change", {}).get("actions") == ["create"], "새 전용 bucket create만 허용")
    after = item["change"]["after"]
    expected = {"name": "gcp-lab-p08-" + inputs["run_id"], "project": inputs["project_id"],
                "location": inputs["region"].upper(), "force_destroy": True,
                "uniform_bucket_level_access": False, "public_access_prevention": "inherited"}
    for key, value in expected.items():
        require(after.get(key) == value, "bucket plan 설정 불일치: " + key)
    require(after.get("labels") == {"harness": "gcp-lab-harness", "phase": "08", "run": inputs["run_id"]}, "plan labels 불일치")
    require(after.get("versioning") == [{"enabled": True}], "versioning plan 불일치")
    require(len(after.get("soft_delete_policy", [])) == 1 and
            after["soft_delete_policy"][0].get("retention_duration_seconds") == 0, "soft-delete=0 필요")
    rules = after.get("lifecycle_rule", [])
    require(len(rules) == 1 and len(rules[0].get("action", [])) == 1 and
            rules[0]["action"][0].get("type") == "Delete" and
            rules[0]["action"][0].get("storage_class") in (None, "") and
            len(rules[0].get("condition", [])) == 1 and rules[0]["condition"][0].get("age") == 31,
            "31일 Delete lifecycle plan 불일치")
    condition = rules[0]["condition"][0]
    require(all(value in (None, "", False, [], 0, "ANY") for key, value in condition.items() if key != "age"),
            "추가 lifecycle 조건이 있습니다.")
    require(not after.get("retention_policy") and not after.get("encryption") and
            not after.get("default_event_based_hold") and not after.get("enable_object_retention"),
            "보존 잠금/기본 암호화/hold는 실습 범위 밖입니다.")


class StorageLab:
    def __init__(self, api, inputs, run_dir, *, sync=None, wait=time.sleep):
        self.api, self.inputs, self.run_dir = api, inputs, Path(run_dir)
        self.bucket = "gcp-lab-p08-" + inputs["run_id"]
        self.base = "/storage/v1/b/" + self.bucket
        self.identity_file = self.run_dir / "bucket-identity.json"
        self.sync = sync or self.rsync
        self.wait = wait

    def inventory(self, soft=False):
        query = {"project": self.inputs["project_id"], "prefix": self.bucket}
        if soft:
            query["softDeleted"] = "true"
        return [item for item in self.api.items("/storage/v1/b", **query) if item.get("name") == self.bucket]

    def owned(self, allow_missing=False, record=False):
        found = self.inventory()
        if not found and allow_missing:
            return None
        require(len(found) == 1, "전용 프로젝트 bucket을 찾지 못했습니다.")
        bucket = self.api.request("GET", self.base)
        labels = {"harness": "gcp-lab-harness", "phase": "08", "run": self.inputs["run_id"]}
        require(bucket.get("name") == self.bucket and all(bucket.get("labels", {}).get(key) == value for key, value in labels.items()),
                "bucket 소유권 label 불일치")
        require(bool(bucket.get("timeCreated")) and bool(bucket.get("projectNumber")), "bucket identity 누락")
        identity = {key: bucket[key] for key in ("name", "timeCreated", "projectNumber")}
        if self.identity_file.exists():
            require(read_json(self.identity_file) == identity, "bucket 재생성/프로젝트 변경 감지")
        elif record:
            write_json(self.identity_file, identity)
        return bucket

    def settings(self, bucket):
        require(bucket.get("location", "").upper() == self.inputs["region"].upper(), "bucket region 불일치")
        iam = bucket.get("iamConfiguration", {})
        require(iam.get("uniformBucketLevelAccess", {}).get("enabled") is False, "ACL 실습은 fine-grained bucket 필요")
        require(iam.get("publicAccessPrevention") == "inherited", "PAP 설정 drift")
        require(int(bucket.get("softDeletePolicy", {}).get("retentionDurationSeconds", -1)) == 0, "soft-delete=0 readback 필요")
        require(bucket.get("versioning", {}).get("enabled") is True, "versioning 비활성")
        require(bucket.get("lifecycle", {}).get("rule") == [{"action": {"type": "Delete"}, "condition": {"age": 31}}],
                "31일 Delete lifecycle readback 불일치")
        require(not bucket.get("retentionPolicy") and not bucket.get("defaultEventBasedHold") and
                not bucket.get("encryption"), "bucket hold/retention/encryption drift")

    def path(self, name):
        return self.base + "/o/" + quote(name, safe="")

    def objects(self, prefix="", versions=False):
        return self.api.items(self.base + "/o", prefix=prefix, versions=str(versions).lower())

    def metadata(self, name, generation=None):
        query = {"projection": "full"}
        if generation:
            query["generation"] = generation
        return self.api.request("GET", self.path(name), query=query)

    def upload(self, name, content, previous="0", key=None):
        return self.api.request("POST", "/upload/storage/v1/b/" + self.bucket + "/o",
                                query={"uploadType": "media", "name": name, "ifGenerationMatch": previous,
                                       "predefinedAcl": "private"}, data=content,
                                headers={"Content-Type": "text/html", **encryption_headers(key)})

    def download(self, name, generation=None, key=None, anonymous=False):
        query = {"alt": "media"}
        if generation:
            query["generation"] = generation
        return self.api.request("GET", self.path(name), query=query, headers=encryption_headers(key),
                                anonymous=anonymous, raw=True)

    def private(self, generation):
        self.api.request("PATCH", self.path("setup.html"), query={"generation": generation, "predefinedAcl": "private"},
                         data={"cacheControl": "no-store, max-age=0"})
        acl = self.metadata("setup.html", generation).get("acl", [])
        require(not any(item.get("entity") in {"allUsers", "allAuthenticatedUsers"} for item in acl), "공개 ACL 회수 실패")

    def anonymous_denied(self, generation):
        # alt=media 오류는 일반 텍스트일 수도 있다. 같은 generation의 인증 GET을
        # 전후 positive control로 사용하고, 헤더 없는 익명 요청만 401/403을 허용한다.
        self.metadata("setup.html", generation)
        authenticated = self.download("setup.html", generation)
        for attempt in range(10):
            try:
                self.download("setup.html", generation, anonymous=True)
            except ApiError as error:
                if error.code in {401, 403}:
                    require(self.download("setup.html", generation) == authenticated, "익명 거부 후 인증 GET 대조 실패")
                    return
                raise
            if attempt < 9:
                self.wait(2)
        raise LabError("private 객체가 익명 다운로드됨")

    def acl_test(self, original):
        obj = self.upload("setup.html", original)
        generation = obj["generation"]
        self.private(generation)
        require(self.download("setup.html", generation) == original, "Task 2 인증 다운로드 hash 불일치")
        self.anonymous_denied(generation)
        public = "created-tested-revoked"
        # 요청 직전부터 finally를 건다. 서버에서 성공하고 응답만 유실된 경우도 회수한다.
        try:
            try:
                self.api.request("POST", self.path("setup.html") + "/acl", query={"generation": generation},
                                 data={"entity": "allUsers", "role": "READER"})
            except ApiError as error:
                if not error.pap:
                    raise
                public = "policy-prevented"
            if public != "policy-prevented":
                acl = self.metadata("setup.html", generation).get("acl", [])
                require(any(item.get("entity") == "allUsers" and item.get("role") == "READER" for item in acl), "public ACL readback 불일치")
                require(self.download("setup.html", generation, anonymous=True) == original, "public 객체 hash 불일치")
        finally:
            # action timeout 뒤에도 비밀/공개 회수용 짧은 별도 시간을 준다.
            self.api.deadline = time.monotonic() + 90
            self.private(generation)
            self.anonymous_denied(generation)
        return generation, public

    def encrypted_metadata(self, name, key):
        expected = {"encryptionAlgorithm": "AES256", "keySha256": base64.b64encode(hashlib.sha256(key).digest()).decode()}
        require(self.metadata(name).get("customerEncryption") == expected, "CSEK metadata fingerprint 불일치")

    def expect_key_denied(self, name, key, correct_key):
        generation = self.metadata(name)["generation"]
        control = self.download(name, generation, key=correct_key)
        try:
            self.download(name, generation, key=key)
        except ApiError as error:
            require(error.code == 400, "예상 CSEK 거부가 아님: HTTP " + str(error.code))
            if not key_denial(error):
                # media의 non-JSON 400을 무조건 인정하지 않는다. 동일 generation의
                # 암호화 checksum metadata 요청도 동일 구키로 거부되어야 한다.
                try:
                    self.api.request("GET", self.path(name),
                                     query={"generation": generation, "fields": "generation,md5Hash,crc32c,customerEncryption"},
                                     headers=encryption_headers(key))
                except ApiError as metadata_error:
                    require(key_denial(metadata_error), "CSEK metadata 거부 reason 불일치")
                else:
                    raise LabError("CSEK metadata가 잘못된 키를 거부하지 않음")
            require(self.download(name, generation, key=correct_key) == control, "CSEK 거부 후 올바른 키 대조 실패")
            return
        raise LabError("잘못된 CSEK로 다운로드 성공")

    def rewrite(self, name, old_key, new_key):
        generation = self.metadata(name)["generation"]
        query = {"sourceGeneration": generation, "ifSourceGenerationMatch": generation,
                 "ifGenerationMatch": generation, "destinationPredefinedAcl": "private"}
        for _ in range(20):
            response = self.api.request("POST", self.path(name) + "/rewriteTo/b/" + self.bucket + "/o/" + quote(name, safe=""),
                                        query=query, data={}, headers={**encryption_headers(old_key, source=True), **encryption_headers(new_key)})
            if response.get("done") is True:
                require(response.get("resource", {}).get("generation") != generation and
                        response.get("resource", {}).get("name") == name, "rewrite 완료 객체 불일치")
                self.encrypted_metadata(name, new_key)
                return
            require(response.get("done") is False and bool(response.get("rewriteToken")), "rewrite continuation 누락")
            query["rewriteToken"] = response["rewriteToken"]
        raise LabError("rewrite continuation 상한 초과")

    def remove_encrypted(self):
        failed = False
        for name in ("setup2.html", "setup3.html"):
            try:
                for obj in self.objects(name, versions=True):
                    require(obj["name"] == name, "암호화 cleanup 대상 밖 객체")
                    self.api.request("DELETE", self.path(name), query={"generation": obj["generation"], "ifGenerationMatch": obj["generation"]})
                require(not self.objects(name, versions=True), "암호화 세대 잔여")
            except LabError:
                failed = True
        require(not failed, "암호화 객체 전체 세대 cleanup 미완료; run destroy 필요")

    def csek_test(self, original):
        key1, key2 = os.urandom(32), os.urandom(32)
        try:
            for name in ("setup2.html", "setup3.html"):
                self.upload(name, original, key=key1)
                self.encrypted_metadata(name, key1)
                require(self.download(name, key=key1) == original, "최초 CSEK 복호화 hash 불일치")
            self.rewrite("setup2.html", key1, key2)
            require(self.download("setup2.html", key=key2) == original, "setup2 새 키 hash 불일치")
            self.expect_key_denied("setup2.html", key1, key2)
            self.expect_key_denied("setup3.html", key2, key1)
            require(self.download("setup3.html", key=key1) == original, "setup3 기존 키 대조 실패")
            self.rewrite("setup3.html", key1, key2)
            require(self.download("setup3.html", key=key2) == original, "setup3 새 키 hash 불일치")
            self.expect_key_denied("setup3.html", key1, key2)
        finally:
            # 버전 관리로 남은 구키 세대도 삭제. 키는 파일·argv·state에 기록하지 않는다.
            try:
                self.api.deadline = time.monotonic() + 90
                self.remove_encrypted()
            finally:
                key1 = key2 = None

    def versions_test(self, original, original_generation):
        lines = original.splitlines(keepends=True)
        require(len(lines) > 15, "fixture 줄 수 부족")
        second, third = b"".join(lines[:-5]), b"".join(lines[:-10])
        g2 = self.upload("setup.html", second, previous=original_generation)["generation"]
        g3 = self.upload("setup.html", third, previous=g2)["generation"]
        expected = {str(original_generation): len(original), str(g2): len(second), str(g3): len(third)}
        versions = self.objects("setup.html", versions=True)
        require(len(expected) == 3 and len(versions) == 3 and
                all(obj["name"] == "setup.html" for obj in versions) and
                {str(obj["generation"]): int(obj["size"]) for obj in versions} == expected, "3세대 목록/크기 불일치")
        recovered = self.download("setup.html", original_generation)
        require(digest(recovered) == digest(original) and len(recovered) > len(third), "저장 원본 generation 복구 실패")
        (self.run_dir / "recovered.txt").write_bytes(recovered)
        require(self.download("setup.html") == third, "원본 복구가 live 객체를 바꾸었음")
        return {"count": 3, "original_generation": str(original_generation), "recovered_sha256": digest(recovered)}, third

    def rsync(self, directory):
        command = ["gcloud", "storage", "rsync", str(directory), "gs://" + self.bucket + "/firstlevel", "--recursive",
                   "--account=" + self.inputs["runner"], "--project=" + self.inputs["project_id"], "--quiet"]
        result = subprocess.run(command, capture_output=True, timeout=300, check=False)
        require(result.returncode == 0, "gcloud recursive rsync 실패 (원문 로그 생략)")

    def sync_test(self, content):
        directory = self.run_dir / "fixture" / "firstlevel"
        (directory / "secondlevel").mkdir(mode=0o700, parents=True)
        (directory / "setup.html").write_bytes(content)
        (directory / "secondlevel" / "setup.html").write_bytes(content)
        self.sync(directory)
        expected = {"firstlevel/setup.html", "firstlevel/secondlevel/setup.html"}
        objects = self.objects("firstlevel/")
        require(len(objects) == 2 and {obj["name"] for obj in objects} == expected, "rsync 객체 집합 불일치")
        hashes = {}
        for obj in objects:
            name = obj["name"]
            hashes[name] = digest(self.download(name, obj["generation"]))
            require(hashes[name] == digest(content), "rsync 다운로드 hash 불일치")
        return hashes

    def run(self):
        print("CHECK: task-1 bucket/fixture", flush=True)
        require(self.identity_file.exists(), "apply bucket identity 기록이 없습니다.")
        self.settings(self.owned())
        require(not self.objects(versions=True), "비어 있지 않은 bucket: 실습 재실행/외부 객체를 덮어쓰지 않음")
        journal = self.run_dir / "verification-started.json"
        require(not journal.exists(), "이미 시작한 run: destroy 후 새 plan 필요")
        write_json(journal, {"phase": "08", "run_id": self.inputs["run_id"]})
        original = Path(__file__).with_name("fixture.html").read_bytes()
        # Versioning 전파 대기(원문 최소 30초). 테스트는 주입한 clock으로 검증한다.
        self.wait(30)
        print("CHECK: task-2 ACL", flush=True)
        self.api.deadline = time.monotonic() + 300
        generation, public = self.acl_test(original)
        print("CHECK: task-3/4 CSEK", flush=True)
        self.api.deadline = time.monotonic() + 600
        self.csek_test(original)
        print("CHECK: task-5/6 lifecycle/generations", flush=True)
        self.api.deadline = time.monotonic() + 300
        versions, current = self.versions_test(original, generation)
        print("CHECK: task-7 recursive sync", flush=True)
        self.api.deadline = time.monotonic() + 300
        hashes = self.sync_test(current)
        self.settings(self.owned())
        tasks = {"task-1": "region 전용 bucket 및 고정 HTML fixture",
                 "task-2": "private/public ACL·다운로드·즉시 회수: " + public,
                 "task-3": "두 CSEK 객체 metadata 및 최초 복호화 hash",
                 "task-4": "두 객체 rewrite·신키 성공·구키 거부·암호화 전체 세대 삭제",
                 "task-5": "31일 Delete lifecycle readback (31일 실제 삭제 미검증)",
                 "task-6": "3세대 목록·크기·저장 원본 generation 로컬 복구 hash",
                 "task-7": "gcloud recursive rsync·객체 집합·개별 다운로드 hash",
                 "task-8": "CLI/API 동등 기능 검토; Console UI 조작 제외"}
        result = {"phase": "08", "run_id": self.inputs["run_id"], "tasks": {
            task: {"status": "passed", "detail": detail} for task, detail in tasks.items()},
            "fixture_sha256": digest(original), "public_acl": public, "versions": versions, "sync_sha256": hashes,
            "encrypted_generations_remaining": 0, "lab_completion": {"complete": False, "destroy_pending": True,
                "public_acl_exercised": public != "policy-prevented"},
            "risks": ["조직 PAP 때문에 공개 ACL 성공 단계는 미수행"] if public == "policy-prevented" else []}
        write_json(self.run_dir / "evidence" / "phase-08-machine.json", result)
        return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=["identity", "preflight", "guard-plan", "record", "owned", "verify", "destroyed"])
    parser.add_argument("--run-dir", type=Path)
    parser.add_argument("--account")
    parser.add_argument("--project")
    parser.add_argument("--run")
    parser.add_argument("--plan", type=Path)
    parser.add_argument("--inputs", type=Path)
    args = parser.parse_args()
    if args.operation == "guard-plan":
        guard_plan(read_json(args.plan), read_json(args.inputs))
        return
    api = Api(os.environ.get("GOOGLE_OAUTH_ACCESS_TOKEN"))
    if args.operation == "identity":
        identity = api.request("GET", "https://www.googleapis.com/oauth2/v2/userinfo")
        require(identity.get("email", "").lower() == (args.account or "").lower() and identity.get("verified_email") is True,
                "선택 계정과 실제 OAuth 사용자 불일치")
    elif args.operation == "preflight":
        require(bool(re.fullmatch(r"[a-z0-9][a-z0-9-]{6,18}[a-z0-9]", args.run or "")), "잘못된 run ID")
        bucket = "gcp-lab-p08-" + args.run
        # 200으로 모든 페이지를 확인한다. 권한 부족/404/네트워크 실패를 빈 목록으로 간주하지 않는다.
        for soft in (False, True):
            query = {"project": args.project, "prefix": bucket}
            if soft:
                query["softDeleted"] = "true"
            require(not any(item.get("name") == bucket for item in api.items("/storage/v1/b", **query)), "기존/soft-deleted bucket 이름 충돌")
    else:
        require(args.run_dir is not None, "--run-dir 필요")
        inputs = read_json(args.run_dir / "work" / "phase-08.auto.tfvars.json")
        lab = StorageLab(api, inputs, args.run_dir)
        if args.operation == "record":
            lab.settings(lab.owned(record=True))
        elif args.operation == "owned":
            lab.owned(allow_missing=True)
        elif args.operation == "destroyed":
            require(not lab.inventory() and not lab.inventory(soft=True), "활성/soft-deleted bucket 잔여")
            write_json(args.run_dir / "evidence" / "phase-08-destroyed.json",
                       {"phase": "08", "run_id": inputs["run_id"], "live_buckets": 0, "soft_deleted_buckets": 0})
        elif args.operation == "verify":
            lab.run()


if __name__ == "__main__":
    os.umask(0o077)
    # Windows에는 resource 모듈이 없다. POSIX에서는 key가 core dump에 남지 않게 한다.
    try:
        import resource
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    except ImportError:
        pass
    def interrupted(signum, frame):
        raise LabError("실행 중단 신호; 실패 cleanup 필요")
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    try:
        main()
    except (LabError, ValueError, KeyError, TypeError, OSError, subprocess.SubprocessError) as error:
        # 외부 예외의 str(error)에는 HTTP body/토큰이 있을 수 있으므로 자체 오류만 출력한다.
        print("FAIL: " + (str(error) if isinstance(error, LabError) else "로컬 입력/실행 오류; 비밀 비노출"), file=sys.stderr)
        sys.exit(1)
