#!/usr/bin/env python3
"""Cloud 미사용: 실제 오류 재현과 보존 경계 회귀 검사."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "lib/harness"))
import advanced


def load(name, relative):
    spec = importlib.util.spec_from_file_location(name, ROOT / relative)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


billing = load("billing", "phases/10/billing.py")
vpn = load("vpn", "phases/12/vpn.py")
monitoring = load("monitoring", "phases/11/monitoring.py")


class PlanTests(unittest.TestCase):
    def plan(self, actions=("create",)):
        return {"resource_changes": [{"address": "google_compute_network.main", "type": "google_compute_network",
                                     "change": {"actions": list(actions), "after": {"name": "p12-p12-test1234", "project": "lab-project"}}}]}

    def guard(self, plan, **kw):
        advanced.guard_plan(plan, ["google_compute_network"], "lab-project", "p12-test1234", 28, **kw)

    def test_create(self):
        self.guard(self.plan())

    def test_repair_update_and_noop(self):
        for actions in (("update",), ("no-op",)):
            self.guard(self.plan(actions), recovery=True)

    def test_no_update_without_repair(self):
        with self.assertRaises(ValueError): self.guard(self.plan(("update",)))

    def test_delete_replace_fail_closed(self):
        for actions in (("delete",), ("delete", "create"), ("create", "delete")):
            with self.subTest(actions=actions), self.assertRaises(ValueError):
                self.guard(self.plan(actions), recovery=True)

    def test_explicit_destroy_plan(self):
        self.guard(self.plan(("delete",)), destroy=True)
        with self.assertRaises(ValueError): self.guard(self.plan(), destroy=True)

    def test_empty_destroy_can_retry_inventory(self):
        self.guard({"resource_changes": []}, destroy=True)

    def test_wrong_project_name_type(self):
        for key, value in (("project", "other"), ("name", "unrelated")):
            data = self.plan(); data["resource_changes"][0]["change"]["after"][key] = value
            with self.assertRaises(ValueError): self.guard(data)
        data = self.plan(); data["resource_changes"][0]["type"] = "google_project"
        with self.assertRaises(ValueError): self.guard(data)

    def test_empty_and_limit(self):
        with self.assertRaises(ValueError): self.guard({"resource_changes": []})
        data = self.plan(); data["resource_changes"] *= 29
        with self.assertRaises(ValueError): self.guard(data)

    def test_data_not_managed_count(self):
        data = self.plan(); data["resource_changes"].append({"mode": "data", "type": "google_compute_image"})
        self.guard(data)


class APITests(unittest.TestCase):
    def test_pagination_collects_all(self):
        with patch.object(advanced.API, "request", side_effect=[{"members": [1], "nextPageToken": "a b"}, {"members": [2]}]) as req:
            self.assertEqual(advanced.API().pages("https://monitoring.googleapis.com/v3/groups/x/members", "members"), {"members": [1, 2]})
            self.assertIn("pageToken=a+b", req.call_args.args[1])

    def test_pagination_repeated_token_rejected(self):
        with patch.object(advanced.API, "request", return_value={"members": [], "nextPageToken": "x"}), self.assertRaises(ValueError):
            advanced.API().pages("https://monitoring.googleapis.com/x", "members")

    def test_403_not_absent(self):
        with patch.object(advanced.API, "request", side_effect=advanced.APIError(403)), self.assertRaises(advanced.APIError):
            advanced.inventory("10", "p10-test1234", "lab-project")

    def test_404_is_absent(self):
        with patch.object(advanced.API, "request", side_effect=advanced.APIError(404)):
            self.assertEqual(advanced.inventory("10", "p10-test1234", "lab-project"), [])

    def test_compute_error_not_absent(self):
        with patch.object(advanced.subprocess, "run", side_effect=subprocess.CalledProcessError(1, "gcloud")), self.assertRaises(subprocess.SubprocessError):
            advanced.inventory("15", "p15-test1234", "lab-project")

    def test_token_not_sent_to_other_host(self):
        with self.assertRaises(ValueError): advanced.API().request("GET", "https://example.org")


class MetricsTests(unittest.TestCase):
    def test_metadata_cpu_query_is_aligned_but_bool_uptime_is_not_averaged(self):
        from datetime import datetime, timezone
        from urllib.parse import urlsplit, parse_qs
        now = datetime(2026, 8, 26, tzinfo=timezone.utc)
        aligned = parse_qs(urlsplit(monitoring.time_series_url("https://monitoring.googleapis.com/v3/projects/p",
            'metadata.user_labels.run="r"', now, align_mean=True)).query)
        self.assertEqual(aligned["aggregation.alignmentPeriod"], ["60s"])
        self.assertEqual(aligned["aggregation.perSeriesAligner"], ["ALIGN_MEAN"])
        unaligned = parse_qs(urlsplit(monitoring.time_series_url("https://monitoring.googleapis.com/v3/projects/p",
            'metric.type="monitoring.googleapis.com/uptime_check/check_passed"', now)).query)
        self.assertNotIn("aggregation.perSeriesAligner", unaligned)

    def test_dashboard_v1_and_other_resources_v3(self):
        self.assertEqual(monitoring.resource_url("projects/p/dashboards/d"),
                         "https://monitoring.googleapis.com/v1/projects/p/dashboards/d")
        for resource in ("alertPolicies/a", "groups/g", "uptimeCheckConfigs/u"):
            self.assertEqual(monitoring.resource_url("projects/p/" + resource),
                             "https://monitoring.googleapis.com/v3/projects/p/" + resource)

    def config(self):
        metric = 'metric.type="compute.googleapis.com/instance/cpu/utilization" AND resource.type="gce_instance"'
        dashboard = {"mosaicLayout": {"tiles": [{"widget": {"xyChart": {"dataSets": [{"timeSeriesQuery": {"timeSeriesFilter": {
            "filter": metric + ' AND metadata.user_labels.run="p11-test-001"',
            "aggregation": {"alignmentPeriod": "60s", "perSeriesAligner": "ALIGN_MEAN"}}}}]}}}]}}
        policy = {"combiner": "AND", "conditions": [{"conditionThreshold": {"filter": metric + f' AND resource.labels.instance_id="{i}"',
            "thresholdValue": .2, "duration": "60s", "comparison": "COMPARISON_GT"}} for i in ("1", "2")]}
        group = {"filter": 'metadata.user_labels.run="p11-test-001"'}
        uptime = {"period": "60s", "resourceGroup": {"resourceType": "INSTANCE", "groupId": "projects/p/groups/g"}, "httpCheck": {"port": 80, "path": "/"}}
        return [dashboard, policy, group, uptime, {"group": "projects/p/groups/g"}, "p11-test-001", ["1", "2", "3"]]

    def test_monitoring_configuration_exact_targets(self):
        monitoring.check_configuration(*self.config())

    def test_group_rejects_invalid_resource_metadata_prefix(self):
        args = self.config()
        args[2]["filter"] = 'resource.metadata.user_labels.run="p11-test-001"'
        with self.assertRaises(ValueError): monitoring.check_configuration(*args)

    def test_duplicate_vm_condition_not_accepted(self):
        args = self.config(); args[1]["conditions"][1] = copy.deepcopy(args[1]["conditions"][0])
        with self.assertRaises(ValueError): monitoring.check_configuration(*args)

    def test_wrong_group_or_chart_not_accepted(self):
        for kind in ("group", "chart", "uptime"):
            args = self.config()
            if kind == "group": args[2]["filter"] = 'metadata.user_labels.run="other"'
            elif kind == "chart": args[0] = {}
            else: args[3]["resourceGroup"]["groupId"] = "wrong"
            with self.subTest(kind=kind), self.assertRaises(ValueError): monitoring.check_configuration(*args)

    def series(self, values=(True, True, True)):
        return {"timeSeries": [{"resource": {"labels": {"instance_id": str(i)}},
                                "points": [{"interval": {"endTime": "2026-08-26T12:00:00Z"}, "value": {"boolValue": value}}]}
                               for i, value in enumerate(values)]}

    def test_all_uptime_true(self):
        self.assertTrue(advanced.latest_uptime_ok(self.series(), ["0", "1", "2"]))

    def test_false_series_is_not_pass(self):
        self.assertFalse(advanced.latest_uptime_ok(self.series((True, False, True)), ["0", "1", "2"]))

    def test_missing_unknown_no_points(self):
        for expected in (["0", "1"], ["0", "1", "3"]):
            self.assertFalse(advanced.latest_uptime_ok(self.series(), expected))
        data = self.series(); data["timeSeries"][0]["points"] = []
        self.assertFalse(advanced.latest_uptime_ok(data, ["0", "1", "2"]))

    def test_latest_false_overrides_old_true(self):
        data = self.series(); data["timeSeries"][0]["points"].append({"interval": {"endTime": "2026-08-26T12:01:00Z"}, "value": {"boolValue": False}})
        self.assertFalse(advanced.latest_uptime_ok(data, ["0", "1", "2"]))

    def test_per_group_health(self):
        good = [{"backend": "/groups/a", "status": {"healthStatus": [{"healthState": "HEALTHY"}]}},
                {"backend": "/groups/b", "status": {"healthStatus": [{"healthState": "HEALTHY"}]}}]
        self.assertTrue(advanced.healthy_groups(good, ["a", "b"]))
        good[0]["status"]["healthStatus"] *= 2
        good[1]["status"]["healthStatus"][0]["healthState"] = "UNHEALTHY"
        self.assertFalse(advanced.healthy_groups(good, ["a", "b"]))

    def test_routes_require_expected_prefix(self):
        data = {"result": {"bgpPeerStatus": [{"status": "UP"}] * 2, "bestRoutes": [{"destRange": "10.1.1.0/24"}]}}
        self.assertTrue(vpn.peer_routes_ok(data, ["10.1.1.0/24"]))
        self.assertFalse(vpn.peer_routes_ok(data, ["10.2.1.0/24"]))


class BillingTests(unittest.TestCase):
    def result(self, rows=415602, values=(2, 1), field="cost"):
        return {"jobComplete": True, "totalRows": str(rows), "schema": {"fields": [{"name": field}]},
                "rows": [{"f": [{"v": str(v)}]} for v in values]}

    def test_total_rows_not_page_size(self):
        result = billing.check_result(2, self.result())
        self.assertEqual(result["total_rows"], 415602)
        self.assertEqual(result["sample_rows"], 2)

    def test_bad_rows_or_incomplete_fail(self):
        for data in (self.result(100), dict(self.result(), jobComplete=False), dict(self.result(), errors=[{}])):
            with self.assertRaises(ValueError): billing.check_result(2, data)

    def test_cost_predicate(self):
        billing.check_result(1, self.result())
        with self.assertRaises(ValueError): billing.check_result(1, self.result(values=(0,)))
        with self.assertRaises(ValueError): billing.check_result(4, self.result(values=(10,)))

    def test_aggregate_order(self):
        billing.check_result(5, self.result(field="billing_records"))
        with self.assertRaises(ValueError): billing.check_result(5, self.result(values=(1, 2), field="billing_records"))

    def test_schema_contract(self):
        data = {"numRows": "415602", "schema": {"fields": [{"name": k, "type": v} for k, v in billing.REQUIRED_SCHEMA.items()]}}
        billing.check_table(data)
        data["schema"]["fields"].pop()
        with self.assertRaises(ValueError): billing.check_table(data)

    def test_avro_integer_timestamp_is_rejected_with_field_detail(self):
        data = {"numRows": "415602", "schema": {"fields": [{"name": k, "type": v} for k, v in billing.REQUIRED_SCHEMA.items()]}}
        next(f for f in data["schema"]["fields"] if f["name"] == "usage_end_time")["type"] = "INTEGER"
        with self.assertRaisesRegex(ValueError, "usage_end_time: expected=TIMESTAMP, actual=INTEGER"):
            billing.check_table(data)

    def test_real_load_submission_enables_logical_types_before_query(self):
        # 실제 관측한 잘못된 스키마를 반환해 검사 실패까지의 실행 경로를 검증한다.
        metadata = {"generation": "123", "crc32c": "abc="}
        table = {"numRows": "415602", "schema": {"fields": [
            {"name": k, "type": "INTEGER" if k == "usage_end_time" else v}
            for k, v in billing.REQUIRED_SCHEMA.items()]}}
        with tempfile.TemporaryDirectory() as temp:
            run = Path(temp) / "p10-test-001" / "phase-10"
            run.mkdir(parents=True)
            (run / "evidence").mkdir()
            (run / "action-plan.json").write_text(json.dumps({"actions": [{
                "id": "fixture-load", "target": "gs://test-fixture/sample.avro#123 crc32c=abc="}]}))
            responses = [metadata, {}, {"status": {"state": "DONE"}}, metadata, table]
            with patch.object(advanced.API, "request", side_effect=responses) as request:
                with self.assertRaisesRegex(ValueError, "usage_end_time"):
                    billing.run(run, "lab-project")
            posts = [c for c in request.call_args_list if c.args[0] == "POST"]
            self.assertEqual(len(posts), 1, "schema 실패 후 쿼리를 실행하면 안 됨")
            config = posts[0].args[2]["configuration"]["load"]
            self.assertIs(config["useAvroLogicalTypes"], True)
            self.assertEqual(config["writeDisposition"], "WRITE_TRUNCATE")
            self.assertEqual(config["sourceUris"], ["gs://test-fixture/sample.avro"])
            self.assertEqual(config["destinationTable"], {"projectId": "lab-project",
                "datasetId": "billing_p10_test_001", "tableId": "sampleinfotable"})
            self.assertTrue((run / "action-plan.json").exists())
            receipt = json.loads(next((run / "evidence").glob("billing-jobs-*.json")).read_text())
            self.assertEqual(receipt["jobs"][0]["status"], "DONE")


class IntegrationTests(unittest.TestCase):
    def test_stopped_builder_uses_receipt_and_rejects_wrong_identity(self):
        source = (ROOT / "phases/13/execute.sh").read_text()
        function = 'phase_after_apply() {' + source.split('phase_after_apply() {', 1)[1].split('\nsource "$repo_root/', 1)[0]
        for foreign, recovered in ((False, False), (False, True), (True, False)):
            with self.subTest(foreign=foreign, recovered=recovered), tempfile.TemporaryDirectory() as temp:
                run = Path(temp) / "artifacts/runs/p13-test-001/phase-13"
                (run / "work").mkdir(parents=True)
                advanced.write_json(run / "work/builder-readiness.json", {"instance_id": "12345", "project": "lab-project",
                    "zone": "us-central1-a", "instance": "p13-builder-p13-test-001", "captured_before_stop": True,
                    "reset_autostart_verified": True, "first_boot": "a"*36, "second_boot": "b"*36, "apache_package_version": "2.4.test",
                    "recovered_after_image": recovered})
                builder = {"id": "foreign" if foreign else "12345", "labels": {"run": "p13-test-001"},
                    "status": "TERMINATED", "disks": [{"boot": True, "source": "https://www.googleapis.com/disk"}]}
                script = '''set -Eeuo pipefail
repo_root="$TEST_ROOT"; export GCP_PROJECT_ID=lab-project GCP_ZONE=us-central1-a
harness_die(){ printf '%s\\n' "$*" >&2; exit 1; }
harness_sha256_file(){ sha256sum "$1" | cut -d' ' -f1; }
terraform(){ if [[ "$4" == builder_instance_id ]]; then printf 12345; else printf base-image; fi; }
gcloud(){
  printf '%s\\n' "$1 $2 $3" >>"$TEST_ROOT/calls"
  case "$1 $2 $3" in
    'compute instances describe')
      if [[ "$*" == *value* ]]; then printf TERMINATED; else printf %s "$TEST_BUILDER_JSON"; fi ;;
    'compute images describe') printf '{"status":"READY","sourceDisk":"https://www.googleapis.com/disk"}' ;;
    *) printf 'unexpected Cloud call\\n' >&2; return 99 ;;
  esac
}
''' + function + '\nphase_after_apply p13-test-001\n'
                result = subprocess.run(["bash", "-c", script], capture_output=True, text=True,
                    env=dict(os.environ, TEST_ROOT=temp, TEST_BUILDER_JSON=json.dumps(builder)))
                self.assertEqual(result.returncode == 0, not foreign, result.stderr)
                calls = (Path(temp) / "calls").read_text()
                self.assertNotIn("get-serial-port-output", calls)
                self.assertNotIn("start", calls)
                if not foreign:
                    provenance = json.loads((run / "evidence/image-provenance.json").read_text())
                    self.assertEqual(provenance["readiness_recovered_after_image"], recovered)
                    self.assertTrue(provenance["reset_autostart_verified"])

    def test_builder_reset_requires_new_ready_boot_before_stop(self):
        with tempfile.TemporaryDirectory() as temp:
            script = '''set -Eeuo pipefail
gcloud(){
  printf '%s\\n' "$3" >>"$TEST_BUILDER/calls"
  case "$3" in
    reset) touch "$TEST_BUILDER/reset" ;;
    stop) [[ -f "$TEST_BUILDER/second-read" ]] && jq -e '.captured_before_stop==true' "$TEST_BUILDER/receipt.json" >/dev/null ;;
    describe) printf '1234567\\n' ;;
    get-serial-port-output)
      printf 'HARNESS_APACHE_VERSION=2.4.test\\n'
      if [[ -f "$TEST_BUILDER/second-read" ]]; then
        printf 'HARNESS_IMAGE_READY boot_id=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb\\n'
      else
        printf 'HARNESS_IMAGE_READY boot_id=aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa\\n'
        if [[ -f "$TEST_BUILDER/reset" ]]; then touch "$TEST_BUILDER/second-read"; fi
      fi ;;
    *) return 1 ;;
  esac
}
sleep(){ :; }
export -f gcloud sleep
bash "$1/phases/13/terraform/wait-builder.sh" lab-project us-central1-a p13-builder-test "$TEST_BUILDER/receipt.json"
'''
            result = subprocess.run(["bash", "-c", script, "bash", str(ROOT)],
                env=dict(os.environ, TEST_BUILDER=temp), capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((Path(temp) / "calls").read_text().splitlines(),
                ["get-serial-port-output", "reset", "get-serial-port-output", "get-serial-port-output", "get-serial-port-output", "describe", "stop"])
            receipt = json.loads((Path(temp) / "receipt.json").read_text())
            self.assertNotEqual(receipt["first_boot"], receipt["second_boot"])
            self.assertEqual(receipt["apache_package_version"], "2.4.test")
            self.assertEqual(receipt["instance_id"], "1234567")

    def test_loadgen_uses_custom_image_third_region(self):
        source = (ROOT / "phases/13/terraform/main.tf").read_text()
        loadgen = source.split('resource "google_compute_instance" "loadgen" {', 1)[1].split('\noutput ', 1)[0]
        self.assertIn("google_compute_image.webserver.self_link", loadgen)
        self.assertIn("var.load_zone", loadgen)
        self.assertIn("google_compute_router_nat.load", loadgen)
        self.assertNotIn("data.google_compute_image.debian", loadgen)

    def test_onprem_zone_is_same_region_different_active_zone(self):
        source = (ROOT / "phases/12/execute.sh").read_text().split('\nsource "$repo_root/lib/harness/safe-adapter.sh"', 1)[0]
        zones = [{"name": name, "region": "regions/" + region, "status": status} for name, region, status in (
            ("us-central1-a", "us-central1", "UP"), ("us-central1-b", "us-central1", "UP"),
            ("us-central1-c", "us-central1", "DOWN"), ("europe-west1-b", "europe-west1", "UP"))]
        for requested, success in (("", True), ("us-central1-b", True), ("us-central1-a", False),
                                    ("us-central1-c", False), ("europe-west1-b", False)):
            with self.subTest(requested=requested), tempfile.TemporaryDirectory() as temp:
                script = source + '''
gcloud(){ printf '%s' "$TEST_ZONES"; }
harness_die(){ printf '%s\\n' "$*" >&2; exit 1; }
phase_write_tfvars "$TEST_TFVARS" p12-test-001
'''
                target = Path(temp) / "vars.json"
                result = subprocess.run(["bash", "-c", script], capture_output=True, text=True,
                    env=dict(os.environ, TEST_ZONES=json.dumps(zones), TEST_TFVARS=str(target),
                        GCP_PROJECT_ID="lab-project", GCP_REGION="us-central1", GCP_ZONE="us-central1-a",
                        GCP_SECONDARY_REGION="europe-west1", GCP_SECONDARY_ZONE="europe-west1-b",
                        P12_ONPREM_ZONE=requested))
                self.assertEqual(result.returncode == 0, success, result.stderr)
                if success:
                    self.assertEqual(json.loads(target.read_text())["onprem_zone"], "us-central1-b")
                else:
                    self.assertFalse(target.exists(), "zone 오류 전에 PSK/tfvars를 생성하면 안 됨")

    def test_controller_accepts_only_declared_manual_boundary(self):
        source = (ROOT / "bin/gcp-lab-harness").read_text()
        function = "transition_artifact_guard() {" + source.split("transition_artifact_guard() {", 1)[1].split('\ncase "${1:-}" in', 1)[0]
        for status, classification, expected in (("manual-boundary", "manual-boundary", 0), ("manual-boundary", "automated", 1),
                                                  ("failed", "manual-boundary", 1), ("passed", "automated", 0)):
            with self.subTest(status=status, classification=classification), tempfile.TemporaryDirectory() as temp:
                run = Path(temp) / "phase-12"; (run / "evidence").mkdir(parents=True)
                advanced.write_json(run / "manifest.json", {"status": "verified", "checks": [{"status": "passed"}],
                    "source_tasks": [{"id": "task-8", "classification": classification}]})
                advanced.write_json(run / "evidence/phase-12-machine.json", {"tasks": {"task-8": {"status": status}}})
                script = 'set -Eeuo pipefail\nsource "$1/lib/harness/common.sh"\nharness_run_dir(){ printf %s "$2"; }\n'
                script = script.replace('printf %s "$2";', 'printf %s "$TEST_RUN";')
                script += function + '\ntransition_artifact_guard test-run 12 machine_verified\n'
                result = subprocess.run(["bash", "-c", script, "bash", str(ROOT), temp], env=dict(os.environ, TEST_RUN=temp), capture_output=True, text=True)
                self.assertEqual(0 if result.returncode == 0 else 1, expected, result.stderr)

    def test_replan_failure_preserves_previous_plan_and_unique_log(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            run = root / "artifacts/runs/p15-test-001/phase-15"
            (run / "work").mkdir(parents=True)
            (root / "config").mkdir()
            (root / "config/harness.env").write_text("test-config")
            (root / "phases/15/terraform").mkdir(parents=True)
            (root / "phases/15/terraform/main.tf").write_text("# repaired source")
            (run / "phase-15.tfplan").write_text("previous-plan")
            (run / "work/terraform.tfstate").write_text("preserved-state")
            advanced.write_json(run / "binding.json", {"account": advanced.hashlib.sha256(b"tester").hexdigest(),
                "config": advanced.digest(root / "config/harness.env")})
            advanced.write_json(run / "manifest.json", {"phase": "15", "run_id": "p15-test-001", "status": "failed",
                "project_id_hash": advanced.hashlib.sha256(b"lab-project").hexdigest()})
            script = '''set -Eeuo pipefail
export HARNESS_REPO_ROOT="$2" HARNESS_PHASE=15 HARNESS_PHASE_RESOURCE_LIMIT=4 HARNESS_PHASE_ALLOWED_TYPES_JSON='["google_compute_network"]'
source "$1/lib/harness/safe-adapter.sh"
phase_write_tfvars(){ :; }; phase_write_action_plan(){ printf '{}\\n' >"$1"; }
safe_identity(){ export GCP_PROJECT_ID=lab-project CLOUDSDK_CORE_ACCOUNT=tester; }
harness_tf_timeout(){ "$@"; }
terraform(){ printf '%s\\n' "$*" >>"$HARNESS_REPO_ROOT/calls"; [[ "$2" == init ]] && return 0; printf 'MOCK_PLAN_ERROR\\n'; return 17; }
safe_adapter_main replan --run p15-test-001
'''
            result = subprocess.run(["bash", "-c", script, "bash", str(ROOT), temp], capture_output=True, text=True)
            self.assertEqual(result.returncode, 17, result.stderr)
            self.assertNotIn("destroy", (root / "calls").read_text())
            self.assertEqual((run / "work/terraform.tfstate").read_text(), "preserved-state")
            archived = list(run.glob("plan-history.*/phase-15.tfplan"))
            self.assertEqual(len(archived), 1)
            self.assertEqual(archived[0].read_text(), "previous-plan")
            diagnosis = json.loads((run / "diagnosis.json").read_text())
            self.assertEqual(diagnosis["stage"], "replan")
            self.assertIn("MOCK_PLAN_ERROR", Path(diagnosis["private_log"]).read_text())

    def test_existing_run_config_drift_blocks_before_terraform(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp); run = root / "artifacts/runs/p15-test-001/phase-15"
            run.mkdir(parents=True); (root / "config").mkdir()
            (root / "config/harness.env").write_text("changed-config")
            advanced.write_json(run / "binding.json", {"account": advanced.hashlib.sha256(b"tester").hexdigest(), "config": "old"})
            advanced.write_json(run / "manifest.json", {"phase": "15", "run_id": "p15-test-001", "project_id_hash": advanced.hashlib.sha256(b"lab-project").hexdigest()})
            script = '''set -Eeuo pipefail
export HARNESS_REPO_ROOT="$2" HARNESS_PHASE=15 HARNESS_PHASE_RESOURCE_LIMIT=4 HARNESS_PHASE_ALLOWED_TYPES_JSON='["google_compute_network"]'
source "$1/lib/harness/safe-adapter.sh"
phase_write_tfvars(){ :; }; phase_write_action_plan(){ :; }
safe_identity(){ export GCP_PROJECT_ID=lab-project CLOUDSDK_CORE_ACCOUNT=tester; }
terraform(){ printf called >"$HARNESS_REPO_ROOT/calls"; }
safe_adapter_main diagnose --run p15-test-001
'''
            result = subprocess.run(["bash", "-c", script, "bash", str(ROOT), temp], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse((root / "calls").exists())
            self.assertIn("기존 run 설정이 변경", result.stderr)

    def test_real_adapter_apply_failure_and_stale_approval(self):
        for stale in (False, True):
            with self.subTest(stale=stale), tempfile.TemporaryDirectory() as temp:
                root = Path(temp); run = root / "artifacts/runs/p15-test-001/phase-15"
                (run / "work").mkdir(parents=True)
                (run / "work/terraform.tfstate").write_text("original-state")
                (run / "phase-15.tfplan").write_text("saved-plan")
                (run / "action-plan.json").write_text("{}")
                (root / "config").mkdir()
                (root / "config/harness.env").write_text("test-config")
                advanced.write_json(run / "binding.json", {"account": advanced.hashlib.sha256(b"tester").hexdigest(), "config": advanced.digest(root / "config/harness.env")})
                advanced.write_json(run / "manifest.json", {"phase": "15", "run_id": "p15-test-001", "status": "planned", "project_id_hash": advanced.hashlib.sha256(b"lab-project").hexdigest()})
                advanced.write_json(run / "plan-bundle.json", {"operation": "apply", "terraform": {"sha256": advanced.digest(run / "phase-15.tfplan")},
                    "action_plan": {"sha256": advanced.digest(run / "action-plan.json")}, "binding_sha256": advanced.digest(run / "binding.json")})
                sha = "0" * 64 if stale else advanced.digest(run / "plan-bundle.json")
                script = '''set -Eeuo pipefail
export HARNESS_REPO_ROOT="$2" HARNESS_PHASE=15 HARNESS_PHASE_RESOURCE_LIMIT=4 HARNESS_PHASE_ALLOWED_TYPES_JSON='["google_compute_network"]'
source "$1/lib/harness/safe-adapter.sh"
phase_write_tfvars(){ :; }; phase_write_action_plan(){ :; }
safe_identity(){ export GCP_PROJECT_ID=lab-project CLOUDSDK_CORE_ACCOUNT=tester GCP_CLEANUP_ON_FAILURE=true; }
advanced(){ [[ "$1" == check ]]; }
harness_tf_timeout(){ "$@"; }
terraform(){ printf '%s\\n' "$*" >>"$HARNESS_REPO_ROOT/calls"; return 42; }
safe_adapter_main apply --run p15-test-001 --confirm-plan-sha "$3"
'''
                result = subprocess.run(["bash", "-c", script, "bash", str(ROOT), temp, sha], capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)
                calls = (root / "calls").read_text() if (root / "calls").exists() else ""
                self.assertNotIn("destroy", calls)
                self.assertEqual((run / "work/terraform.tfstate").read_text(), "original-state")
                self.assertEqual((run / "phase-15.tfplan").read_text(), "saved-plan")
                if stale:
                    self.assertEqual(calls, "")
                else:
                    self.assertEqual(result.returncode, 42, result.stderr)
                    self.assertEqual(json.loads((run / "diagnosis.json").read_text())["exit_code"], 42)
                    self.assertEqual(json.loads((run / "manifest.json").read_text())["status"], "failed")

    def test_vpn_resumes_after_tunnel_deletion_without_baseline_wait(self):
        with tempfile.TemporaryDirectory() as temp:
            run = Path(temp) / "p12-test-001/phase-12"
            (run / "work").mkdir(parents=True); (run / "evidence").mkdir()
            advanced.write_json(run / "work/phase-12.auto.tfvars.json", {"project_id": "lab-project", "region": "us-central1", "zone": "us-central1-a"})
            (run / "binding.json").write_text("binding")
            advanced.write_json(run / "evidence/vpn-progress.json", {"stage": "fault-requested", "binding": advanced.digest(run / "binding.json"), "baseline_tunnels": 4})
            calls = []
            def cloud(*args):
                calls.append(args)
                if args[2] == "list": return []
                if args[2] == "describe": return {"status": "ESTABLISHED"}
                raise AssertionError(f"unexpected mutation/baseline {args}")
            def command(args, **kw):
                output = {key: {"value": "10.0.0.1"} for key in ("vpc_primary_ip", "vpc_secondary_ip", "onprem_ip")}
                return subprocess.CompletedProcess(args, 0, json.dumps(output) if args[0] == "terraform" else "PING_RC=0\n", "")
            with patch.object(vpn, "cloud", side_effect=cloud), patch.object(vpn.subprocess, "run", side_effect=command):
                vpn.run(run)
            self.assertTrue(all("tunnel0" not in str(c) or "list" in c for c in calls))
            self.assertEqual(json.loads((run / "evidence/vpn-progress.json").read_text())["stage"], "verified")
            self.assertEqual(json.loads((run / "evidence/phase-12-machine.json").read_text())["tasks"]["task-8"]["status"], "manual-boundary")

    def test_failure_preserves_state_plan_and_no_destroy(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp)
            (path / "manifest.json").write_text('{"status":"applied"}')
            (path / "terraform.tfstate").write_text("unchanged-state")
            (path / "plan.tfplan").write_text("unchanged-plan")
            script = 'source "$1/lib/harness/safe-adapter.sh"; terraform(){ echo forbidden >&2; return 99; }; safe_failure 7 verify "$2"'
            result = subprocess.run(["bash", "-c", script, "bash", str(ROOT), temp], capture_output=True, text=True)
            self.assertEqual(result.returncode, 7)
            self.assertNotIn("forbidden", result.stderr)
            self.assertEqual((path / "terraform.tfstate").read_text(), "unchanged-state")
            self.assertEqual((path / "plan.tfplan").read_text(), "unchanged-plan")
            self.assertTrue(json.loads((path / "diagnosis.json").read_text())["resources_preserved"])

    def test_guest_http_failure_propagates(self):
        result = subprocess.run(["bash", "-c", "set -eu; curl(){ return 22; }; for i in 1 2; do curl; printf '\\n'; done"], capture_output=True)
        self.assertEqual(result.returncode, 22)

    def test_managed_state_excludes_data(self):
        data = {"values": {"root_module": {"resources": [{"mode": "data", "address": "data.image", "values": {}},
                 {"mode": "managed", "address": "network", "values": {}}], "child_modules": [{"resources": [{"mode": "managed", "address": "module.vm", "values": {}}]}]}}}
        result = subprocess.run(["jq", "-r", '[.. | objects | select(.mode? == "managed" and has("address") and has("values")) | .address] | unique | .[]'], input=json.dumps(data), text=True, capture_output=True, check=True)
        self.assertEqual(result.stdout.splitlines(), ["module.vm", "network"])

    def test_every_phase_uses_safe_path_and_no_autodestroy(self):
        for phase in range(10, 16):
            with self.subTest(phase=phase):
                execute = (ROOT / f"phases/{phase}/execute.sh").read_text()
                verify = (ROOT / f"phases/{phase}/verify.sh").read_text()
                self.assertIn("safe_adapter_main", execute)
                self.assertIn("HARNESS_SAFE_VERIFY_RUN", verify)
                self.assertNotIn("harness_tf_destroy", verify)

    def test_nat_dependencies_and_uptime_enum(self):
        self.assertIn('resource_type = "INSTANCE"', (ROOT / "phases/11/terraform/main.tf").read_text())
        text = (ROOT / "phases/14/terraform/main.tf").read_text()
        self.assertGreaterEqual(text.count("[google_compute_router_nat.nat]"), 3)

    def test_source_binding_changes_with_source_not_docs(self):
        self.assertRegex(advanced.source_hash("10"), r"^[0-9a-f]{64}$")
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp); (path / "main.tf").write_text("first")
            before = advanced.work_hash(path)
            (path / "main.tf").write_text("second")
            self.assertNotEqual(before, advanced.work_hash(path))


if __name__ == "__main__":
    unittest.main()
