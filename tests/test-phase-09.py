#!/usr/bin/env python3
"""실제 Cloud/비밀 없이 Phase09 정책·비밀·실패 보존/동일 state 복구를 검사한다."""
import copy
import hashlib
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
from urllib.error import HTTPError

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'phases/09'))
import guest_install as installer
SPEC = importlib.util.spec_from_file_location("sql_lab", ROOT / "phases/09/sql_lab.py")
lab = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(lab)
import recovery
recovery.lab = lab
INPUTS = dict(project_id="example-lab", region="us-central1", zone="us-central1-a", run_id="p09-test-001",
              runner="learner@example.com", client_source_cidr="8.8.8.8/32")
for name, asset in lab.read_json(ROOT / "phases/09/assets.json").items():
    INPUTS[name + "_url"], INPUTS[name + "_sha256"] = asset["url"], asset["sha256"]


class UnitTests(unittest.TestCase):
    def test_inputs(self):
        lab.validate_inputs(INPUTS)
        lab.validate_inputs({**INPUTS, "runner": "different@example.com", "region": "asia-northeast3", "zone": "asia-northeast3-a"})

    def test_unsafe_inputs(self):
        for key, value in (("client_source_cidr", "0.0.0.0/0"), ("client_source_cidr", "127.0.0.1/32"),
                           ("client_source_cidr", "8.8.8.8/24"), ("client_source_cidr", "::1/128"),
                           ("run_id", "../bad"), ("zone", "europe-west1-b"),
                           ("runner", "sa@x.iam.gserviceaccount.com"), ("wordpress_url", "https://evil.invalid/a'")):
            with self.subTest(key=key, value=value), self.assertRaises((lab.LabError, ValueError)):
                lab.validate_inputs({**INPUTS, key: value})

    def test_names_do_not_truncate_run_suffix(self):
        first = lab.expected_names({**INPUTS, "run_id": "p09-260826-aaaa"})
        second = lab.expected_names({**INPUTS, "run_id": "p09-260826-aaab"})
        self.assertFalse(first["sa"] & second["sa"])

    def test_inventory_failure_is_not_absence(self):
        with patch.object(lab, "cloud", side_effect=lab.LabError("denied")), self.assertRaises(lab.LabError):
            lab.inventory(INPUTS)

    def test_inventory_exact_names(self):
        with patch.object(lab, "cloud", return_value=[{"name": "foreign"}, {"name": "wordpress-proxy-" + INPUTS["run_id"]}]):
            result = lab.inventory(INPUTS)
        self.assertEqual(len(result["vm"]), 1)
        self.assertEqual(result["network"], [])

    def test_missing_sql_api_is_not_queried_in_preflight_inventory(self):
        with patch.object(lab, "cloud", return_value=[]) as call:
            self.assertNotIn("sql", lab.inventory(INPUTS, sql_enabled=False))
        self.assertTrue(all("sql" not in args for args, _ in call.call_args_list))

    def test_resource_identity_needs_labels(self):
        row = {"name": "wordpress-proxy-" + INPUTS["run_id"], "id": "1", "labels": {}}
        with self.assertRaises(lab.LabError):
            lab.identities({"vm": [row]}, INPUTS)
        row["labels"] = {"harness": "gcp-lab-harness", "phase": "09", "run": INPUTS["run_id"]}
        self.assertTrue(lab.identities({"vm": [row]}, INPUTS))

    def test_destroyed_rejects_iam_tombstone(self):
        email = sorted(lab.expected_names(INPUTS)["sa"])[0]
        with tempfile.TemporaryDirectory() as directory, patch.object(lab, "inventory", return_value={"vm": []}), \
             patch.object(lab, "cloud", return_value={"bindings": [{"members": ["deleted:serviceAccount:" + email + "?uid=123"]}]}), \
             self.assertRaises(lab.LabError):
            lab.destroyed(INPUTS, Path(directory))

    def test_destroyed_rejects_remaining_network(self):
        with patch.object(lab, "inventory", return_value={"network": [{"name": "owned"}]}), self.assertRaises(lab.LabError):
            lab.destroyed(INPUTS, Path("/unused"))

    def test_state_foreign_targets_rejected(self):
        for row in ({"address": "other", "values": {}},
                    {"address": "google_compute_instance.proxy", "values": {"project": "example-lab", "name": "foreign"}},
                    {"address": "google_project_iam_member.proxy_client", "values": {"role": "roles/owner", "member": "foreign"}}):
            with self.subTest(row=row), self.assertRaises(lab.LabError):
                lab.guard_state({"values": {"root_module": {"resources": [row]}}}, INPUTS)

    def test_state_empty_allowed_for_final_cleanup(self):
        lab.guard_state({}, INPUTS)

    def test_api_raw_secret_not_printed(self):
        opener = Mock()
        opener.open.side_effect = HTTPError("https://sqladmin.googleapis.com/v1/x", 403, "secret-password", {}, io.BytesIO(b"secret-password"))
        with patch.dict(os.environ, {"GOOGLE_OAUTH_ACCESS_TOKEN": "test-token"}), patch.object(lab, "build_opener", return_value=opener):
            with self.assertRaises(lab.LabError) as caught:
                lab.api("PUT", "https://sqladmin.googleapis.com/v1/x", {"password": "secret-password"})
            self.assertNotIn("secret-password", str(caught.exception))
            self.assertIn("403", str(caught.exception))

    def test_api_error_classification_never_echoes_fields(self):
        cases = [('Cannot change password and roles together: secret-password', 'password-role-combination'),
                 ('User type must be specified: secret-password', 'user-type-required'),
                 ('Database role not found: secret-password', 'role-not-found'),
                 ('Cannot assign roles to system user secret-password', 'system-user-role-denied'),
                 ('secret-password', 'unknown')]
        for message, category in cases:
            error = {'error': {'status': 'INVALID_ARGUMENT', 'message': message,
                               'errors': [{'reason': 'invalid'}, {'reason': 'secret-password'}]}}
            opener = Mock()
            opener.open.side_effect = HTTPError('https://sqladmin.googleapis.com/v1/x', 400, 'secret-password', {},
                                               io.BytesIO(json.dumps(error).encode()))
            with self.subTest(category=category), patch.dict(os.environ, {'GOOGLE_OAUTH_ACCESS_TOKEN': 'test-token'}), \
                 patch.object(lab, 'build_opener', return_value=opener), self.assertRaises(lab.LabError) as caught:
                lab.api('PUT', 'https://sqladmin.googleapis.com/v1/x', {'password': 'secret-password'})
            self.assertNotIn('secret-password', str(caught.exception))
            self.assertIn('status=INVALID_ARGUMENT; reason=invalid; category=' + category, str(caught.exception))

    def test_api_error_malformed_or_oversized_stays_redacted(self):
        for body in (b'secret-password', b'x' * 65537, b'[]', b'{"error":"secret-password"}'):
            opener = Mock()
            opener.open.side_effect = HTTPError('https://sqladmin.googleapis.com/v1/x', 400, 'secret-password', {}, io.BytesIO(body))
            with self.subTest(size=len(body)), patch.dict(os.environ, {'GOOGLE_OAUTH_ACCESS_TOKEN': 'test-token'}), \
                 patch.object(lab, 'build_opener', return_value=opener), self.assertRaises(lab.LabError) as caught:
                lab.api('PUT', 'https://sqladmin.googleapis.com/v1/x', {'password': 'secret-password'})
            self.assertNotIn('secret-password', str(caught.exception))
            self.assertIn('category=unknown', str(caught.exception))

    def test_api_requires_https_and_owned_endpoint(self):
        for url in ("http://sqladmin.googleapis.com/v1/x", "https://evil.invalid/api"):
            with self.subTest(url=url), self.assertRaises(lab.LabError):
                lab.api("PUT", url, {"password": "secret"})

    def test_command_timeout_not_leaked(self):
        with patch.object(lab.subprocess, "run", side_effect=subprocess.TimeoutExpired(["secret-password"], 1)), self.assertRaises(lab.LabError) as caught:
            lab.run_command(["command"])
        self.assertNotIn("secret-password", str(caught.exception))

    def test_password_async_done_and_error(self):
        for operation, fails in (({"name": "op-1", "status": "DONE"}, False),
                                 ({"name": "op-1", "status": "DONE", "error": {"errors": ["secret"]}}, True)):
            replies = [{'items': [{'name': 'root', 'host': '%'}]},
                       {"name": "op-1", "status": "RUNNING"}, operation]
            if not fails:
                replies.extend([{'name': 'password-2', 'status': 'RUNNING'}, {'name': 'password-2', 'status': 'DONE'}])
            with patch.object(lab, "api", side_effect=replies) as call, patch.object(lab.time, "sleep"):
                if fails:
                    with self.assertRaises(lab.LabError):
                        lab.set_password(INPUTS, "secret")
                else:
                    lab.set_password(INPUTS, "secret")
                self.assertEqual(call.call_args_list[1].args[2], {'name': 'root', 'host': '%', 'type': 'BUILT_IN'})
                self.assertIn("host=%25", call.call_args_list[1].args[1])
                self.assertIn('databaseRoles=cloudsqlsuperuser', call.call_args_list[1].args[1])
                self.assertIn('revokeExistingRoles=false', call.call_args_list[1].args[1])
                self.assertNotIn('databaseRoles', call.call_args_list[1].args[2])
                self.assertEqual(call.call_count, 3 if fails else 5)
                if not fails:
                    self.assertEqual(call.call_args_list[3].args[2]['password'], 'secret')
                    self.assertNotIn('databaseRoles', call.call_args_list[3].args[1])
                    self.assertTrue(call.call_args_list[2].args[1].endswith('/operations/op-1'))

    def test_missing_root_created_with_explicit_database_role(self):
        with patch.object(lab, 'api', side_effect=[{'items': []}, {'name': 'op-1', 'status': 'DONE'}]) as call:
            self.assertEqual(lab.set_password(INPUTS, 'secret'), 'created')
        self.assertEqual(call.call_args_list[1].args[0], 'POST')
        self.assertEqual(call.call_args_list[1].args[2], {'name': 'root', 'host': '%', 'password': 'secret',
                                                        'type': 'BUILT_IN', 'databaseRoles': ['cloudsqlsuperuser']})
        self.assertTrue(all('secret' not in args[1] for args, _ in call.call_args_list))

    def test_existing_root_updated_without_overwrite_insert(self):
        with patch.object(lab, 'api', side_effect=[{'items': [{'name': 'root', 'host': '%', 'type': 'BUILT_IN'}]},
                                                   {'name': 'op-1', 'status': 'DONE'}, {'name': 'op-2', 'status': 'DONE'}]) as call:
            self.assertEqual(lab.set_password(INPUTS, 'secret'), 'updated')
        self.assertEqual([args[0] for args, _ in call.call_args_list], ['GET', 'PUT', 'PUT'])
        self.assertNotIn('password', call.call_args_list[1].args[2])
        self.assertNotIn('databaseRoles', call.call_args_list[2].args[1])

    def test_role_api_failure_never_rotates_password(self):
        with patch.object(lab, 'api', side_effect=[{'items': [{'name': 'root', 'host': '%'}]},
                                                   lab.LabError('API HTTP 400; 원문 생략')]) as call, \
             self.assertRaisesRegex(lab.LabError, 'root-role'):
            lab.set_password(INPUTS, 'secret')
        self.assertEqual(call.call_count, 2)
        self.assertNotIn('password', call.call_args.args[2])

    def test_password_failure_never_revokes_roles_or_deletes_user(self):
        with patch.object(lab, 'api', side_effect=[{'items': [{'name': 'root', 'host': '%'}]},
                                                   {'name': 'op-1', 'status': 'DONE'}, lab.LabError('API HTTP 400')]) as call, \
             self.assertRaisesRegex(lab.LabError, 'root-password'):
            lab.set_password(INPUTS, 'secret')
        self.assertEqual([args[0] for args, _ in call.call_args_list], ['GET', 'PUT', 'PUT'])
        self.assertIn('revokeExistingRoles=false', call.call_args_list[1].args[1])

    def test_password_operation_shares_role_deadline(self):
        with patch.object(lab, 'api', side_effect=[{'items': [{'name': 'root', 'host': '%'}]},
                                                   {'name': 'op-1', 'status': 'DONE'}, {'name': 'op-2', 'status': 'RUNNING'}]) as call, \
             patch.object(lab.time, 'monotonic', side_effect=[0, 1, 601]), \
             self.assertRaisesRegex(lab.LabError, 'root-password operation timeout'):
            lab.set_password(INPUTS, 'secret')
        self.assertEqual(call.call_count, 3)

    def test_expired_role_budget_never_starts_password_mutation(self):
        with patch.object(lab, 'api', side_effect=[{'items': [{'name': 'root', 'host': '%'}]},
                                                   {'name': 'op-1', 'status': 'DONE'}]) as call, \
             patch.object(lab.time, 'monotonic', side_effect=[0, 601]), self.assertRaises(lab.LabError):
            lab.set_password(INPUTS, 'secret')
        self.assertEqual(call.call_count, 2)

    def test_root_list_failure_never_mutates(self):
        with patch.object(lab, 'api', side_effect=lab.LabError('permission denied')) as call, self.assertRaises(lab.LabError):
            lab.set_password(INPUTS, 'secret')
        self.assertEqual(call.call_count, 1)
        self.assertEqual(call.call_args.args[0], 'GET')

    def test_unexpected_root_or_incomplete_listing_refused(self):
        for listing in ({'items': [{'name': 'root', 'host': '%', 'type': 'CLOUD_IAM_USER'}]},
                        {'items': [], 'nextPageToken': 'next'}, {'items': {}},
                        {'items': [{'name': 'root', 'host': '%'}] * 2}):
            with self.subTest(listing=listing), patch.object(lab, 'api', return_value=listing) as call, self.assertRaises(lab.LabError):
                lab.set_password(INPUTS, 'secret')
            self.assertEqual(call.call_count, 1)

    def test_other_user_not_modified(self):
        with patch.object(lab, 'api', side_effect=[{'items': [{'name': 'other', 'host': '%'}]},
                                                   {'name': 'op-1', 'status': 'DONE'}]) as call:
            lab.set_password(INPUTS, 'secret')
        self.assertEqual(call.call_args.args[2]['name'], 'root')
        self.assertEqual(call.call_args.args[0], 'POST')

    def test_guest_secret_in_stdin_only(self):
        with patch.object(lab, "run_command", return_value=b"") as call:
            lab.guest(INPUTS, "wordpress-proxy-" + INPUTS["run_id"], "sudo python3 -c safe", b"secret-password")
        self.assertEqual(call.call_args.kwargs["data"], b"secret-password")
        self.assertNotIn("secret-password", str(call.call_args.args))
        self.assertIn("--account=learner@example.com", call.call_args.args[0])

    def test_password_operation_timeout(self):
        with patch.object(lab, "api", side_effect=[{'items': [{'name': 'root', 'host': '%'}]},
                                                 {"name": "op-1", "status": "RUNNING"}]), \
             patch.object(lab.time, "monotonic", side_effect=[0, 601]), self.assertRaises(lab.LabError):
            lab.set_password(INPUTS, "secret")

    def test_guest_foreign_rejected(self):
        with self.assertRaises(lab.LabError):
            lab.guest(INPUTS, "foreign", "true")

    def test_wp_config_two_frontends(self):
        config = lab.wp_config("a" * 64, "10.29.0.2", "8.8.8.8")
        self.assertIn("define('DB_HOST','10.29.0.2')", config)
        self.assertIn("define('WP_HOME','http://8.8.8.8')", config)
        self.assertIn("define('WP_SITEURL','http://8.8.8.8')", config)
        self.assertIn("if (!defined('ABSPATH'))", config)
        self.assertIn("define('AUTH_KEY'", config)
        with self.assertRaises(lab.LabError):
            lab.wp_config("bad'input", "127.0.0.1", "8.8.8.8")

    def test_remote_installer_syntax_and_secret_prompt(self):
        compile(lab.INSTALL_CONFIG, "<guest>", "exec")
        self.assertIn("tempfile.mkstemp", lab.INSTALL_CONFIG)
        self.assertIn("os.chmod(temporary, 0o640)", lab.INSTALL_CONFIG)
        self.assertIn("--prompt=admin_password", lab.INSTALL_CONFIG)
        self.assertNotIn("--admin_password=", lab.INSTALL_CONFIG)

    def test_help_offline(self):
        for script in ("execute.sh", "verify.sh"):
            result = subprocess.run(["bash", str(ROOT / "phases/09" / script), "--help"], capture_output=True, timeout=10)
            self.assertEqual(result.returncode, 0)


class GuestInstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.payload = {'run_id': INPUTS['run_id'], 'config': '<?php // test-secret', 'url': 'http://8.8.8.8',
                        'admin_password': 'admin-secret', 'db_host': '127.0.0.1',
                        'db_password': 'db-secret', 'install': True}

    def install(self, child):
        with patch.object(installer, 'WEBROOT', self.root), patch.object(installer.os, 'geteuid', return_value=0), \
             patch.object(installer, 'CONFIG_MARKER', self.root / 'managed.json'), \
             patch.object(installer.os, 'chown'), patch('pwd.getpwnam', return_value=Mock(pw_gid=33)), \
             patch.object(installer.subprocess, 'run', side_effect=child):
            return installer.install(self.payload)

    def test_real_config_and_secret_only_in_stdin(self):
        calls = []
        def child(args, **kwargs):
            calls.append((args, kwargs))
            if 'is-installed' in args and len([a for a, kw in calls if 'is-installed' in a]) == 1:
                return subprocess.CompletedProcess(args, 1, '', '')
            return subprocess.CompletedProcess(args, 0, 'admin-secret', 'db-secret')
        self.assertEqual(self.install(child), {'stage': 'complete', 'reason': 'ok', 'exit_code': 0})
        self.assertEqual((self.root / 'wp-config.php').stat().st_mode & 0o777, 0o640)
        install_calls = [(args, kw) for args, kw in calls if '--prompt=admin_password' in args]
        self.assertEqual(install_calls[0][1]['input'], 'admin-secret\n')
        db_calls = [(args, kw) for args, kw in calls if installer.DB_CHECK in args]
        self.assertEqual(json.loads(db_calls[0][1]['input'])['db_password'], 'db-secret')
        self.assertTrue(all('secret' not in str(args) for args, kw in calls))

    def test_db_transient_retried_before_wp_install(self):
        checks = []
        def child(args, **kwargs):
            if installer.DB_CHECK in args:
                checks.append(args)
                return subprocess.CompletedProcess(args, 31 if len(checks) == 1 else 0, '', '')
            if '--prompt=admin_password' in args:
                self.assertEqual(len(checks), 2)
            return subprocess.CompletedProcess(args, 0, '', '')
        with patch.object(installer.time, 'sleep'):
            self.assertEqual(self.install(child)['stage'], 'complete')
        self.assertEqual(len(checks), 2)

    def test_db_deadline_records_only_error_class(self):
        def child(args, **kwargs):
            return subprocess.CompletedProcess(args, 32 if installer.DB_CHECK in args else 0, 'db-secret', '')
        with patch.object(installer.time, 'monotonic', side_effect=[0, 121]):
            result = self.install(child)
        self.assertEqual(result, {'stage': 'db-ready', 'reason': 'db-access-denied', 'exit_code': 32})
        self.assertNotIn('secret', json.dumps(result))

    def test_wp_failure_redacted_not_success(self):
        def child(args, **kwargs):
            if 'is-installed' in args:
                return subprocess.CompletedProcess(args, 1, '', '')
            return subprocess.CompletedProcess(args, 1 if '--prompt=admin_password' in args else 0,
                                               'admin-secret', 'Fatal error db-secret')
        self.assertEqual(self.install(child), {'stage': 'wp-install', 'reason': 'php-fatal', 'exit_code': 1})

    def test_child_timeout_never_leaks_exception(self):
        def child(args, **kwargs):
            raise subprocess.TimeoutExpired(['db-secret'], 30, output='admin-secret')
        self.assertEqual(self.install(child), {'stage': 'php', 'reason': 'timeout', 'exit_code': None})

    def test_config_is_never_overwritten(self):
        path = self.root / 'wp-config.php'
        path.write_text('existing')
        result = self.install(lambda args, **kw: subprocess.CompletedProcess(args, 0, '', ''))
        self.assertEqual(result['reason'], 'file-exists')
        self.assertEqual(path.read_text(), 'existing')

    def test_managed_config_retry_updates_only_owned_file(self):
        calls = []
        def child(args, **kw):
            calls.append(args)
            return subprocess.CompletedProcess(args, 0, '', '')
        self.assertEqual(self.install(child)['reason'], 'ok')
        self.payload['config'] = '<?php // rotated-secret'
        self.assertEqual(self.install(child)['reason'], 'ok')
        self.assertEqual((self.root / 'wp-config.php').read_text(), self.payload['config'])
        self.assertFalse(any('--prompt=admin_password' in args for args in calls))
        self.assertEqual((self.root / 'managed.json').stat().st_mode & 0o777, 0o600)
        self.assertNotIn('secret', (self.root / 'managed.json').read_text())

    def test_managed_config_foreign_run_or_drift_refused(self):
        child = lambda args, **kw: subprocess.CompletedProcess(args, 0, '', '')
        self.assertEqual(self.install(child)['reason'], 'ok')
        self.payload['run_id'] = 'p09-other-001'
        self.assertEqual(self.install(child)['reason'], 'config-drift')
        self.payload['run_id'] = INPUTS['run_id']
        (self.root / 'wp-config.php').write_text('user-edited')
        self.assertEqual(self.install(child)['reason'], 'config-drift')
        self.assertEqual((self.root / 'wp-config.php').read_text(), 'user-edited')

    def test_config_symlink_refused(self):
        target = self.root / 'user-file'
        target.write_text('keep')
        (self.root / 'wp-config.php').symlink_to(target)
        self.assertEqual(self.install(lambda args, **kw: subprocess.CompletedProcess(args, 0, '', ''))['reason'], 'config-drift')
        self.assertEqual(target.read_text(), 'keep')

    def test_db_errno_safe_number_only(self):
        for raw, expected in (('{"mysql_errno":2026}', 2026), ('{"mysql_errno":"db-secret"}', None),
                              ('{"mysql_errno":true}', None), ('{"mysql_errno":1045,"password":"secret"}', None)):
            def child(args, **kwargs):
                return subprocess.CompletedProcess(args, 31 if installer.DB_CHECK in args else 0, raw, 'db-secret')
            with patch.object(installer.time, 'monotonic', side_effect=[0, 121]):
                result = self.install(child)
            self.assertEqual(result.get('mysql_errno'), expected)
            self.assertEqual(result['reason'], 'db-connect')
            self.assertNotIn('secret', json.dumps(result))

    def test_db_privilege_denied_does_not_retry_as_network(self):
        def child(args, **kw):
            return subprocess.CompletedProcess(args, 35 if installer.DB_CHECK in args else 0,
                                               '{"mysql_errno":1044}', 'secret')
        with patch.object(installer.time, 'sleep') as sleep:
            self.assertEqual(self.install(child), {'stage': 'db-ready', 'reason': 'db-privilege-denied',
                                                  'exit_code': 35, 'mysql_errno': 1044})
        sleep.assert_not_called()

    def test_direct_only_checks_existing_install(self):
        self.payload['install'] = False
        calls = []
        def child(args, **kw):
            calls.append(args)
            return subprocess.CompletedProcess(args, 0, '', '')
        self.assertEqual(self.install(child)['reason'], 'ok')
        self.assertFalse(any('--prompt=admin_password' in args for args in calls))
        self.assertTrue(any('is-installed' in args for args in calls))

    def test_transport_payload_failure_is_machine_readable(self):
        result = subprocess.run([sys.executable, '-c', lab.INSTALL_CONFIG], input=b'bad-secret',
                                capture_output=True, timeout=5)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(json.loads(result.stdout), {'stage': 'input', 'reason': 'invalid-input', 'exit_code': None})
        self.assertEqual(result.stderr, b'')

    def test_host_failure_records_safe_diagnostic(self):
        result = {'stage': 'wp-install', 'reason': 'php-fatal', 'exit_code': 1}
        with patch.object(lab, 'guest', return_value=json.dumps(result).encode()), self.assertRaises(lab.LabError):
            lab.install_guest(INPUTS, self.root, 'wordpress-proxy-' + INPUTS['run_id'], self.payload)
        evidence = lab.read_json(self.root / 'evidence/guest-install-proxy.json')
        self.assertEqual(evidence['stage'], 'wp-install')
        self.assertNotIn('secret', json.dumps(evidence))

    def test_host_rejects_secret_in_untrusted_result(self):
        for raw in (b'bad-secret', b'{"stage":"db-secret","reason":"ok","exit_code":0}',
                    b'{"stage":"complete","reason":"ok","exit_code":true}',
                    b'{"stage":"complete","reason":"ok","exit_code":0,"extra":"db-secret"}'):
            with self.subTest(raw=raw), patch.object(lab, 'guest', return_value=raw), self.assertRaises(lab.LabError) as caught:
                lab.install_guest(INPUTS, self.root, 'wordpress-proxy-' + INPUTS['run_id'], self.payload)
            self.assertNotIn('secret', str(caught.exception))
            evidence = lab.read_json(self.root / 'evidence/guest-install-proxy.json')
            self.assertEqual(evidence['stage'], 'transport')
            self.assertNotIn('secret', json.dumps(evidence))


class VerifyFlowTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.run = Path(self.temp.name)
        lab.write_json(self.run / "resource-identities.json", {})
        lab.write_json(self.run / "database-initialized.json", {"root_password_initialized": True})
        self.proxy, self.direct = "wordpress-proxy-" + INPUTS["run_id"], "wordpress-private-" + INPUTS["run_id"]
        self.rows = {"sql": [{"state": "RUNNABLE", "databaseVersion": "MYSQL_8_0", "region": "us-central1",
                              "connectionName": "example-lab:us-central1:wordpress-db-" + INPUTS["run_id"],
                              "settings": {"tier": "db-custom-1-3840", "ipConfiguration": {}},
                              "ipAddresses": [{"type": "PRIMARY", "ipAddress": "9.9.9.9"},
                                              {"type": "PRIVATE", "ipAddress": "10.29.1.2"}]}], "vm": []}
        for vm, ip in ((self.proxy, "8.8.8.8"), (self.direct, "1.1.1.1")):
            self.rows["vm"].append({"name": vm, "status": "RUNNING", "zone": "/zones/us-central1-a",
                                    "networkInterfaces": [{"accessConfigs": [{"natIP": ip}]}]})
        self.calls = []
        self.fail_install = self.bad_http = self.bad_marker = False

    def guest(self, inputs, vm, command, data=None):
        self.calls.append((vm, command, data))
        if lab.INSTALL_CONFIG.splitlines()[1] in command:
            return json.dumps({'stage': 'complete', 'reason': 'ok', 'exit_code': 0}).encode()
        if "os.O_EXCL,0o644" in command and self.fail_install:
            raise lab.LabError("response lost")
        if "SELECT marker" in command:
            return ("phase09-" + INPUTS["run_id"] + "\n").encode()
        if command == "systemctl cat cloud-sql-proxy.service":
            return ("ExecStart=cloud-sql-proxy --address=127.0.0.1 --port=3306 " +
                    self.rows["sql"][0]["connectionName"]).encode()
        return b""

    def response(self, url, **kwargs):
        if "/harness-" in url:
            body = json.dumps({"marker": "wrong" if self.bad_marker else "phase09-" + INPUTS["run_id"],
                               "path": "harness-" + INPUTS["run_id"] + ".php"}).encode()
        else:
            body = b"<html>GCP Lab wp-content</html>"
        result = io.BytesIO(body)
        result.status = 302 if self.bad_http else 200
        return result

    def run_flow(self):
        opener = Mock()
        opener.open.side_effect = self.response
        with patch.object(lab, "owned", return_value=self.rows), patch.object(lab, "set_password"), \
             patch.object(lab, "wait_guest"), patch.object(lab, "guest", side_effect=self.guest), \
             patch.object(lab, "build_opener", return_value=opener), patch.object(lab.secrets, "token_hex", return_value="a" * 64):
            lab.verify(INPUTS, self.run)

    def test_full_flow(self):
        self.run_flow()
        evidence = lab.read_json(self.run / "evidence/phase-09-machine.json")
        self.assertEqual(len(evidence["tasks"]), 6)
        self.assertTrue(all(row["status"] == "passed" for row in evidence["tasks"].values()))
        self.assertFalse(evidence["lab_completion"]["complete"])
        configs = [(vm, json.loads(data)) for vm, command, data in self.calls if lab.INSTALL_CONFIG.splitlines()[1] in command]
        self.assertEqual(len(configs), 2)
        self.assertIn("define('DB_HOST','127.0.0.1')", configs[0][1]["config"])
        self.assertIn("define('DB_HOST','10.29.1.2')", configs[1][1]["config"])
        self.assertFalse(configs[1][1]["install"])
        self.assertTrue(all("a" * 64 not in command for _, command, _ in self.calls))
        self.assertTrue(all("db query" not in command for _, command, _ in self.calls))
        self.assertEqual(len([command for _, command, _ in self.calls if "wp eval " in command]), 2)
        self.assertEqual(len([command for _, command, _ in self.calls if 'p.unlink(missing_ok=True)' in command]), 2)

    def test_redirect_is_not_http_success(self):
        self.bad_http = True
        with self.assertRaises(lab.LabError):
            self.run_flow()
        self.assertFalse((self.run / "evidence/phase-09-machine.json").exists())
        self.assertTrue(any('p.unlink(missing_ok=True)' in command for _, command, _ in self.calls))

    def test_http_marker_must_match(self):
        self.bad_marker = True
        with self.assertRaises(lab.LabError):
            self.run_flow()
        self.assertFalse((self.run / "evidence/phase-09-machine.json").exists())

    def test_probe_response_lost_still_revoked(self):
        self.fail_install = True
        with self.assertRaises(lab.LabError):
            self.run_flow()
        self.assertTrue(any('p.unlink(missing_ok=True)' in command for _, command, _ in self.calls))

    def test_same_run_retry_archives_old_evidence(self):
        lab.write_json(self.run / 'verification-started.json', {'previous': True})
        self.run_flow()
        journals = list((self.run / 'verification-attempts').glob('*/verification-started.json'))
        self.assertEqual(len(journals), 1)
        self.assertTrue(lab.read_json(journals[0])['previous'])
        self.assertTrue(any('CREATE TABLE IF NOT EXISTS' in command for _, command, _ in self.calls))
        self.assertTrue(any('ON DUPLICATE KEY UPDATE' in command for _, command, _ in self.calls))

    def test_root_must_be_initialized_before_verify(self):
        (self.run / "database-initialized.json").unlink()
        with self.assertRaises(lab.LabError):
            self.run_flow()
        self.assertFalse(self.calls)


class RecoveryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.run = Path(self.temp.name)
        (self.run / 'work').mkdir()
        lab.write_json(self.run / 'work/phase-09.auto.tfvars.json', INPUTS)
        (self.run / 'work/terraform.tfstate').write_text('state-original')
        (self.run / 'phase-09.tfplan').write_text('plan-original')
        lab.write_json(self.run / 'phase-09-plan.json', {'resource_changes': []})
        lab.write_json(self.run / 'plan-bundle.json', {'terraform': {'sha256': recovery.sha(self.run / 'phase-09.tfplan')}})
        self.key = 'network:p09-net-' + INPUTS['run_id']
        self.rows = {'network': [{'name': 'p09-net-' + INPUTS['run_id'], 'id': '42'}]}
        self.saved = {'identities': {self.key: '42'}, 'created_keys': [], 'state_sha256': recovery.state_sha(self.run),
                      'plan_json_sha256': recovery.sha(self.run / 'phase-09-plan.json')}
        self.save_baseline()

    def save_baseline(self):
        lab.write_json(self.run / 'plan-baseline.json', self.saved)
        lab.write_json(self.run / 'action-plan.json', {'actions': [
            {'id': 'plan-baseline', 'target': recovery.sha(self.run / 'plan-baseline.json')}]})

    def check(self):
        with patch.object(lab, 'inventory', return_value=self.rows), patch.object(lab, 'cloud', return_value=[]), \
             patch.object(lab, 'guard_plan'):
            recovery.before_apply(self.run, INPUTS)

    def test_before_apply_accepts_exact_baseline(self):
        self.check()

    def test_changed_state_plan_or_cloud_rejected(self):
        for target in ('work/terraform.tfstate', 'phase-09.tfplan', 'phase-09-plan.json'):
            path = self.run / target
            old = path.read_bytes()
            path.write_bytes(old + b' ')
            with self.subTest(target=target), self.assertRaises(lab.LabError):
                self.check()
            path.write_bytes(old)
        self.rows['network'][0]['id'] = 'foreign-id'
        with self.assertRaises(lab.LabError):
            self.check()

    def test_cloud_query_error_not_empty_success(self):
        with patch.object(lab, 'guard_plan'), patch.object(lab, 'cloud', side_effect=lab.LabError('denied')), \
             self.assertRaises(lab.LabError):
            recovery.before_apply(self.run, INPUTS)

    def test_archive_retains_plan_not_duplicate_state(self):
        destination = recovery.archive(self.run, 'revisions', ['phase-09.tfplan', 'action-plan.json'])
        self.assertEqual((destination / 'phase-09.tfplan').read_text(), 'plan-original')
        self.assertEqual((self.run / 'work/terraform.tfstate').read_text(), 'state-original')
        self.assertFalse(list(destination.rglob('terraform.tfstate')))

    def test_verify_requires_current_apply_receipt(self):
        lab.write_json(self.run / 'apply-completed.json', {'bundle_sha256': recovery.sha(self.run / 'plan-bundle.json'),
                                                        'state_sha256': recovery.state_sha(self.run)})
        recovery.require_apply(self.run)
        (self.run / 'work/terraform.tfstate').write_text('changed')
        with self.assertRaises(lab.LabError):
            recovery.require_apply(self.run)

    def test_new_identity_requires_approved_create_and_state(self):
        lab.write_json(self.run / 'resource-identities.json', {self.key: 'old'})
        self.saved['identities'] = {}
        self.saved['created_keys'] = [self.key]
        self.save_baseline()
        lab.write_json(self.run / 'apply-started.json', {'bundle_sha256': recovery.sha(self.run / 'plan-bundle.json')})
        state = {'values': {'root_module': {'resources': [
            {'address': 'google_compute_network.sql', 'values': {'name': 'p09-net-' + INPUTS['run_id']}}]}}}
        with patch.object(lab, 'inventory', return_value=self.rows), patch.object(lab, 'run_command', return_value=json.dumps(state).encode()):
            lab.owned(INPUTS, self.run)
        with patch.object(lab, 'inventory', return_value=self.rows), patch.object(lab, 'run_command', return_value=b'{}'), \
             self.assertRaises(lab.LabError):
            lab.owned(INPUTS, self.run)
        self.saved['created_keys'] = []
        self.save_baseline()
        with patch.object(lab, 'inventory', return_value=self.rows), patch.object(lab, 'run_command', return_value=json.dumps(state).encode()), \
             self.assertRaises(lab.LabError):
            lab.owned(INPUTS, self.run)

    def test_new_plan_can_retain_partial_created_identity(self):
        lab.write_json(self.run / 'resource-identities.json', {self.key: 'old-deleted'})
        with patch.object(lab, 'inventory', return_value=self.rows):
            lab.owned(INPUTS, self.run)  # 새 계획 baseline에 들어간 partial apply의 생존 identity
        self.rows['network'][0]['id'] = 'foreign'
        with patch.object(lab, 'inventory', return_value=self.rows), self.assertRaises(lab.LabError):
            lab.owned(INPUTS, self.run)


class ShellTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        shutil.copytree(ROOT / "lib", self.root / "lib")
        shutil.copytree(ROOT / "phases/09", self.root / "phases/09", ignore=shutil.ignore_patterns(".terraform", "__pycache__"))
        self.run = self.root / "artifacts/runs" / INPUTS["run_id"] / "phase-09"
        self.work = self.run / "work"
        self.work.mkdir(parents=True)
        for name in ("main.tf", ".terraform.lock.hcl"):
            shutil.copy2(self.root / "phases/09/terraform" / name, self.work / name)
        self.tfvars = self.work / "phase-09.auto.tfvars.json"
        lab.write_json(self.tfvars, INPUTS)
        self.bin = self.root / "stub-bin"
        self.bin.mkdir()
        self.env = {**os.environ, "PATH": str(self.bin) + os.pathsep + os.environ["PATH"], "PYTHONDONTWRITEBYTECODE": "1"}
        for name in list(self.env):
            if name.startswith(("P09_", "GOOGLE_", "CLOUDSDK_", "TF_")):
                self.env.pop(name)
        self.script(self.bin / "gcloud", """#!/usr/bin/env bash
case "$1 $2" in
  "config get-value") [[ "$3" != account ]] || printf 'learner@example.com\\n'; exit 0 ;;
  "auth print-access-token") printf 'test-token\\n'; exit 0 ;;
esac
exit 1
""")
        python = shutil.which("python3")
        self.script(self.bin / "python3", f"""#!/usr/bin/env bash
if [[ "$1" == */sql_lab.py ]]; then
  case "$2" in
    identity|owned) exit 0 ;;
    verify) exit 17 ;;
    record) exit "${{STUB_RECORD_FAIL:-0}}" ;;
    destroyed) exit "${{STUB_DESTROYED_FAIL:-0}}" ;;
  esac
fi
if [[ "$1" == */recovery.py && "$2" == before-apply ]]; then exit 0; fi
exec "{python}" "$@"
""")
        self.script(self.bin / "terraform", f"""#!/usr/bin/env bash
case "$2" in
  show) printf '{{"values":{{"root_module":{{"resources":[]}}}}}}\\n'; exit 0 ;;
  destroy) printf 'destroy\\n' >>"{self.root}/operations.log"; exit "${{STUB_DESTROY_FAIL:-0}}" ;;
  apply) printf 'apply\\n' >>"{self.root}/operations.log"; exit "${{STUB_APPLY_FAIL:-1}}" ;;
  state) exit 0 ;;
esac
exit 1
""")
        (self.root / "scripts").mkdir()
        self.script(self.root / "scripts/preflight-gcp.sh", "#!/usr/bin/env bash\nexit 0\n")
        (self.root / "config").mkdir()
        (self.root / "config/harness.env").write_text("HARNESS_ENVIRONMENT=lab\nGCP_PROJECT_ID=example-lab\nGCP_ALLOWED_PROJECTS=example-lab\nGCP_REGION=us-central1\nGCP_CLEANUP_ON_FAILURE=true\nGCP_MAX_APPLY_MINUTES=1\n")
        code = self.shell("p09_source_sha").stdout.strip()
        lab.write_json(self.run / 'plan-baseline.json', {})
        (self.work / 'terraform.tfstate').write_text('preserved-state')
        lab.write_json(self.run / "action-plan.json", {"phase": "09", "run_id": INPUTS["run_id"], "actions": [
            {"id": "implementation", "target": code}, {"id": "saved-inputs", "target": hashlib.sha256(self.tfvars.read_bytes()).hexdigest()},
            {'id': 'plan-baseline', 'target': recovery.sha(self.run / 'plan-baseline.json')},
            {'id': 'failure-policy', 'target': 'preserve-diagnose-replan'}]})
        lab.write_json(self.run / "plan-bundle.json", {"action_plan": {"sha256": hashlib.sha256((self.run / "action-plan.json").read_bytes()).hexdigest()}})
        self.manifest = self.run / "manifest.json"
        lab.write_json(self.manifest, {"status": "applied", "cleanup": {"status": "not_started"},
                                     "plan": {"bundle_sha256": hashlib.sha256((self.run / "plan-bundle.json").read_bytes()).hexdigest()}})
        lab.write_json(self.run / 'apply-completed.json', {'bundle_sha256': recovery.sha(self.run / 'plan-bundle.json'),
                                                        'state_sha256': recovery.state_sha(self.run)})

    def script(self, path, text):
        path.write_text(text)
        path.chmod(0o700)

    def shell(self, command):
        prefix = f"""set -Eeuo pipefail
repo_root="{self.root}"
source "$repo_root/lib/harness/phase-adapter.sh"
source "$repo_root/phases/09/support.sh"
HARNESS_ENVIRONMENT=lab
GCP_PROJECT_ID=example-lab
GCP_ALLOWED_PROJECTS=example-lab
GCP_CLEANUP_ON_FAILURE=true
run_id={INPUTS["run_id"]}
"""
        return subprocess.run(["bash", "-c", prefix + command], env=self.env, text=True, capture_output=True, timeout=20)

    def test_context_hash(self):
        self.assertEqual(self.shell('p09_context "$run_id"; p09_approved_context').returncode, 0)
        lab.write_json(self.tfvars, {**INPUTS, "runner": "other@example.com"})
        self.assertNotEqual(self.shell('p09_context "$run_id"; p09_approved_context').returncode, 0)

    def test_source_hash(self):
        with (self.root / "phases/09/assets.json").open("a") as stream:
            stream.write("\n")
        self.assertNotEqual(self.shell('p09_context "$run_id"; p09_approved_context').returncode, 0)

    def test_installer_source_hash(self):
        with (self.root / 'phases/09/guest_install.py').open('a') as stream:
            stream.write('\n')
        self.assertNotEqual(self.shell('p09_context "$run_id"; p09_approved_context').returncode, 0)

    def test_environment_override(self):
        self.env["TF_CLI_ARGS_destroy"] = "-target=other"
        self.assertNotEqual(self.shell('p09_context "$run_id"; p09_identity').returncode, 0)

    def test_verify_failure_preserves(self):
        result = subprocess.run(["bash", str(self.root / "phases/09/verify.sh"), "--run", INPUTS["run_id"]],
                                env=self.env, capture_output=True, timeout=20)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(lab.read_json(self.manifest)["status"], "failed", result.stderr.decode())
        self.assertFalse((self.root / 'operations.log').exists())
        self.assertEqual((self.work / 'terraform.tfstate').read_text(), 'preserved-state')
        self.assertFalse(lab.read_json(self.run / 'recovery.json')['automatic_destroy'])
        self.assertTrue((self.run / 'verification.log').exists())
        self.assertFalse(list((self.root / "artifacts/locks").glob("*.lock.d")))

    def test_psa_pending_not_reported_destroyed(self):
        self.env["STUB_DESTROY_FAIL"] = "1"
        result = subprocess.run(["bash", str(self.root / "phases/09/verify.sh"), "--run", INPUTS["run_id"]],
                                env=self.env, capture_output=True, timeout=20)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(lab.read_json(self.manifest)["status"], "failed")
        self.assertFalse((self.root / 'operations.log').exists())

    def test_inventory_error_not_reported_destroyed(self):
        self.env["STUB_DESTROYED_FAIL"] = "1"
        result = subprocess.run(["bash", str(self.root / "phases/09/verify.sh"), "--run", INPUTS["run_id"]],
                                env=self.env, capture_output=True, timeout=20)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(lab.read_json(self.manifest)["status"], "failed")
        self.assertFalse((self.root / 'operations.log').exists())

    def test_apply_and_initialization_failure_never_destroy(self):
        for apply_code, record_code in ((1, 0), (0, 19), (124, 0), (130, 0), (143, 0)):
            with self.subTest(apply=apply_code, record=record_code):
                self.env['STUB_APPLY_FAIL'] = str(apply_code)
                self.env['STUB_RECORD_FAIL'] = str(record_code)
                value = lab.read_json(self.manifest)
                value['status'] = 'planned'
                lab.write_json(self.manifest, value)
                (self.run / 'phase-09.tfplan').write_text('saved-plan-preserved')
                result = subprocess.run(['bash', str(self.root / 'phases/09/execute.sh'), 'apply', '--run', INPUTS['run_id'],
                                         '--confirm-plan-sha', recovery.sha(self.run / 'plan-bundle.json')],
                                        env=self.env, capture_output=True, timeout=20)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(lab.read_json(self.manifest)['status'], 'failed', result.stderr.decode())
                self.assertNotIn('destroy', (self.root / 'operations.log').read_text())
                self.assertEqual((self.work / 'terraform.tfstate').read_text(), 'preserved-state')
                self.assertEqual((self.run / 'phase-09.tfplan').read_text(), 'saved-plan-preserved')
                self.assertTrue((self.run / 'apply.log').exists())

    def test_baseline_and_policy_hashes_required(self):
        lab.write_json(self.run / 'plan-baseline.json', {'tampered': True})
        self.assertNotEqual(self.shell('p09_context "$run_id"; p09_approved_context').returncode, 0)

    def test_replan_only_can_read_stale_source_contract(self):
        with (self.root / 'phases/09/recovery.py').open('a') as stream:
            stream.write('\n')
        self.assertEqual(self.shell('p09_context "$run_id"; p09_saved_context').returncode, 0)
        self.assertNotEqual(self.shell('p09_context "$run_id"; p09_approved_context').returncode, 0)


if __name__ == "__main__":
    if sys.argv[1:] == ["--terraform-plans"]:
        seen = set()
        for line in sys.stdin:
            event = json.loads(line)
            if event.get("type") != "test_plan" or event.get("@testrun") == "wide_ingress_rejected":
                continue
            inputs = dict(INPUTS)
            if event["@testrun"] == "different_clone":
                inputs.update(run_id="p09-other-002", region="asia-northeast3", zone="asia-northeast3-a", runner="another@example.com")
            lab.guard_plan(event["test_plan"], inputs)
            recovery_plan = copy.deepcopy(event['test_plan'])
            for row in recovery_plan['resource_changes']:
                if row.get('mode') != 'data':
                    row['change']['actions'] = ['no-op'] if row['address'] == 'google_compute_network.sql' else ['create']
            lab.guard_plan(recovery_plan, inputs)
            for actions in (['delete'], ['delete', 'create'], ['create', 'delete']):
                bad = copy.deepcopy(recovery_plan)
                next(r for r in bad['resource_changes'] if r.get('mode') != 'data')['change']['actions'] = actions
                try:
                    lab.guard_plan(bad, inputs)
                except lab.LabError:
                    pass
                else:
                    raise AssertionError('복구 계획의 삭제/교체를 허용함')
            seen.add(event["@testrun"])
        lab.require(len(seen) == 2, "provider JSON plan2 검사 필요")
        print("PASS: Terraform mock JSON plan2와 Python guard 호환")
    else:
        unittest.main()
