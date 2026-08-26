#!/usr/bin/env python3
"""Phase 07의 거짓 양성·권한 범위·승인·rollback 회귀 검사(Cloud 호출 없음)."""

import copy
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "phases/07" / (name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


policy = load("plan-guard")
probe = load("iam-probe")
PROJECT, RUN, REGION = "phase07-test", "testp007", "us-central1"
USER1, USER2 = "admin@example.com", "lab@example.com"


def fixture():
    values = {
        "google_project_service.resource_manager": {
            "service": "cloudresourcemanager.googleapis.com", "disable_on_destroy": False,
            "disable_dependent_services": False},
        "google_compute_network.iam": {"name": "p07-net-" + RUN, "auto_create_subnetworks": False},
        "google_compute_subnetwork.iam": {
            "name": "p07-subnet-" + RUN, "region": REGION, "ip_cidr_range": "10.27.0.0/24",
            "private_ip_google_access": True, "network": f"projects/{PROJECT}/global/networks/p07-net-{RUN}"},
        "google_compute_firewall.iap_ssh": {
            "name": "p07-iap-ssh-" + RUN, "network": "p07-net-" + RUN,
            "direction": "INGRESS", "disabled": False, "source_ranges": ["35.235.240.0/20"],
            "target_tags": ["p07-iam-probe"], "allow": [{"protocol": "tcp", "ports": ["22"]}]},
        "google_storage_bucket.iam": {
            "name": "gcp-lab-p07-" + RUN, "location": "US", "storage_class": "STANDARD", "force_destroy": True,
            "public_access_prevention": "enforced", "uniform_bucket_level_access": True,
            "labels": {"run": RUN}, "soft_delete_policy": [{"retention_duration_seconds": 0}]},
        "google_storage_bucket_object.sample": {
            "name": "sample.txt", "bucket": "gcp-lab-p07-" + RUN,
            "content": f"Phase 07 IAM fixture {RUN}\n"},
        "google_project_iam_member.workload_viewer": {
            "role": "roles/storage.objectViewer",
            "member": f"serviceAccount:p07-w-{RUN}@{PROJECT}.iam.gserviceaccount.com"},
        "google_service_account.workload": {"account_id": f"p07-w-{RUN}"},
    }
    return {"resource_changes": [{"address": addr, "type": addr.split(".")[0],
                                   "change": {"actions": ["create"], "after": dict(value, project=PROJECT)}}
                                  for addr, value in values.items()]}


class PlanGuardTests(unittest.TestCase):
    def check(self, plan):
        policy.guard(plan, PROJECT, RUN, REGION, USER1, USER2)

    def test_accept_exact_private_topology(self):
        self.check(fixture())

    def test_reject_unsafe_changes(self):
        cases = [
            ("google_project_service.resource_manager", "service", "unrelated.googleapis.com"),
            ("google_project_service.resource_manager", "disable_on_destroy", True),
            ("google_project_service.resource_manager", "disable_dependent_services", True),
            ("google_compute_subnetwork.iam", "private_ip_google_access", False),
            ("google_compute_subnetwork.iam", "network", "projects/other/global/networks/default"),
            ("google_compute_firewall.iap_ssh", "source_ranges", ["0.0.0.0/0"]),
            ("google_compute_firewall.iap_ssh", "source_tags", ["other"]),
            ("google_compute_firewall.iap_ssh", "allow", [{"protocol": "tcp", "ports": ["1-65535"]}]),
            ("google_compute_firewall.iap_ssh", "direction", "EGRESS"),
            ("google_storage_bucket.iam", "public_access_prevention", "inherited"),
            ("google_storage_bucket.iam", "uniform_bucket_level_access", False),
            ("google_storage_bucket.iam", "soft_delete_policy", [{"retention_duration_seconds": 604800}]),
            ("google_storage_bucket.iam", "project", "production"),
            ("google_storage_bucket.iam", "storage_class", "ARCHIVE"),
            ("google_service_account.workload", "account_id", "default-account"),
            ("google_project_iam_member.workload_viewer", "member", "allAuthenticatedUsers"),
            ("google_project_iam_member.workload_viewer", "member", "user:" + USER2),
            ("google_project_iam_member.workload_viewer", "role", "roles/storage.admin"),
        ]
        for address, field, value in cases:
            with self.subTest(address=address, field=field):
                plan = fixture()
                next(r for r in plan["resource_changes"] if r["address"] == address)["change"]["after"][field] = value
                with self.assertRaises(ValueError):
                    self.check(plan)

    def test_reject_update_delete_extra_missing(self):
        for actions in (["update"], ["delete"], ["delete", "create"], ["no-op"]):
            plan = fixture()
            plan["resource_changes"][0]["change"]["actions"] = actions
            with self.assertRaises(ValueError):
                self.check(plan)
        for delta in ("extra", "missing"):
            plan = fixture()
            if delta == "extra":
                plan["resource_changes"].append(copy.deepcopy(plan["resource_changes"][0]))
            else:
                plan["resource_changes"].pop()
            with self.assertRaises(ValueError):
                self.check(plan)

    def test_unknown_without_exact_dependency_is_rejected(self):
        plan = fixture()
        next(r for r in plan["resource_changes"] if r["address"] == "google_compute_subnetwork.iam")["change"]["after"]["network"] = None
        with self.assertRaises(ValueError):
            self.check(plan)
        plan["configuration"] = {"root_module": {"resources": [{
            "address": "google_compute_subnetwork.iam",
            "expressions": {"network": {"references": ["google_compute_network.iam.id"]}},
        }]}}
        self.check(plan)

    def test_terraform_never_pregrants_actas_or_user_roles(self):
        for role, member in (("roles/iam.serviceAccountUser", "user:" + USER1),
                             ("roles/iam.serviceAccountUser", "user:" + USER2),
                             ("roles/iam.serviceAccountTokenCreator", "allUsers"),
                             ("roles/iam.serviceAccountUser", "domain:altostrat.com")):
            plan = fixture()
            plan["resource_changes"].append({"address": "google_service_account_iam_member.extra", "type": "google_service_account_iam_member",
                                            "change": {"actions": ["create"], "after": {"member": member, "role": role}}})
            with self.subTest(role=role, member=member), self.assertRaises(ValueError):
                self.check(plan)


def args(**kwargs):
    values = dict(operation="read", expect="deny", project=PROJECT, run=RUN, zone=REGION + "-a",
                  region=REGION, bucket="gcp-lab-p07-" + RUN, vm="p07-probe-" + RUN,
                  actor=USER1, guest=False,
                  workload=f"p07-w-{RUN}@{PROJECT}.iam.gserviceaccount.com",
                  permission="compute.instances.create", image="https://www.googleapis.com/compute/v1/projects/debian-cloud/global/images/debian-12-fixture")
    values.update(kwargs)
    return SimpleNamespace(**values)


def vm_operation(a, status="DONE", denied=False):
    zone = f"https://www.googleapis.com/compute/v1/projects/{a.project}/zones/{a.zone}"
    value = {"name": "operation-fixture", "operationType": "insert", "user": a.actor,
             "zone": zone, "targetLink": zone + "/instances/" + a.vm, "status": status}
    if denied:
        value.update(httpErrorStatusCode=400, error={"errors": [{
            "code": "SERVICE_ACCOUNT_ACCESS_DENIED",
            "message": (f"The user does not have access to service account '{a.workload}'. "
                        f"User: '{a.actor}'. Ask a project owner to grant you the iam.serviceAccountUser role on the service account.")} ]})
    return value


class ProbeTests(unittest.TestCase):
    def test_exact_permission_403(self):
        body = {"error": {"code": 403, "message": "Required 'storage.objects.create' permission"}}
        self.assertTrue(probe.exact_denial(403, body, "storage.objects.create"))
        self.assertFalse(probe.exact_denial(403, body, "storage.objects.get"))
        for code in (401, 404, 429, 500):
            self.assertFalse(probe.exact_denial(code, body, "storage.objects.create"))

    def test_scope_api_transport_are_not_iam_denial(self):
        for reason in ("ACCESS_TOKEN_SCOPE_INSUFFICIENT", "SERVICE_DISABLED", "insufficientPermissions", "VPC_SERVICE_CONTROLS"):
            body = {"error": {"code": 403, "message": "storage.objects.create", "reason": reason}}
            self.assertFalse(probe.exact_denial(403, body, "storage.objects.create"))
        self.assertFalse(probe.exact_denial(403, b"permission denied", "storage.objects.create"))

    def test_generic_project_403_needs_permission_test(self):
        body = {"error": {"code": 403, "message": "permission denied"}}
        self.assertFalse(probe.exact_denial(403, body, "resourcemanager.projects.get"))
        self.assertTrue(probe.exact_denial(403, body, "resourcemanager.projects.get", []))
        self.assertFalse(probe.exact_denial(403, body, "resourcemanager.projects.get", ["resourcemanager.projects.get"]))
        self.assertFalse(probe.exact_denial(403, body, "resourcemanager.projects.get", "malformed"))

    def test_permission_token_boundary(self):
        self.assertFalse(probe.exact_denial(403, {"error": "storage.objects.getIamPolicy"}, "storage.objects.get"))

    def test_user_authentication_failure_never_reaches_probe(self):
        with patch.object(probe.subprocess, "run", return_value=SimpleNamespace(returncode=1, stdout="")):
            with self.assertRaises(probe.ProbeError):
                probe.token_for(args())

    def test_real_user_token_is_explicit_and_identity_checked(self):
        with patch.object(probe.subprocess, "run", return_value=SimpleNamespace(returncode=0, stdout="test-token")) as command, \
                patch.object(probe, "request", return_value=(200, {"email": USER1, "verified_email": True})):
            self.assertEqual(probe.token_for(args()), "test-token")
        self.assertIn("--account=" + USER1, command.call_args.args[0])
        self.assertFalse(any("impersonate" in item for item in command.call_args.args[0]))

    def test_wrong_or_unverified_oauth_identity_is_rejected(self):
        for identity in ({"email": USER2, "verified_email": True}, {"email": USER1, "verified_email": False}, {}):
            with patch.object(probe.subprocess, "run", return_value=SimpleNamespace(returncode=0, stdout="test-token")), \
                    patch.object(probe, "request", return_value=(200, identity)):
                with self.assertRaises(probe.ProbeError):
                    probe.token_for(args())

    def test_service_account_and_token_override_cannot_replace_user(self):
        with self.assertRaises(probe.ProbeError):
            probe.user_token("actor@test.iam.gserviceaccount.com")
        with patch.dict(probe.os.environ, {"CLOUDSDK_AUTH_ACCESS_TOKEN": "override-not-real"}):
            with self.assertRaises(probe.ProbeError):
                probe.user_token(USER1)

    def test_storage_generic_denial_requires_same_user_permission_test(self):
        for check, expected in (((200, {}), True), ((403, {}), False),
                                ((200, {"permissions": ["storage.objects.get"]}), False)):
            with patch.object(probe, "request", side_effect=[(403, {"error": {"message": "Forbidden"}}), check]):
                if expected:
                    self.assertEqual(probe.evaluate(args(), "test-token")["result"], "denied")
                else:
                    with self.assertRaises(probe.ProbeError):
                        probe.evaluate(args(), "test-token")

    def test_guest_requires_exact_metadata_identity_and_scope(self):
        a = args(guest=True)
        with patch.object(probe, "request", return_value=(200, b"wrong-account")):
            with self.assertRaises(probe.ProbeError):
                probe.token_for(a)
        with patch.object(probe, "request", side_effect=[(200, a.actor.encode()), (200, b"devstorage.read_write")]):
            with self.assertRaises(probe.ProbeError):
                probe.token_for(a)

    def test_wrong_fixture_not_success(self):
        with patch.object(probe, "request", return_value=(200, b"wrong content")):
            with self.assertRaises(probe.ProbeError):
                probe.evaluate(args(expect="allow"), "not-a-real-token")

    def test_create_unexpected_success_stops_without_retry(self):
        for operation in ("write", "create-vm"):
            with patch.object(probe, "request", return_value=(200, {"name": "unexpected"})):
                with self.assertRaises(probe.ProbeError):
                    probe.evaluate(args(operation=operation), "not-a-real-token")

    def test_async_actas_denial_waits_for_done_and_checks_permission(self):
        a = args(operation="create-vm", permission="iam.serviceAccounts.actAs")
        responses = [(200, vm_operation(a, "RUNNING")), (200, vm_operation(a, denied=True)),
                     (404, {"error": {"code": 404}}), (200, {})]
        with patch.object(probe, "request", side_effect=responses) as request, patch.object(probe.time, "sleep"):
            result = probe.evaluate(a, "not-a-real-token")
        self.assertEqual(result["result"], "denied")
        self.assertEqual(result["http_status"], 200)
        self.assertEqual(result["operation_http_error_status"], 400)
        self.assertEqual(result["operation_status"], "DONE")
        self.assertTrue(result["instance_absent"])
        self.assertEqual(request.call_count, 4)
        self.assertTrue(request.call_args_list[-1].args[0].endswith(":testIamPermissions"))

    def test_async_unexpected_actual_success_fails(self):
        a = args(operation="create-vm", permission="iam.serviceAccounts.actAs")
        with patch.object(probe, "request", return_value=(200, vm_operation(a))):
            with self.assertRaises(probe.ProbeError):
                probe.evaluate(a, "not-a-real-token")

    def test_async_allow_waits_for_successful_done(self):
        a = args(operation="create-vm", expect="allow")
        with patch.object(probe, "request", side_effect=[(200, vm_operation(a, "PENDING")),
                                                        (200, vm_operation(a))]), patch.object(probe.time, "sleep"):
            result = probe.evaluate(a, "not-a-real-token")
        self.assertEqual(result["result"], "allowed")
        self.assertEqual(result["operation_status"], "DONE")

    def test_async_allow_retries_only_terminal_iam_failure_without_vm(self):
        a = args(operation="create-vm", expect="allow")
        with patch.object(probe, "request", side_effect=[(200, vm_operation(a, denied=True)), (404, {})]):
            self.assertIsNone(probe.evaluate(a, "not-a-real-token"))

    def test_async_operation_identity_mismatch_is_rejected(self):
        a = args(operation="create-vm", permission="iam.serviceAccounts.actAs")
        for key, value in (("name", "../../other"), ("zone", "wrong-zone"), ("user", "other@account"),
                           ("targetLink", "https://attacker.invalid/instances/" + a.vm),
                           ("operationType", "delete"), ("status", "UNKNOWN")):
            with self.subTest(key=key):
                operation = vm_operation(a, denied=True)
                operation[key] = value
                with patch.object(probe, "request", return_value=(200, operation)):
                    with self.assertRaises(probe.ProbeError):
                        probe.evaluate(a, "not-a-real-token")

    def test_async_other_failure_not_expected_denial_or_retry(self):
        a = args(operation="create-vm", permission="iam.serviceAccounts.actAs")
        for change in ("quota", "other-actor", "other-account", "scope", "status", "malformed", "empty-error"):
            operation = vm_operation(a, denied=True)
            error = operation["error"]["errors"][0]
            if change == "quota":
                error["code"] = "QUOTA_EXCEEDED"
            elif change == "other-actor":
                error["message"] = error["message"].replace(a.actor, "other@account")
            elif change == "other-account":
                error["message"] = error["message"].replace(a.workload, "other@account")
            elif change == "scope":
                error["message"] += " ACCESS_TOKEN_SCOPE_INSUFFICIENT"
            elif change == "status":
                operation["httpErrorStatusCode"] = 500
            elif change == "malformed":
                operation["error"]["errors"] = None
            else:
                operation["error"] = {}
            for expect in ("deny", "allow"):
                a.expect = expect
                with self.subTest(change=change, expect=expect), patch.object(probe, "request", return_value=(200, operation)):
                    with self.assertRaises(probe.ProbeError):
                        probe.evaluate(a, "not-a-real-token")

    def test_async_actas_denial_needs_valid_absent_permission(self):
        a = args(operation="create-vm", permission="iam.serviceAccounts.actAs")
        for check in ((403, {}), (200, {"permissions": [a.permission]}),
                      (200, {"permissions": "malformed"}), (200, {"error": "invalid"})):
            with self.subTest(check=check), patch.object(probe, "request", side_effect=[
                    (200, vm_operation(a, denied=True)), (404, {}), check]):
                with self.assertRaises(probe.ProbeError):
                    probe.evaluate(a, "not-a-real-token")

    def test_async_failure_with_residual_vm_or_failed_get_is_rejected(self):
        for expect in ("allow", "deny"):
            a = args(operation="create-vm", expect=expect, permission="iam.serviceAccounts.actAs")
            for code in (200, 401, 403, 500):
                with self.subTest(expect=expect, code=code), patch.object(probe, "request", side_effect=[
                        (200, vm_operation(a, denied=True)), (code, {})]):
                    with self.assertRaises(probe.ProbeError):
                        probe.evaluate(a, "not-a-real-token")

    def test_async_failed_operation_get_or_timeout_not_denial(self):
        a = args(operation="create-vm", permission="iam.serviceAccounts.actAs")
        with patch.object(probe, "request", side_effect=[(200, vm_operation(a, "RUNNING")), (403, {})]), \
                patch.object(probe.time, "sleep"):
            with self.assertRaises(probe.ProbeError):
                probe.evaluate(a, "not-a-real-token")
        with patch.object(probe, "request", return_value=(200, vm_operation(a, "RUNNING"))), \
                patch.object(probe.time, "monotonic", side_effect=[0, 301]):
            with self.assertRaises(probe.ProbeError):
                probe.evaluate(a, "not-a-real-token")

    def test_async_actas_error_does_not_prove_compute_permission_denial(self):
        a = args(operation="create-vm", permission="compute.instances.create")
        with patch.object(probe, "request", side_effect=[(200, vm_operation(a, denied=True)), (404, {})]):
            with self.assertRaises(probe.ProbeError):
                probe.evaluate(a, "not-a-real-token")

    def test_vm_has_no_public_ip_and_has_cloud_platform_scope(self):
        body = probe.vm_body(args())
        self.assertFalse(any(nic.get("accessConfigs") for nic in body["networkInterfaces"]))
        self.assertEqual(body["serviceAccounts"][0]["scopes"], ["https://www.googleapis.com/auth/cloud-platform"])
        self.assertEqual(body["disks"][0]["initializeParams"]["diskSizeGb"], "10")
        self.assertTrue(body["disks"][0]["autoDelete"])

    def test_permission_check_failure_not_absence(self):
        with patch.object(probe, "request", return_value=(403, {"error": "denied"})):
            with self.assertRaises(probe.ProbeError):
                probe.evaluate(args(operation="actas"), "not-a-real-token")
        with patch.object(probe, "request", return_value=(200, {"permissions": ["iam.serviceAccounts.actAs"]})):
            self.assertIsNone(probe.evaluate(args(operation="actas"), "not-a-real-token"))

    def test_service_disabled_waits_only_in_readiness_probe(self):
        response = {"error": {"code": 403, "details": [{"reason": "SERVICE_DISABLED"}]}}
        with patch.object(probe, "request", return_value=(403, response)):
            self.assertIsNone(probe.evaluate(args(operation="api-ready", expect="allow"), "not-a-real-token"))
            with self.assertRaises(probe.ProbeError):
                probe.evaluate(args(operation="project", expect="deny"), "not-a-real-token")

    def test_readiness_is_not_permission_success(self):
        response = {"error": {"code": 403, "message": "Permission denied"}}
        with patch.object(probe, "request", return_value=(403, response)):
            evidence = probe.evaluate(args(operation="api-ready", expect="allow"), "not-a-real-token")
            self.assertEqual(evidence["result"], "ready")
            self.assertEqual(evidence["check"], "api-readiness-only")
            self.assertNotIn("permission", evidence)


class HarnessTests(unittest.TestCase):
    def shell(self, script, **env):
        return subprocess.run(["bash", "-c", 'repo_root="$1"; user1=admin@example.com; user2=lab@example.com; workload=w; source "$repo_root/lib/harness/terraform.sh"; source "$repo_root/phases/07/support.sh"; ' + script,
                               "test", str(ROOT)], text=True, capture_output=True, check=False, env=env or None)

    def test_tuple_guard_never_calls_gcloud_for_real_user(self):
        result = self.shell('actor1=a; actor2=b; workload=w; gcloud(){ echo UNSAFE >&2; }; p07_binding add project user:owner@example.com roles/owner')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("UNSAFE", result.stderr)

    def test_subnet_inventory_uses_supported_gcloud_group(self):
        result = self.shell('p07_project=test; gcloud(){ printf "%s\\n" "$*"; }; p07_compute_inventory subnetworks')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "compute networks subnets list --account=admin@example.com --project=test --format=json")

    def test_unconditional_exact_remove(self):
        result = self.shell('p07_project=test; p07_policy(){ printf \'%s\\n\' \'{"bindings":[{"role":"roles/viewer","members":["user:lab@example.com"]}]}\'; }; gcloud(){ printf \'%s\\n\' "$*" >&2; }; p07_binding remove project user:lab@example.com roles/viewer')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--condition=None", result.stderr)
        self.assertNotIn("--all", result.stderr)

    def test_policy_hash_ignores_etag_not_binding(self):
        result = self.shell('printf \'%s\\n\' \'{"etag":"one","bindings":[]}\' | p07_policy_hash; printf \'%s\\n\' \'{"etag":"two","bindings":[]}\' | p07_policy_hash')
        lines = result.stdout.splitlines()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(lines[0], lines[1])

    def test_rollback_failure_is_not_swallowed(self):
        with tempfile.TemporaryDirectory() as directory:
            journal = Path(directory) / "rollback.json"
            journal.write_text(json.dumps({"run_id": RUN, "project": PROJECT, "user1": USER1, "user2": USER2, "user2_baseline_empty": True, "user2_workload_baseline_empty": True}))
            result = self.shell(f'journal={journal}; run_id={RUN}; p07_project={PROJECT}; actor1=a; actor2=b; workload=w; '
                                'p07_assert_identities(){ return 0; }; p07_binding(){ return 17; }; p07_rollback')
            self.assertEqual(result.returncode, 1, result.stderr)

    def test_workload_identity_failure_still_revokes_temporary_user_roles(self):
        with tempfile.TemporaryDirectory() as directory:
            journal = Path(directory) / "rollback.json"
            journal.write_text(json.dumps({"run_id": RUN, "project": PROJECT, "user1": USER1, "user2": USER2, "user2_baseline_empty": True, "user2_workload_baseline_empty": True}))
            result = self.shell(f'journal={journal}; run_id={RUN}; p07_project={PROJECT}; '
                                'p07_assert_identities(){ return 1; }; p07_binding(){ printf "%s\\n" "$*"; }; p07_rollback')
            self.assertEqual(result.returncode, 1)
            self.assertEqual(result.stdout.splitlines(), [f"remove project user:{USER2} roles/viewer", f"remove project user:{USER2} roles/storage.objectViewer", f"remove project user:{USER2} roles/compute.instanceAdmin.v1"])

    def test_project_and_object_permissions_are_checked_on_correct_resources(self):
        auth = load("auth")
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "users.json"
            config.write_text(json.dumps({"identity_mode": "two-users", "user1": USER1, "user2": USER2}))
            calls = []
            def response(url, token, method="GET", body=None):
                calls.append((url, token, method, body))
                if method == "POST":
                    self.assertFalse(any(p.startswith("storage.objects.") for p in body["permissions"]))
                    return 200, {"permissions": body["permissions"] if token == USER1 else []}
                return 200, {"permissions": ["storage.objects.get", "storage.objects.list", "storage.objects.create"] if token == USER1 else []}
            with patch.object(auth.sys, "argv", ["auth.py", "--config", str(config), "--project", PROJECT, "--bucket", "fixture-bucket"]), \
                    patch.object(auth.subprocess, "run", return_value=SimpleNamespace(returncode=0, stdout="(unset)")), \
                    patch.object(auth.probe, "user_token", side_effect=lambda user: user), patch.object(auth.probe, "request", side_effect=response), \
                    patch.object(auth.sys, "stdout", new_callable=io.StringIO):
                auth.main()
            self.assertEqual(len(calls), 4)
            self.assertTrue(all("/iam/testPermissions?" in url for url, _, method, _ in calls if method == "GET"))

    def test_inherited_user2_object_permissions_fail_before_role_changes(self):
        auth = load("auth")
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "users.json"
            config.write_text(json.dumps({"identity_mode": "two-users", "user1": USER1, "user2": USER2}))
            with patch.object(auth.sys, "argv", ["auth.py", "--config", str(config), "--only", "user2", "--bucket", "fixture-bucket"]), \
                    patch.object(auth.subprocess, "run", return_value=SimpleNamespace(returncode=0, stdout="(unset)")), \
                    patch.object(auth.probe, "user_token", return_value="test-token"), \
                    patch.object(auth.probe, "request", return_value=(200, {"permissions": ["storage.objects.get"]})):
                with self.assertRaisesRegex(ValueError, "기존/상속 Storage"):
                    auth.main()

    def test_cleanup_refuses_unowned_vm(self):
        with tempfile.TemporaryDirectory() as directory:
            journal = Path(directory) / "rollback.json"
            journal.touch()
            result = self.shell(f'journal={journal}; run_id={RUN}; p07_project={PROJECT}; p07_zone={REGION}-a; vm=p07-probe-{RUN}; '
                                'gcloud(){ if [[ "$*" == *" delete "* ]]; then echo UNSAFE >&2; return 0; fi; '
                                'printf \'%s\\n\' \'[{"name":"existing-production-vm","labels":{}}]\'; }; p07_delete_probe')
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn("UNSAFE", result.stderr)

    def test_cleanup_list_failure_is_not_absence(self):
        with tempfile.TemporaryDirectory() as directory:
            journal = Path(directory) / "rollback.json"
            journal.touch()
            result = self.shell(f'journal={journal}; run_id={RUN}; p07_project={PROJECT}; vm=p07-probe-{RUN}; '
                                'gcloud(){ return 13; }; p07_delete_probe')
            self.assertNotEqual(result.returncode, 0)

    def test_common_adapter_checks_evidence_root(self):
        text = (ROOT / "lib/harness/phase-adapter.sh").read_text()
        expression = re.search(r'jq -e --slurpfile contract "\$contract_file" \'(.*?)\' "\$evidence_file"', text, re.S).group(1)
        with tempfile.TemporaryDirectory() as directory:
            contract = Path(directory) / "contract.json"
            contract.write_text(json.dumps({"phase": "07", "source_tasks": [{"id": "task-1"}]}))
            for status, expected in (("passed", 0), ("failed", 1), (None, 1)):
                evidence = {"phase": "07", "tasks": {"task-1": {"status": status}}}
                result = subprocess.run(["jq", "-e", "--slurpfile", "contract", str(contract), expression], input=json.dumps(evidence), text=True, capture_output=True)
                self.assertEqual(result.returncode, expected, result.stderr)

    def test_existing_actor_binding_is_rejected_before_journal(self):
        text = (ROOT / "phases/07/verify.sh").read_text()
        expression = '[.bindings[]?.members[]? | select(.==$u)] | length==0'
        self.assertIn(expression, text)
        for role, member, expected in (("roles/viewer", "user:" + USER1, 0),
                                       ("roles/viewer", "user:" + USER2, 1),
                                       ("roles/logging.viewer", "user:" + USER2, 1)):
            policy_doc = {"bindings": [{"role": role, "members": [member]}]}
            result = subprocess.run(["jq", "-e", "--arg", "u", "user:" + USER2, expression],
                                    input=json.dumps(policy_doc), text=True, capture_output=True)
            self.assertEqual(result.returncode, expected, result.stderr)

    def test_admin_and_bucket_scope_user_grants_are_rejected(self):
        for command in ("project user:admin@example.com roles/viewer", "bucket user:lab@example.com roles/storage.objectViewer",
                        "project domain:altostrat.com roles/compute.instanceAdmin.v1"):
            result = self.shell('gcloud(){ echo UNSAFE >&2; }; p07_binding add ' + command)
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn("UNSAFE", result.stderr)

    def test_auth_config_requires_two_human_identities(self):
        auth = load("auth")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "users.json"
            for user2, allowed in ((USER2, True), (USER1, False), ("actor@test.iam.gserviceaccount.com", False)):
                path.write_text(json.dumps({"identity_mode": "two-users", "user1": USER1, "user2": user2}))
                if allowed:
                    self.assertEqual(auth.load_users(path)["user2"], USER2)
                else:
                    with self.assertRaises(ValueError):
                        auth.load_users(path)

    def test_private_users_config_ignored_and_login_preserves_active_user(self):
        result = subprocess.run(["git", "check-ignore", "config/phase-07-users.json"], cwd=ROOT, capture_output=True)
        self.assertEqual(result.returncode, 0)
        text = (ROOT / "phases/07/auth.py").read_text()
        self.assertIn('["gcloud", "auth", "login", account, "--no-activate"]', text)
        self.assertNotIn("--update-adc", text)

    def test_project_level_viewer_does_not_assume_project_get_denial(self):
        text = (ROOT / "phases/07/verify.sh").read_text()
        self.assertIn('p07_binding add project "user:$user2" roles/storage.objectViewer', text)
        self.assertIn('probe storage-project-role-boundary "$user2" project "$project_expect"', text)
        self.assertIn('probe storage-compute-deny "$user2" compute deny', text)

    def test_code_or_inputs_change_invalidates_approval(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            inputs = path / "inputs.json"
            inputs.write_text("{}")
            actions = {"phase": "07", "run_id": RUN, "actions": [
                {"id": "implementation", "target": "a" * 64},
                {"id": "saved-inputs", "target": hashlib.sha256(inputs.read_bytes()).hexdigest()},
                {"id": "probe-vm", "target": "test image=https://www.googleapis.com/compute/v1/projects/debian-cloud/global/images/debian-12-fixture"}]}
            (path / "action-plan.json").write_text(json.dumps(actions))
            bundle = {"action_plan": {"sha256": hashlib.sha256((path / "action-plan.json").read_bytes()).hexdigest()}}
            (path / "plan-bundle.json").write_text(json.dumps(bundle))
            (path / "manifest.json").write_text(json.dumps({"plan": {"bundle_sha256": hashlib.sha256((path / "plan-bundle.json").read_bytes()).hexdigest()}}))
            setup = f'run_dir={path}; run_id={RUN}; tfvars={inputs}; manifest={path}/manifest.json; '
            for sha, expected in (("a" * 64, 0), ("b" * 64, 1)):
                result = self.shell(setup + f'p07_source_sha() {{ echo {sha}; }}; p07_assert_approved_context')
                self.assertEqual(result.returncode, expected, result.stderr)
            inputs.write_text('{"tampered":true}')
            result = self.shell(setup + 'p07_source_sha(){ echo ' + 'a' * 64 + '; }; p07_assert_approved_context')
            self.assertNotEqual(result.returncode, 0)


class NotionContractTests(unittest.TestCase):
    def test_workload_actas_and_project_compute_grants_only_target_user2(self):
        harness = HarnessTests()
        for scope, role in (("workload", "roles/iam.serviceAccountUser"), ("project", "roles/compute.instanceAdmin.v1")):
            result = harness.shell('p07_project=test; p07_assert_identities(){ return 0; }; p07_policy(){ echo \'{"bindings":[]}\'; }; '
                                   'gcloud(){ printf "%s\\n" "$*" >&2; }; '
                                   f'p07_binding add {scope} user:{USER2} {role}')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("--member=user:" + USER2, result.stderr)
            self.assertIn("--account=" + USER1, result.stderr)
            self.assertIn("--condition=None", result.stderr)
            if scope == "workload":
                self.assertIn("iam service-accounts add-iam-policy-binding w", result.stderr)
            else:
                self.assertIn("projects add-iam-policy-binding test", result.stderr)
        for scope, member, role in (("workload", USER1, "roles/iam.serviceAccountUser"),
                                    ("project", USER2, "roles/iam.serviceAccountUser"),
                                    ("project", USER2, "roles/owner"), ("project", USER2, "roles/editor")):
            result = harness.shell(f'gcloud(){{ echo UNSAFE >&2; }}; p07_binding add {scope} user:{member} {role}')
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn("UNSAFE", result.stderr)

    def test_rollback_removes_all_four_temporary_user_roles(self):
        harness = HarnessTests()
        with tempfile.TemporaryDirectory() as directory:
            journal = Path(directory) / "journal.json"
            journal.write_text(json.dumps({"run_id": RUN, "project": PROJECT, "user1": USER1, "user2": USER2,
                                           "user2_baseline_empty": True, "user2_workload_baseline_empty": True}))
            result = harness.shell(f'journal={journal}; run_id={RUN}; p07_project={PROJECT}; '
                                   'p07_assert_identities(){ return 0; }; p07_binding(){ printf "%s\\n" "$*"; }; p07_rollback')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.splitlines(), [
                f"remove project user:{USER2} roles/viewer", f"remove project user:{USER2} roles/storage.objectViewer",
                f"remove project user:{USER2} roles/compute.instanceAdmin.v1", f"remove workload user:{USER2} roles/iam.serviceAccountUser",
                "remove project serviceAccount:w roles/storage.objectCreator", "add project serviceAccount:w roles/storage.objectViewer"])

    def test_workload_grant_refuses_recreated_service_account(self):
        result = HarnessTests().shell('p07_assert_identities(){ return 1; }; gcloud(){ echo UNSAFE >&2; }; '
                                       f'p07_binding add workload user:{USER2} roles/iam.serviceAccountUser')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("UNSAFE", result.stderr)

    def test_actas_rollback_requires_empty_original_workload_policy(self):
        harness = HarnessTests()
        with tempfile.TemporaryDirectory() as directory:
            journal = Path(directory) / "journal.json"
            journal.write_text(json.dumps({"run_id": RUN, "project": PROJECT, "user1": USER1, "user2": USER2, "user2_baseline_empty": True}))
            result = harness.shell(f'journal={journal}; run_id={RUN}; p07_project={PROJECT}; '
                                   'p07_assert_identities(){ return 0; }; p07_binding(){ printf "%s\\n" "$*"; }; p07_rollback')
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn("remove workload", result.stdout)

    def test_notion_identity_order_and_final_creator_read_denial(self):
        script = (ROOT / "phases/07/verify.sh").read_text()
        steps = [
            'probe user2-actas-baseline-deny "$user2" actas deny',
            'p07_binding add project "user:$user2" roles/viewer',
            'p07_binding remove project "user:$user2" roles/viewer',
            'probe revoked-storage-read "$user2" read deny',
            'p07_binding add project "user:$user2" roles/storage.objectViewer',
            'probe storage-read "$user2" read allow',
            'p07_binding add workload "user:$user2" roles/iam.serviceAccountUser',
            'p07_binding add project "user:$user2" roles/compute.instanceAdmin.v1',
            'probe user2-create-vm "$user2" create-vm allow',
            'probe user2-vm-running "$user2" vm-status allow',
            'guest_probe guest-object-read read allow',
            'guest_probe guest-object-write-deny write deny',
            'p07_binding remove project "serviceAccount:$workload" roles/storage.objectViewer',
            'p07_binding add project "serviceAccount:$workload" roles/storage.objectCreator',
            'guest_probe guest-creator-write write allow',
            'guest_probe guest-creator-read-deny read deny',
            'probe rollback-storage-deny "$user2" read deny',
            'probe rollback-compute-deny "$user2" compute-create-permission deny',
            'probe rollback-actas-deny "$user2" actas deny',
            'probe rollback-admin-preserved "$user1" policy-edit-permission allow',
        ]
        positions = [script.index(step) for step in steps]
        self.assertEqual(positions, sorted(positions))
        self.assertNotIn('probe user1-create-vm', script)
        self.assertIn('gcloud compute ssh "$vm" --account="$user1"', script)
        self.assertIn('resource_cleanup:"pending-approved-destroy",complete:false', script)

    def test_action_plan_discloses_all_existing_vm_scope_and_user2_actor(self):
        script = (ROOT / "phases/07/execute.sh").read_text()
        self.assertIn('ALL project VMs including existing ones', script)
        self.assertIn('"User2="+$user2+" (not administrator User1)', script)
        self.assertIn('cannot read existing sample.txt', script)
        self.assertIn('HARNESS_PHASE_RESOURCE_LIMIT=8', script)

    def vm(self, **updates):
        a = args(operation="vm-status", expect="allow", actor=USER2)
        value = {"name": a.vm, "zone": "https://compute.googleapis.com/compute/v1/projects/" + PROJECT + "/zones/" + a.zone,
                 "status": "RUNNING", "machineType": "zones/" + a.zone + "/machineTypes/e2-micro",
                 "labels": {"harness": "gcp-lab-harness", "phase": "07", "run": RUN},
                 "serviceAccounts": [{"email": a.workload, "scopes": ["https://www.googleapis.com/auth/cloud-platform"]}],
                 "networkInterfaces": [{"subnetwork": f"https://compute.googleapis.com/compute/v1/projects/{PROJECT}/regions/{REGION}/subnetworks/p07-subnet-{RUN}"}]}
        value.update(updates)
        return a, value

    def test_vm_is_running_with_exact_workload_and_private_subnet(self):
        a, value = self.vm()
        with patch.object(probe, "request", return_value=(200, value)):
            evidence = probe.evaluate(a, "user2-token")
        self.assertEqual(evidence["vm_status"], "RUNNING")
        self.assertTrue(evidence["private_vm"])
        self.assertEqual(evidence["workload_principal_sha256"], hashlib.sha256(a.workload.encode()).hexdigest())

    def test_vm_creation_acceptance_and_wrong_identity_are_not_running_success(self):
        for status in ("PROVISIONING", "STAGING"):
            a, value = self.vm(status=status)
            with patch.object(probe, "request", return_value=(200, value)):
                self.assertIsNone(probe.evaluate(a, "user2-token"))
        for update in ({"status": "TERMINATED"}, {"name": "someone-elses-vm"}, {"serviceAccounts": []},
                       {"labels": {}}, {"zone": "other-zone"}, {"machineType": "zones/x/machineTypes/e2-standard-8"},
                       {"networkInterfaces": []}, {"networkInterfaces": [{"subnetwork": "other", "accessConfigs": [{"natIP": "203.0.113.1"}]}]}):
            a, value = self.vm(**update)
            with self.subTest(update=update), patch.object(probe, "request", return_value=(200, value)), self.assertRaises(probe.ProbeError):
                probe.evaluate(a, "user2-token")

    def test_malformed_permission_reply_cannot_prove_denial(self):
        for operation in ("actas", "compute-create-permission", "policy-edit-permission"):
            for reply in ({"error": "failure"}, {"permissions": None}, {"permissions": [123]}, {"permissions": "invalid"}):
                with self.subTest(operation=operation, reply=reply), patch.object(probe, "request", return_value=(200, reply)), self.assertRaises(probe.ProbeError):
                    probe.evaluate(args(operation=operation), "user2-token")


class AccountSetupTests(unittest.TestCase):
    def setUp(self):
        self.auth = load("auth")
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.config = Path(self.directory.name) / "users.json"
        self.users = {"identity_mode": "two-users", "user1": USER1, "user2": USER2}

    def existing(self):
        self.config.write_text(json.dumps(self.users))

    def main(self, *options):
        with patch.object(self.auth.sys, "argv", ["auth.py", "--config", str(self.config), *options]):
            self.auth.main()

    def isolated_cli(self):
        clone = self.config.parent / "clone"
        (clone / "phases/07").mkdir(parents=True)
        (clone / "bin").mkdir()
        shutil.copytree(ROOT / "lib", clone / "lib")
        shutil.copy2(ROOT / "bin/gcp-lab-harness", clone / "bin/gcp-lab-harness")
        for name in ("auth.py", "auth.sh", "iam-probe.py"):
            shutil.copy2(ROOT / "phases/07" / name, clone / "phases/07" / name)
        return clone, clone / "bin/gcp-lab-harness", clone / "config/phase-07-users.json"

    def test_actual_cli_registers_and_replaces_each_users_accounts_without_login(self):
        clone, command, config = self.isolated_cli()
        for user1, user2 in ((USER1, USER2), ("nextadmin@example.com", "nextlab@example.com")):
            result = subprocess.run([str(command), "accounts", "setup", "--user1", user1, "--user2", user2, "--no-login"],
                                    stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(self.auth.load_users(config), {"identity_mode": "two-users", "user1": user1, "user2": user2})
            self.assertNotIn(user1, result.stdout)
        self.assertFalse((clone / "artifacts").exists())

    def test_actual_noninteractive_cli_missing_setup_stops_without_writes(self):
        clone, command, config = self.isolated_cli()
        for args in ([str(command), "accounts", "setup"], [str(command), "accounts", "check"],
                     [str(clone / "phases/07/auth.sh"), "--ensure"]):
            result = subprocess.run(args, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertIn("--setup", result.stderr)
            self.assertFalse(config.exists())

    @unittest.skipIf(os.name == "nt", "PTY 기반 Linux 입력 점검; Windows는 별도 실기동 확인")
    def test_actual_terminal_prompt_reuses_saved_emails(self):
        import pty
        clone, command, config = self.isolated_cli()
        self.auth.save_users(config, self.users)
        master, slave = pty.openpty()
        process = None
        try:
            process = subprocess.Popen([str(command), "accounts", "setup", "--no-login"], stdin=slave,
                                       stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            os.close(slave)
            slave = None
            os.write(master, b"\n\n")
            stdout, stderr = process.communicate(timeout=10)
            self.assertEqual(process.returncode, 0, stderr)
            self.assertIn("User1", stdout)
            self.assertIn("User2", stdout)
            self.assertEqual(self.auth.load_users(config), self.users)
        finally:
            if process is not None and process.poll() is None:
                process.kill()
                process.communicate()
            if slave is not None:
                os.close(slave)
            os.close(master)

    def test_prompt_creates_normalized_private_config_without_secrets(self):
        with patch.object(self.auth, "active_user", return_value=""), patch.object(self.auth.sys, "stdout", new_callable=io.StringIO) as output:
            users = self.auth.setup_users(self.config, interactive=True, input_fn=lambda prompt: " ADMIN@EXAMPLE.COM " if "User1" in prompt else " LAB@EXAMPLE.COM ")
        self.assertEqual(users, self.users)
        self.assertEqual(json.loads(self.config.read_text()), self.users)
        self.assertNotIn(USER1, output.getvalue())
        if os.name != "nt":
            self.assertEqual(self.config.stat().st_mode & 0o777, 0o600)

    def test_prompt_reuses_existing_values_and_not_active_account(self):
        self.existing()
        with patch.object(self.auth, "active_user") as active, patch.object(self.auth.sys, "stdout", new_callable=io.StringIO):
            users = self.auth.setup_users(self.config, interactive=True, input_fn=lambda prompt: "")
        active.assert_not_called()
        self.assertEqual(users, self.users)

    def test_prompt_uses_active_human_as_admin_default(self):
        with patch.object(self.auth, "active_user", return_value=USER1), patch.object(self.auth.sys, "stdout", new_callable=io.StringIO):
            users = self.auth.setup_users(self.config, interactive=True, input_fn=lambda prompt: "" if "User1" in prompt else USER2)
        self.assertEqual(users, self.users)

    def test_fresh_clone_uses_the_cloners_accounts_not_previous_users(self):
        clone_admin, clone_lab = "another-admin@example.net", "another-lab@example.net"
        with patch.object(self.auth, "active_user", return_value=clone_admin), patch.object(self.auth.sys, "stdout", new_callable=io.StringIO):
            users = self.auth.setup_users(self.config, interactive=True, input_fn=lambda prompt: "" if "User1" in prompt else clone_lab)
        self.assertEqual(users["user1"], clone_admin)
        self.assertEqual(users["user2"], clone_lab)
        self.assertNotIn(USER1, self.config.read_text())
        self.assertNotIn(USER2, self.config.read_text())
        for path in ("config/phase-07-users.json", "config/harness.env"):
            ignored = subprocess.run(["git", "check-ignore", path], cwd=ROOT, capture_output=True)
            tracked = subprocess.run(["git", "ls-files", "--", path], cwd=ROOT, capture_output=True)
            self.assertEqual(ignored.returncode, 0)
            self.assertEqual(tracked.stdout, b"")

    def test_active_account_never_defaults_to_service_account(self):
        with patch.object(self.auth.subprocess, "run", return_value=SimpleNamespace(returncode=0, stdout="robot@test.iam.gserviceaccount.com\n")):
            self.assertEqual(self.auth.active_user(), "")

    def test_explicit_setup_no_login_has_no_gcloud_calls(self):
        with patch.object(self.auth.sys.stdin, "isatty", return_value=False), patch.object(self.auth.subprocess, "run") as command, \
                patch.object(self.auth.sys, "stdout", new_callable=io.StringIO):
            self.main("--setup", "--user1", USER1, "--user2", USER2, "--no-login")
        command.assert_not_called()
        self.assertEqual(self.auth.load_users(self.config), self.users)

    def test_noninteractive_setup_requires_both_explicit_users(self):
        with self.assertRaisesRegex(ValueError, "--user1"):
            self.auth.setup_users(self.config, user1=USER1, interactive=False)
        self.assertFalse(self.config.exists())

    def test_invalid_input_does_not_replace_existing_config(self):
        self.existing()
        before = self.config.read_bytes()
        for other in (USER1.upper(), "wrong", "robot@test.iam.gserviceaccount.com"):
            with self.subTest(other=other), self.assertRaises(ValueError):
                self.auth.setup_users(self.config, user1=USER1, user2=other, interactive=False)
            self.assertEqual(self.config.read_bytes(), before)

    def test_cancelled_prompt_keeps_existing_config(self):
        self.existing()
        before = self.config.read_bytes()
        with patch("builtins.input", side_effect=["newadmin@example.com", EOFError]), self.assertRaises(EOFError):
            self.auth.setup_users(self.config, interactive=True)
        self.assertEqual(self.config.read_bytes(), before)

    def test_bad_json_shape_is_rejected_without_reset(self):
        for value in ([], None, "invalid", {"identity_mode": "two-users"}):
            self.config.write_text(json.dumps(value))
            before = self.config.read_bytes()
            with self.assertRaises(ValueError):
                self.auth.setup_users(self.config, user1=USER1, user2=USER2, interactive=False)
            self.assertEqual(self.config.read_bytes(), before)

    def test_atomic_write_failure_keeps_original_and_cleans_temp(self):
        self.existing()
        before = self.config.read_bytes()
        with patch.object(self.auth.os, "replace", side_effect=OSError("fixture")), self.assertRaises(OSError):
            self.auth.save_users(self.config, dict(self.users, user2="other@example.com"))
        self.assertEqual(self.config.read_bytes(), before)
        self.assertEqual(list(self.config.parent.glob("*.tmp")), [])

    @unittest.skipIf(os.name == "nt", "Windows symlink 권한은 별도 실기동 확인")
    def test_setup_refuses_symlink_destination(self):
        target = self.config.parent / "other.json"
        target.write_text(json.dumps(self.users))
        self.config.symlink_to(target)
        with self.assertRaisesRegex(ValueError, "심볼릭"):
            self.auth.save_users(self.config, dict(self.users, user2="other@example.com"))
        self.assertEqual(json.loads(target.read_text()), self.users)

    def test_save_drops_unknown_sensitive_fields(self):
        self.auth.save_users(self.config, dict(self.users, token="must-not-save"))
        self.assertEqual(json.loads(self.config.read_text()), self.users)

    def test_setup_reuses_authenticated_users_without_login(self):
        self.existing()
        with patch.object(self.auth, "check_auth_overrides"), patch.object(self.auth.sys.stdin, "isatty", return_value=False), \
                patch.object(self.auth.probe, "user_token", return_value="must-not-print"), \
                patch.object(self.auth.subprocess, "run") as command, patch.object(self.auth.sys, "stdout", new_callable=io.StringIO) as output:
            self.main("--setup", "--user1", USER1, "--user2", USER2)
        command.assert_not_called()
        self.assertNotIn("must-not-print", output.getvalue())
        self.assertNotIn(USER1, output.getvalue())

    def test_setup_logs_in_only_missing_user_and_rechecks_identity(self):
        with patch.object(self.auth, "check_auth_overrides"), patch.object(self.auth.sys.stdin, "isatty", return_value=False), \
                patch.object(self.auth.probe, "user_token", side_effect=["token1", self.auth.probe.ProbeError("login required"), "token2"]) as token, \
                patch.object(self.auth.subprocess, "run", return_value=SimpleNamespace(returncode=0)) as command, \
                patch.object(self.auth.sys, "stdout", new_callable=io.StringIO), patch.object(self.auth.sys, "stderr", new_callable=io.StringIO):
            self.main("--setup", "--user1", USER1, "--user2", USER2)
        command.assert_called_once_with(["gcloud", "auth", "login", USER2, "--no-activate"], check=False)
        self.assertEqual([call.args[0] for call in token.call_args_list], [USER1, USER2, USER2])

    def test_interactive_plan_ensure_creates_config_and_authenticates(self):
        with patch.object(self.auth, "check_auth_overrides"), patch.object(self.auth.sys.stdin, "isatty", return_value=True), \
                patch.object(self.auth, "active_user", return_value=USER1), patch("builtins.input", side_effect=["", USER2]), \
                patch.object(self.auth.probe, "user_token", side_effect=["token1", self.auth.probe.ProbeError("login required"), "token2"]), \
                patch.object(self.auth.subprocess, "run", return_value=SimpleNamespace(returncode=0)) as command, \
                patch.object(self.auth.sys, "stdout", new_callable=io.StringIO), patch.object(self.auth.sys, "stderr", new_callable=io.StringIO):
            self.main("--ensure")
        self.assertEqual(self.auth.load_users(self.config), self.users)
        command.assert_called_once_with(["gcloud", "auth", "login", USER2, "--no-activate"], check=False)

    def test_noninteractive_plan_missing_config_never_prompts_or_logs_in(self):
        with patch.object(self.auth.sys.stdin, "isatty", return_value=False), patch("builtins.input") as prompt, \
                patch.object(self.auth.subprocess, "run") as command, self.assertRaisesRegex(ValueError, "--setup"):
            self.main("--ensure")
        prompt.assert_not_called()
        command.assert_not_called()
        self.assertFalse(self.config.exists())

    def test_check_and_noninteractive_ensure_never_launch_browser(self):
        self.existing()
        for options in ([], ["--ensure"]):
            with self.subTest(options=options), patch.object(self.auth, "check_auth_overrides"), \
                    patch.object(self.auth.sys.stdin, "isatty", return_value=False), patch.object(self.auth.subprocess, "run") as command, \
                    patch.object(self.auth.probe, "user_token", side_effect=self.auth.probe.ProbeError("login required")), \
                    self.assertRaisesRegex(ValueError, "--setup"):
                self.main(*options)
            command.assert_not_called()

    def test_cancelled_login_keeps_saved_selection_for_retry(self):
        with patch.object(self.auth, "check_auth_overrides"), patch.object(self.auth.sys.stdin, "isatty", return_value=False), \
                patch.object(self.auth.probe, "user_token", side_effect=["token1", self.auth.probe.ProbeError("login required")]), \
                patch.object(self.auth.subprocess, "run", return_value=SimpleNamespace(returncode=1)), \
                patch.object(self.auth.sys, "stdout", new_callable=io.StringIO), patch.object(self.auth.sys, "stderr", new_callable=io.StringIO), \
                self.assertRaisesRegex(ValueError, "완료되지"):
            self.main("--setup", "--user1", USER1, "--user2", USER2)
        self.assertEqual(self.auth.load_users(self.config), self.users)

    def test_wrong_identity_after_browser_login_is_not_success(self):
        with patch.object(self.auth.probe, "user_token", side_effect=self.auth.probe.ProbeError("wrong identity")), \
                patch.object(self.auth.subprocess, "run", return_value=SimpleNamespace(returncode=0)), \
                patch.object(self.auth.sys, "stderr", new_callable=io.StringIO), self.assertRaisesRegex(ValueError, "identity"):
            self.auth.authenticated_user(USER2, "user2", allow_login=True)

    def test_override_blocks_browser_login(self):
        self.existing()
        with patch.dict(os.environ, {"CLOUDSDK_AUTH_ACCESS_TOKEN": "fixture-token"}), \
                patch.object(self.auth.subprocess, "run") as command, self.assertRaisesRegex(ValueError, "override"):
            self.main("--login", "user2")
        command.assert_not_called()

    def test_explicit_login_targets_selected_user_first(self):
        self.existing()
        with patch.object(self.auth, "check_auth_overrides"), patch.object(self.auth.probe, "user_token", return_value="token") as token, \
                patch.object(self.auth.subprocess, "run", return_value=SimpleNamespace(returncode=0)) as command, \
                patch.object(self.auth.sys, "stdout", new_callable=io.StringIO), patch.object(self.auth.sys, "stderr", new_callable=io.StringIO):
            self.main("--login", "user2")
        command.assert_called_once_with(["gcloud", "auth", "login", USER2, "--no-activate"], check=False)
        self.assertEqual(token.call_args_list[0].args[0], USER2)

    def test_cli_help_and_invalid_options_do_not_modify_config(self):
        for command in ([str(ROOT / "bin/gcp-lab-harness"), "--help"], [str(ROOT / "phases/07/auth.sh"), "--help"],
                        [str(ROOT / "bin/gcp-lab-harness"), "accounts", "setup", "--help"]):
            result = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("--user1", result.stdout)
        for extra in (["--setup", "--config", str(self.config)], ["--ensure", "--setup"], ["--check", "--setup"]):
            result = subprocess.run([str(ROOT / "phases/07/auth.sh"), *extra], capture_output=True, text=True)
            self.assertEqual(result.returncode, 2, result.stderr)
        self.assertFalse(self.config.exists())

    def test_account_setup_is_before_plan_and_never_overrides_saved_apply_identity(self):
        text = (ROOT / "phases/07/execute.sh").read_text()
        ensure = text.index('"$repo_root/phases/07/auth.sh" --ensure')
        self.assertIn('if [[ "$action" == plan ]]; then', text[:ensure])
        self.assertLess(ensure, text.index('p07_provider_identity "$identity_config"'))
        self.assertIn('[[ "$action" == plan ]] || identity_config="$repo_root/artifacts/runs/$selected_run/phase-07/work/phase-07.auto.tfvars.json"', text)
        self.assertIn('auth.py,auth.sh', (ROOT / "phases/07/support.sh").read_text())


if __name__ == "__main__":
    unittest.main(verbosity=2)
