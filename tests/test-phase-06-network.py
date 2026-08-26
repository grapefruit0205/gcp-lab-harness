#!/usr/bin/env python3
"""Cloud 호출 없이 Phase 06 firewall policy의 허용·거부 경계를 시험한다."""

import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
POLICY_PATH = ROOT / "phases/06/network-policy.py"
spec = importlib.util.spec_from_file_location("phase06_network", POLICY_PATH)
policy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(policy)


def rule(cidr, port):
    return {
        "source_ranges": [cidr],
        "allow": [{"protocol": "tcp", "ports": [port]}],
        "target_tags": ["minecraft-server"],
        "network": "projects/test/global/networks/p06-test",
        "direction": "INGRESS",
        "disabled": False,
    }


class NetworkPolicyTest(unittest.TestCase):
    def setUp(self):
        self.app = rule("0.0.0.0/0", "25565")
        self.ssh = rule("35.235.240.0/20", "22")

    def plan(self):
        return {"resource_changes": [
            {"mode": "managed", "type": "google_compute_firewall",
             "address": f"google_compute_firewall.{name}",
             "change": {"after": value}}
            for name, value in (("minecraft", self.app), ("iap_ssh", self.ssh))
        ]}

    def test_public_and_restricted(self):
        for cidr in ("0.0.0.0/0", "192.0.2.10/32", "192.0.2.0/24"):
            with self.subTest(cidr=cidr):
                self.app["source_ranges"] = [cidr]
                policy.validate_pair(self.app, self.ssh, cidr)
                policy.validate_plan(self.plan(), cidr)

    def test_reject_invalid_cidr(self):
        for cidr in ("::/0", "not-cidr", "1.2.3.4/33", "0.0.0.0/0;true"):
            with self.subTest(cidr=cidr), self.assertRaises(ValueError):
                policy.validate_cidr(cidr)

    def test_reject_public_ssh(self):
        self.ssh["source_ranges"] = ["0.0.0.0/0"]
        with self.assertRaises(ValueError):
            policy.validate_plan(self.plan(), "0.0.0.0/0")

    def test_reject_scope_expansion(self):
        mutations = [
            ("allow", [{"protocol": "tcp", "ports": ["22", "25565"]}]),
            ("allow", [{"protocol": "udp", "ports": ["25565"]}]),
            ("allow", [{"protocol": "all", "ports": []}]),
            ("target_tags", []), ("disabled", True), ("direction", "EGRESS"),
            ("source_tags", ["other-client"]),
            ("source_ranges", ["0.0.0.0/0", "192.0.2.0/24"]),
            ("network", "other-network"),
        ]
        for field, value in mutations:
            with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                app = copy.deepcopy(self.app)
                app[field] = value
                policy.validate_pair(app, self.ssh, "0.0.0.0/0")

    def test_reject_extra_firewall(self):
        plan = self.plan()
        extra = copy.deepcopy(plan["resource_changes"][0])
        extra["address"] = "google_compute_firewall.unexpected"
        plan["resource_changes"].append(extra)
        with self.assertRaises(ValueError):
            policy.validate_plan(plan, "0.0.0.0/0")

    def test_reject_unapproved_source(self):
        with self.assertRaises(ValueError):
            policy.validate_pair(self.app, self.ssh, "192.0.2.10/32")

    def test_unknown_create_network(self):
        self.app.pop("network")
        self.ssh.pop("network")
        policy.validate_plan(self.plan(), "0.0.0.0/0")
        with self.assertRaises(ValueError):
            policy.validate_pair(self.app, self.ssh, "0.0.0.0/0")

    def test_gcloud_response_shape(self):
        def live(value):
            return {
                "sourceRanges": value["source_ranges"],
                "allowed": [{"IPProtocol": "tcp", "ports": value["allow"][0]["ports"]}],
                "targetTags": value["target_tags"],
                "network": value["network"], "direction": "INGRESS", "disabled": False,
            }
        policy.validate_pair(live(self.app), live(self.ssh), "0.0.0.0/0")

    def test_cli_with_plan_path_after_options(self):
        with tempfile.TemporaryDirectory() as directory:
            plan_path = Path(directory) / "plan.json"
            plan_path.write_text(json.dumps(self.plan()), encoding="utf-8")
            result = subprocess.run(
                ["python3", str(POLICY_PATH), "plan", "--cidr", "0.0.0.0/0", str(plan_path)],
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)

    def update_plan(self):
        plan = self.plan()
        for item in plan["resource_changes"]:
            item["change"]["before"] = copy.deepcopy(item["change"]["after"])
            item["change"]["actions"] = ["no-op"]
        app = plan["resource_changes"][0]["change"]
        app["actions"] = ["update"]
        app["before"]["source_ranges"] = ["192.0.2.10/32"]
        return plan

    def test_in_place_source_update_only(self):
        policy.validate_update(self.update_plan(), "0.0.0.0/0")

    def test_reject_replacement_or_other_update(self):
        plan = self.update_plan()
        plan["resource_changes"][0]["change"]["actions"] = ["delete", "create"]
        with self.assertRaises(ValueError):
            policy.validate_update(plan, "0.0.0.0/0")
        plan = self.update_plan()
        plan["resource_changes"][1]["change"]["actions"] = ["update"]
        with self.assertRaises(ValueError):
            policy.validate_update(plan, "0.0.0.0/0")

    def test_reject_other_field_change(self):
        plan = self.update_plan()
        plan["resource_changes"][0]["change"]["after"]["priority"] = 2000
        with self.assertRaises(ValueError):
            policy.validate_update(plan, "0.0.0.0/0")


if __name__ == "__main__":
    unittest.main()
