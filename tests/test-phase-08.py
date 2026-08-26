#!/usr/bin/env python3
"""Cloud/자격 증명 없이 Phase 08 API 계약과 실패 경계를 검사한다."""
import base64
import copy
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch
from urllib.error import HTTPError, URLError
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("storage_lab", ROOT / "phases/08/storage_lab.py")
lab = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(lab)
INPUTS = {"project_id": "example-lab", "run_id": "p08-test-001", "region": "us-central1", "runner": "learner@example.com"}


def error(code, reason="forbidden", message="test error"):
    return lab.ApiError(code, json.dumps({"error": {"code": code, "message": message, "errors": [{"reason": reason}]}}).encode())


class FakeStorage(lab.Api):
    def __init__(self):
        self.bucket = {"name": "gcp-lab-p08-" + INPUTS["run_id"], "timeCreated": "2026-01-01T00:00:00Z", "projectNumber": "123456789",
                       "labels": {"harness": "gcp-lab-harness", "phase": "08", "run": INPUTS["run_id"]},
                       "location": "US-CENTRAL1", "iamConfiguration": {"uniformBucketLevelAccess": {"enabled": False}, "publicAccessPrevention": "inherited"},
                       "softDeletePolicy": {"retentionDurationSeconds": "0"}, "versioning": {"enabled": True},
                       "lifecycle": {"rule": [{"action": {"type": "Delete"}, "condition": {"age": 31}}]}}
        self.data, self.requests = {}, []
        self.counter = 100
        self.pap = self.fail_after_public = self.fail_delete = self.corrupt_sync = False
        self.wrong_key_error = None
        self.rewrite_pending = False
        self.soft = []

    def find(self, name, generation=None):
        objects = self.data.get(name, [])
        if generation:
            objects = [obj for obj in objects if obj["generation"] == str(generation)]
        if not objects:
            raise error(404, "notFound")
        return objects[-1]

    def meta(self, obj):
        return {key: copy.deepcopy(value) for key, value in obj.items() if key not in {"body", "key"}}

    def put(self, name, content, key=None):
        self.counter += 1
        obj = {"name": name, "generation": str(self.counter), "size": str(len(content)), "body": content, "acl": [], "key": key}
        if key:
            obj["customerEncryption"] = {"encryptionAlgorithm": "AES256", "keySha256": base64.b64encode(__import__("hashlib").sha256(key).digest()).decode()}
        self.data.setdefault(name, []).append(obj)
        return self.meta(obj)

    def request(self, method, path, *, query=None, data=None, headers=None, anonymous=False, raw=False):
        query, headers = query or {}, headers or {}
        self.requests.append((method, path, copy.deepcopy(query)))
        key = base64.b64decode(headers["X-Goog-Encryption-Key"]) if "X-Goog-Encryption-Key" in headers else None
        if path == "/storage/v1/b":
            return {"items": self.soft if query.get("softDeleted") == "true" else ([self.bucket] if self.bucket else [])}
        if path.endswith("/o") and method == "GET":
            items = []
            for name, values in self.data.items():
                if name.startswith(query.get("prefix", "")):
                    items.extend(self.meta(obj) for obj in (values if query.get("versions") == "true" else values[-1:]))
            return {"items": items}
        if path.startswith("/upload/"):
            name = query["name"]
            previous = self.data.get(name, [])
            expected = previous[-1]["generation"] if previous else "0"
            if str(query["ifGenerationMatch"]) != expected:
                raise error(412, "conditionNotMet")
            return self.put(name, data, key)
        if "/o/" not in path:
            return copy.deepcopy(self.bucket)
        name = unquote(path.split("/o/", 1)[1].split("/rewriteTo/")[0].removesuffix("/acl"))
        obj = self.find(name, query.get("generation"))
        if "/rewriteTo/" in path:
            source_key = base64.b64decode(headers["X-Goog-Copy-Source-Encryption-Key"])
            assert source_key == obj["key"] and key != source_key
            assert str(query["ifSourceGenerationMatch"]) == obj["generation"] == str(query["ifGenerationMatch"])
            if self.rewrite_pending and "rewriteToken" not in query:
                return {"done": False, "rewriteToken": "continuation"}
            return {"done": True, "resource": self.put(name, obj["body"], key)}
        if path.endswith("/acl"):
            if self.pap:
                raise error(412, "conditionNotMet", "Public access prevention is enforced")
            obj["acl"] = [data]
            if self.fail_after_public:
                raise lab.LabError("응답 유실")
            return data
        if method == "PATCH":
            obj["acl"] = []
            obj["cacheControl"] = data["cacheControl"]
            return self.meta(obj)
        if method == "DELETE":
            if self.fail_delete:
                raise error(403)
            assert query["ifGenerationMatch"] == obj["generation"]
            self.data[name].remove(obj)
            return {}
        if query.get("alt") == "media":
            if anonymous and not obj["acl"]:
                raise error(401, "required")
            if obj["key"] != key:
                raise self.wrong_key_error or error(400, "customerEncryptionKeyIsIncorrect")
            return obj["body"]
        if key is not None and obj["key"] != key:
            raise error(400, "customerEncryptionKeyIsIncorrect")
        return self.meta(obj)

    def sync(self, directory):
        for path in directory.rglob("*.html"):
            content = b"corrupt" if self.corrupt_sync else path.read_bytes()
            self.put("firstlevel/" + path.relative_to(directory).as_posix(), content)


class FlowTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.api = FakeStorage()
        self.wait = Mock()
        self.subject = lab.StorageLab(self.api, INPUTS, self.temp.name, sync=self.api.sync, wait=self.wait)
        self.subject.owned(record=True)
        self.fixture = (ROOT / "phases/08/fixture.html").read_bytes()

    def test_full_flow(self):
        result = self.subject.run()
        self.assertTrue(all(item["status"] == "passed" for item in result["tasks"].values()))
        self.assertEqual(result["versions"]["count"], 3)
        self.assertEqual(len(result["sync_sha256"]), 2)
        self.assertFalse(result["lab_completion"]["complete"])
        self.assertEqual(self.api.data["setup2.html"], [])
        self.assertEqual(self.api.data["setup3.html"], [])
        self.assertFalse(any(obj["acl"] for values in self.api.data.values() for obj in values))
        self.wait.assert_any_call(30)
        self.assertEqual((Path(self.temp.name) / "recovered.txt").read_bytes(), self.fixture)

    def test_pap_boundary_is_explicit(self):
        self.api.pap = True
        result = self.subject.run()
        self.assertEqual(result["public_acl"], "policy-prevented")
        self.assertFalse(result["lab_completion"]["public_acl_exercised"])
        self.assertTrue(result["risks"])

    def test_response_lost_after_public_grant_still_revokes(self):
        self.api.fail_after_public = True
        with self.assertRaises(lab.LabError):
            self.subject.acl_test(self.fixture)
        self.assertEqual(self.api.find("setup.html")["acl"], [])

    def test_public_hash_mismatch_still_revokes(self):
        actual = self.subject.download
        with patch.object(self.subject, "download", side_effect=lambda *a, **k: b"bad" if k.get("anonymous") and self.api.find("setup.html")["acl"] else actual(*a, **k)):
            with self.assertRaises(lab.LabError):
                self.subject.acl_test(self.fixture)
        self.assertEqual(self.api.find("setup.html")["acl"], [])

    def test_cleanup_failure_is_not_swallowed(self):
        self.api.fail_delete = True
        with self.assertRaisesRegex(lab.LabError, "cleanup"):
            self.subject.csek_test(self.fixture)
        deletes = [item[1] for item in self.api.requests if item[0] == "DELETE"]
        self.assertTrue(any("setup2" in path for path in deletes))
        self.assertTrue(any("setup3" in path for path in deletes))

    def test_auth_error_is_not_key_denial_and_encrypted_cleanup_runs(self):
        self.api.wrong_key_error = error(401, "authError")
        with self.assertRaisesRegex(lab.LabError, "예상 CSEK 거부가 아님"):
            self.subject.csek_test(self.fixture)
        self.assertEqual(self.api.data["setup2.html"], [])
        self.assertEqual(self.api.data["setup3.html"], [])

    def test_rewrite_continuation(self):
        self.api.rewrite_pending = True
        self.subject.csek_test(self.fixture)
        self.assertEqual(sum("rewriteToken" in query for _, _, query in self.api.requests), 2)

    def test_wrong_fingerprint_rejected(self):
        self.subject.upload("setup2.html", self.fixture, key=b"a" * 32)
        with self.assertRaisesRegex(lab.LabError, "fingerprint"):
            self.subject.encrypted_metadata("setup2.html", b"b" * 32)

    def test_preexisting_objects_not_overwritten(self):
        self.api.put("external.txt", b"keep")
        with self.assertRaisesRegex(lab.LabError, "비어 있지 않은"):
            self.subject.run()
        self.assertEqual(set(self.api.data), {"external.txt"})

    def test_run_retry_not_allowed(self):
        lab.write_json(Path(self.temp.name) / "verification-started.json", {})
        with self.assertRaisesRegex(lab.LabError, "이미 시작한"):
            self.subject.run()

    def test_ownership_and_recreation(self):
        for change in ({"labels": {}}, {"timeCreated": "new"}, {"projectNumber": "999"}):
            with self.subTest(change=change):
                old = copy.deepcopy(self.api.bucket)
                self.api.bucket.update(change)
                with self.assertRaises(lab.LabError):
                    self.subject.owned()
                self.api.bucket = old

    def test_provider_effective_label_does_not_break_ownership(self):
        self.api.bucket["labels"]["goog-terraform-provisioned"] = "true"
        self.subject.owned()

    def test_bucket_policy_drift(self):
        for key, value in (("softDeletePolicy", {"retentionDurationSeconds": "604800"}), ("versioning", {}),
                           ("lifecycle", {}), ("location", "US"), ("encryption", {"defaultKmsKeyName": "x"}),
                           ("retentionPolicy", {"retentionPeriod": "1"})):
            with self.subTest(key=key):
                bad = {**self.api.bucket, key: value}
                with self.assertRaises(lab.LabError):
                    self.subject.settings(bad)

    def test_hash_mismatch_rejected_for_sync(self):
        self.api.corrupt_sync = True
        with self.assertRaisesRegex(lab.LabError, "hash"):
            self.subject.sync_test(self.fixture)

    def test_extra_sync_object_rejected(self):
        self.api.put("firstlevel/unexpected.html", b"extra")
        with self.assertRaisesRegex(lab.LabError, "집합"):
            self.subject.sync_test(self.fixture)

    def test_versions_count_and_size_checked(self):
        generation = self.subject.upload("setup.html", self.fixture)["generation"]
        self.api.put("setup.html-extra", b"extra")
        with self.assertRaisesRegex(lab.LabError, "3세대"):
            self.subject.versions_test(self.fixture, generation)

    def test_absence_does_not_swallow_inventory_failure(self):
        with patch.object(self.api, "items", side_effect=error(403)):
            with self.assertRaises(lab.ApiError):
                self.subject.owned(allow_missing=True)
        self.api.bucket = None
        self.assertIsNone(self.subject.owned(allow_missing=True))

    def test_anonymous_404_network_and_server_failures_rejected(self):
        generation = self.subject.upload("setup.html", self.fixture)["generation"]
        for failure in (error(404, "notFound"), error(500), error(429), lab.LabError("network")):
            with self.subTest(failure=failure), patch.object(self.subject, "download", side_effect=failure):
                with self.assertRaises(lab.LabError):
                    self.subject.anonymous_denied(generation)

    def test_plaintext_anonymous_401_requires_authenticated_controls(self):
        generation = self.subject.upload("setup.html", self.fixture)["generation"]
        actual = self.subject.download
        def download(*args, **kwargs):
            if kwargs.get("anonymous"):
                raise lab.ApiError(401, b"Anonymous caller lacks storage.objects.get")
            return actual(*args, **kwargs)
        with patch.object(self.subject, "download", side_effect=download) as mocked:
            self.subject.anonymous_denied(generation)
        self.assertEqual(mocked.call_count, 3)

    def test_anonymous_denial_with_broken_authenticated_control_fails(self):
        generation = self.subject.upload("setup.html", self.fixture)["generation"]
        with patch.object(self.subject, "download", side_effect=[self.fixture, lab.ApiError(401, b"anonymous denied"), error(401, "authError")]):
            with self.assertRaises(lab.ApiError):
                self.subject.anonymous_denied(generation)

    def test_plaintext_csek_400_needs_matching_metadata_denial(self):
        self.api.wrong_key_error = lab.ApiError(400, b"encryption key incorrect")
        self.subject.csek_test(self.fixture)
        self.assertEqual(sum("fields" in query for _, _, query in self.api.requests), 3)

    def test_unknown_csek_400_and_successful_metadata_is_not_pass(self):
        self.subject.upload("setup2.html", self.fixture, key=b"a" * 32)
        self.api.wrong_key_error = lab.ApiError(400, b"generic bad request")
        actual = self.api.request
        def request(*args, **kwargs):
            if "fields" in kwargs.get("query", {}):
                return {}
            return actual(*args, **kwargs)
        with patch.object(self.api, "request", side_effect=request):
            with self.assertRaisesRegex(lab.LabError, "잘못된 키를 거부하지 않음"):
                self.subject.expect_key_denied("setup2.html", b"b" * 32, b"a" * 32)


class ApiTests(unittest.TestCase):
    def test_action_deadline_blocks_request(self):
        api = lab.Api("test")
        api.deadline = 0
        api.opener = Mock()
        with self.assertRaisesRegex(lab.LabError, "시간 제한"):
            api.request("GET", "/storage/v1/b")
        api.opener.open.assert_not_called()

    def test_key_denial_exact_reasons(self):
        self.assertTrue(lab.key_denial(error(400, "customerEncryptionKeyIsIncorrect")))
        self.assertTrue(lab.key_denial(error(400, "resourceIsEncryptedWithCustomerEncryptionKey")))
        for code, reason in ((401, "authError"), (403, "forbidden"), (400, "invalid"), (404, "notFound"), (500, "customerEncryptionKeyIsIncorrect")):
            self.assertFalse(lab.key_denial(error(code, reason)))

    def test_pap_is_not_any_412(self):
        self.assertFalse(error(412, "conditionNotMet", "generation mismatch").pap)
        self.assertFalse(error(403, "forbidden", "Public access prevention").pap)
        self.assertTrue(error(412, "conditionNotMet", "Public access prevention is enforced").pap)

    def test_pagination_all_pages_and_loop_guard(self):
        api = lab.Api("not-a-real-token")
        with patch.object(api, "request", side_effect=[{"items": [1], "nextPageToken": "two"}, {"items": [2]}]) as request:
            self.assertEqual(api.items("/storage/v1/b", project="example-lab"), [1, 2])
            self.assertEqual(request.call_args.kwargs["query"]["pageToken"], "two")
        with patch.object(api, "request", return_value={"nextPageToken": "repeated"}):
            with self.assertRaises(lab.LabError):
                api.items("/storage/v1/b")

    def test_bad_second_page_not_empty(self):
        api = lab.Api("test")
        with patch.object(api, "request", side_effect=[{"nextPageToken": "two"}, error(403)]):
            with self.assertRaises(lab.ApiError):
                api.items("/storage/v1/b")

    def test_no_redirect_or_token_in_error(self):
        self.assertIsNone(lab.NoRedirect().redirect_request(None, None, 302, "", {}, "https://other.test"))
        api = lab.Api("NEVER-PRINT-TOKEN")
        api.opener = Mock()
        api.opener.open.side_effect = HTTPError("url", 403, "secret", {}, io.BytesIO(b'{"error":{"message":"NEVER-PRINT-TOKEN"}}'))
        with self.assertRaises(lab.ApiError) as captured:
            api.request("GET", "/storage/v1/b")
        self.assertNotIn("NEVER-PRINT", str(captured.exception))
        api.opener.open.side_effect = URLError("NEVER-PRINT-TOKEN")
        with self.assertRaises(lab.LabError) as captured:
            api.request("GET", "/storage/v1/b")
        self.assertNotIn("NEVER-PRINT", str(captured.exception))

    def test_external_endpoint_rejected(self):
        with self.assertRaises(lab.LabError):
            lab.Api("secret").request("GET", "https://other.test/steal")

    def test_csek_headers(self):
        key = bytes(range(32))
        headers = lab.encryption_headers(key)
        self.assertEqual(headers["X-Goog-Encryption-Algorithm"], "AES256")
        self.assertEqual(base64.b64decode(headers["X-Goog-Encryption-Key"]), key)
        self.assertEqual(len(base64.b64decode(headers["X-Goog-Encryption-Key-Sha256"])), 32)
        with self.assertRaises(lab.LabError):
            lab.encryption_headers(b"short")

    def test_rsync_command_has_explicit_account_project_and_no_secret(self):
        subject = lab.StorageLab(lab.Api("secret"), INPUTS, "/unused")
        with patch.object(lab.subprocess, "run", return_value=Mock(returncode=0)) as run:
            subject.rsync(Path("/fixture"))
        argv = run.call_args.args[0]
        self.assertIn("--recursive", argv)
        self.assertIn("--account=learner@example.com", argv)
        self.assertIn("--project=example-lab", argv)
        self.assertNotIn("secret", str(argv))


class PlanTests(unittest.TestCase):
    def plan(self):
        after = {"name": "gcp-lab-p08-" + INPUTS["run_id"], "project": INPUTS["project_id"], "location": "US-CENTRAL1",
                 "force_destroy": True, "uniform_bucket_level_access": False, "public_access_prevention": "inherited",
                 "labels": {"harness": "gcp-lab-harness", "phase": "08", "run": INPUTS["run_id"]},
                 "versioning": [{"enabled": True}], "soft_delete_policy": [{"retention_duration_seconds": 0}],
                 "lifecycle_rule": [{"action": [{"type": "Delete", "storage_class": ""}], "condition": [{"age": 31}]}]}
        return {"resource_changes": [{"address": "google_storage_bucket.lab", "type": "google_storage_bucket", "change": {"actions": ["create"], "after": after}}]}

    def test_expected_plan(self):
        lab.guard_plan(self.plan(), INPUTS)
        plan = self.plan()
        plan["resource_changes"][0]["change"]["after"]["lifecycle_rule"][0]["action"][0]["storage_class"] = None
        lab.guard_plan(plan, INPUTS)

    def test_unsafe_plan_rejected(self):
        for key, value in (("name", "foreign"), ("project", "foreign"), ("location", "US"),
                           ("uniform_bucket_level_access", True), ("public_access_prevention", "enforced"),
                           ("labels", {}), ("versioning", []), ("soft_delete_policy", []), ("lifecycle_rule", [])):
            with self.subTest(key=key):
                plan = self.plan()
                plan["resource_changes"][0]["change"]["after"][key] = value
                with self.assertRaises(lab.LabError):
                    lab.guard_plan(plan, INPUTS)

    def test_update_and_extra_resource_rejected(self):
        plan = self.plan()
        plan["resource_changes"][0]["change"]["actions"] = ["update"]
        with self.assertRaises(lab.LabError):
            lab.guard_plan(plan, INPUTS)
        plan = self.plan()
        plan["resource_changes"].append(copy.deepcopy(plan["resource_changes"][0]))
        with self.assertRaises(lab.LabError):
            lab.guard_plan(plan, INPUTS)

    def test_help_needs_no_credentials(self):
        for script in ("execute.sh", "verify.sh"):
            result = subprocess.run(["bash", str(ROOT / "phases/08" / script), "--help"], capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("사용법", result.stdout)

    def test_fixture_and_code_have_no_personal_accounts_or_stored_keys(self):
        for path in (ROOT / "phases/08").glob("*"):
            if path.is_file():
                content = path.read_text()
                self.assertNotRegex(content, r"\b[\w.+-]+@[\w.-]+\.[a-zA-Z]{2,}\b")
                self.assertNotIn("openssl rand", content)


class ShellTests(unittest.TestCase):
    """실제 Bash adapter를 격리 복제본에서 실행. gcloud/API/Terraform만 stub 처리."""
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        shutil.copytree(ROOT / "lib", self.root / "lib")
        shutil.copytree(ROOT / "phases/08", self.root / "phases/08", ignore=shutil.ignore_patterns(".terraform", "__pycache__"))
        self.run = self.root / "artifacts/runs" / INPUTS["run_id"] / "phase-08"
        self.work = self.run / "work"
        self.work.mkdir(parents=True)
        for name in ("main.tf", ".terraform.lock.hcl"):
            shutil.copy2(self.root / "phases/08/terraform" / name, self.work / name)
        self.tfvars = self.work / "phase-08.auto.tfvars.json"
        lab.write_json(self.tfvars, INPUTS)
        self.bin = self.root / "stub-bin"
        self.bin.mkdir()
        self.env = {**os.environ, "PATH": str(self.bin) + os.pathsep + os.environ["PATH"], "PYTHONDONTWRITEBYTECODE": "1"}
        for name in list(self.env):
            if name.startswith(("P08_", "GOOGLE_", "CLOUDSDK_", "TF_")):
                self.env.pop(name)
        self.script(self.bin / "gcloud", '''#!/usr/bin/env bash
case "$1 $2" in
  "config get-value") [[ "$3" != account ]] || printf 'learner@example.com\\n'; exit 0 ;;
  "auth print-access-token") printf 'test-token\\n'; exit 0 ;;
esac
exit 1
''')
        real_python = shutil.which("python3")
        self.script(self.bin / "python3", f'''#!/usr/bin/env bash
if [[ "$1" == */storage_lab.py ]]; then
  printf '%s\\n' "$2" >>"{self.root}/operations.log"
  case "$2" in
    identity|owned) exit 0 ;;
    verify) exit 17 ;;
    destroyed) exit "${{STUB_DESTROYED_FAIL:-0}}" ;;
  esac
fi
exec "{real_python}" "$@"
''')
        self.script(self.bin / "terraform", f'''#!/usr/bin/env bash
case "$2" in
  show) printf '{{"values":{{"root_module":{{"resources":[]}}}}}}\\n'; exit 0 ;;
  destroy) printf 'destroy\\n' >>"{self.root}/operations.log"; exit 0 ;;
  state) exit 0 ;;
esac
exit 1
''')
        (self.root / "scripts").mkdir()
        self.script(self.root / "scripts/preflight-gcp.sh", "#!/usr/bin/env bash\nexit 0\n")
        (self.root / "config").mkdir()
        (self.root / "config/harness.env").write_text("HARNESS_ENVIRONMENT=lab\nGCP_PROJECT_ID=example-lab\nGCP_ALLOWED_PROJECTS=example-lab\nGCP_REGION=us-central1\nGCP_CLEANUP_ON_FAILURE=true\nGCP_MAX_APPLY_MINUTES=1\n")
        code = self.shell("p08_source_sha").stdout.strip()
        actions = {"phase": "08", "run_id": INPUTS["run_id"], "actions": [
            {"id": "implementation", "target": code}, {"id": "saved-inputs", "target": lab.digest(self.tfvars.read_bytes())}]}
        lab.write_json(self.run / "action-plan.json", actions)
        bundle = {"action_plan": {"sha256": lab.digest((self.run / "action-plan.json").read_bytes())}}
        lab.write_json(self.run / "plan-bundle.json", bundle)
        self.manifest = self.run / "manifest.json"
        lab.write_json(self.manifest, {"status": "applied", "cleanup": {"status": "not_started"}, "plan": {
            "bundle_sha256": lab.digest((self.run / "plan-bundle.json").read_bytes())}})

    def script(self, path, text):
        path.write_text(text)
        path.chmod(0o700)

    def shell(self, command):
        prefix = f'''set -Eeuo pipefail
repo_root="{self.root}"
source "$repo_root/lib/harness/phase-adapter.sh"
source "$repo_root/phases/08/support.sh"
HARNESS_ENVIRONMENT=lab
GCP_PROJECT_ID=example-lab
GCP_ALLOWED_PROJECTS=example-lab
GCP_CLEANUP_ON_FAILURE=true
run_id={INPUTS["run_id"]}
'''
        return subprocess.run(["bash", "-c", prefix + command], env=self.env, text=True, capture_output=True, timeout=20)

    def test_saved_context_accepts_then_detects_input_change(self):
        command = 'p08_context "$run_id"; p08_approved_context'
        self.assertEqual(self.shell(command).returncode, 0)
        lab.write_json(self.tfvars, {**INPUTS, "runner": "changed@example.com"})
        self.assertNotEqual(self.shell(command).returncode, 0)

    def test_source_change_requires_new_plan(self):
        with (self.root / "phases/08/fixture.html").open("a") as stream:
            stream.write("changed\n")
        self.assertNotEqual(self.shell('p08_context "$run_id"; p08_approved_context').returncode, 0)

    def test_work_override_blocked(self):
        for name in ("override.tf", "override.tf.json", "evil.auto.tfvars.json", "terraform.tfvars"):
            with self.subTest(name=name):
                (self.work / name).write_text("{}")
                self.assertNotEqual(self.shell('p08_context "$run_id"; p08_approved_context').returncode, 0)
                (self.work / name).unlink()

    def test_project_allowlist_mismatch_blocked(self):
        self.assertNotEqual(self.shell('GCP_ALLOWED_PROJECTS=other; p08_context "$run_id"').returncode, 0)

    def test_environment_override_blocked(self):
        self.env["TF_CLI_ARGS_destroy"] = "-target=foreign"
        self.assertNotEqual(self.shell('p08_context "$run_id"; p08_identity').returncode, 0)

    def test_verify_failure_destroys_and_retains_failure_exit(self):
        result = subprocess.run(["bash", str(self.root / "phases/08/verify.sh"), "--run", INPUTS["run_id"]],
                                env=self.env, text=True, capture_output=True, timeout=20)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(lab.read_json(self.manifest)["status"], "destroyed", result.stderr)
        self.assertEqual(lab.read_json(self.manifest)["cleanup"]["remaining_resource_count"], 0)
        self.assertFalse(list((self.root / "artifacts/locks").glob("*.lock.d")))
        self.assertIn("destroy\n", (self.root / "operations.log").read_text())

    def test_cleanup_inventory_failure_remains_cleanup_required(self):
        self.env["STUB_DESTROYED_FAIL"] = "1"
        result = subprocess.run(["bash", str(self.root / "phases/08/verify.sh"), "--run", INPUTS["run_id"]],
                                env=self.env, text=True, capture_output=True, timeout=20)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(lab.read_json(self.manifest)["status"], "cleanup_required", result.stderr)

    def test_destroy_state_target_guard(self):
        self.assertEqual(self.shell('p08_context "$run_id"; p08_state_guard').returncode, 0)
        for resource in ({"address": "foreign", "type": "google_storage_bucket", "values": {}},
                         {"address": "google_storage_bucket.lab", "type": "google_storage_bucket", "values": {"id": "foreign"}}):
            state = {"values": {"root_module": {"resources": [resource]}}}
            self.script(self.bin / "terraform", "#!/usr/bin/env bash\nprintf '%s\\n' '" + json.dumps(state) + "'\n")
            self.assertNotEqual(self.shell('p08_context "$run_id"; p08_state_guard').returncode, 0)


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "--terraform-plans":
        checked = set()
        for line in sys.stdin:
            event = json.loads(line)
            if event.get("type") != "test_plan" or event.get("@testrun") == "invalid_run_rejected":
                continue
            inputs = dict(INPUTS)
            if event["@testrun"] == "different_clone_region":
                inputs.update(region="asia-northeast3", run_id="other-p08-run", runner="other@example.com")
            lab.guard_plan(event["test_plan"], inputs)
            checked.add(event["@testrun"])
        lab.require(len(checked) == 3, "Terraform 실제 mock JSON plan 3개 검사 필요")
        print("PASS: Terraform provider mock JSON 3개와 Python plan guard 호환")
    else:
        unittest.main(verbosity=1)
