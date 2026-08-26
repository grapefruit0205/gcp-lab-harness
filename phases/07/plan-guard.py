#!/usr/bin/env python3
"""Phase 07 저장 plan의 정확한 리소스·principal·네트워크 범위 검사."""

import argparse
import json
import re
import sys


def require(value, message):
    if not value:
        raise ValueError(message)


def guard(plan, project, run, region, user1, user2):
    require(re.fullmatch(r"[a-z0-9][a-z0-9-]{6,18}[a-z0-9]", run), "run ID")
    expected = {
        "google_project_service.resource_manager",
        "google_compute_network.iam", "google_compute_subnetwork.iam",
        "google_compute_firewall.iap_ssh", "google_storage_bucket.iam",
        "google_storage_bucket_object.sample", "google_project_iam_member.workload_viewer",
        "google_service_account.workload",
    }
    require(user1.lower() != user2.lower() and all("@" in user and not user.endswith(".gserviceaccount.com") for user in (user1, user2)), "실제 사용자 두 계정")
    changes = plan.get("resource_changes", [])
    require(len(changes) == 8 and {r["address"] for r in changes} == expected, "정확한 8개 리소스만 허용")
    resources = {}
    for item in changes:
        require(item["change"]["actions"] == ["create"], "신규 create만 허용")
        require(item["type"] == item["address"].split(".")[0], "resource type 불일치")
        value = item["change"]["after"]
        require(value.get("project", project) == project, "다른 project")
        resources[item["address"]] = value
    configuration = {r["address"]: r for r in plan.get("configuration", {}).get("root_module", {}).get("resources", [])}
    service = resources["google_project_service.resource_manager"]
    require(service["service"] == "cloudresourcemanager.googleapis.com" and
            service["disable_on_destroy"] is False and service["disable_dependent_services"] is False,
            "Resource Manager API만 활성화하고 cleanup에서 공용 API를 끄지 않음")

    def refers(address, expression, reference):
        refs = configuration.get(address, {}).get("expressions", {}).get(expression, {}).get("references", [])
        require(reference in refs, f"{address}.{expression} dependency 불일치")

    def linked(address, field, expected_value, reference):
        value = resources[address].get(field)
        if value is not None:
            require(value == expected_value, f"{address}.{field} 대상 불일치")
        else:
            refers(address, field, reference)

    network = resources["google_compute_network.iam"]
    require(network["name"] == "p07-net-" + run and network["auto_create_subnetworks"] is False, "전용 custom VPC")
    subnet = resources["google_compute_subnetwork.iam"]
    require(subnet["name"] == "p07-subnet-" + run and subnet["region"] == region and
            subnet["ip_cidr_range"] == "10.27.0.0/24" and subnet["private_ip_google_access"] is True, "PGA subnet")
    linked("google_compute_subnetwork.iam", "network", f"projects/{project}/global/networks/p07-net-{run}", "google_compute_network.iam.id")
    firewall = resources["google_compute_firewall.iap_ssh"]
    require(firewall["name"] == "p07-iap-ssh-" + run and firewall["direction"] == "INGRESS" and
            firewall["disabled"] is False and firewall["source_ranges"] == ["35.235.240.0/20"] and
            firewall["target_tags"] == ["p07-iam-probe"] and
            firewall["allow"] == [{"ports": ["22"], "protocol": "tcp"}] and
            not firewall.get("source_tags") and not firewall.get("source_service_accounts") and
            not firewall.get("target_service_accounts") and not firewall.get("deny"), "IAP-only TCP22")
    linked("google_compute_firewall.iap_ssh", "network", "p07-net-" + run, "google_compute_network.iam.name")
    sa = resources["google_service_account.workload"]
    require(sa["account_id"] == f"p07-w-{run}" and sa.get("disabled", False) is False, "VM workload SA 하나만 허용")
    bucket = resources["google_storage_bucket.iam"]
    require(bucket["name"] == "gcp-lab-p07-" + run and bucket["location"] == "US" and
            bucket["storage_class"] == "STANDARD" and
            bucket["public_access_prevention"] == "enforced" and bucket["uniform_bucket_level_access"] is True and
            bucket["force_destroy"] is True and bucket["labels"].get("run") == run and
            bucket["soft_delete_policy"][0]["retention_duration_seconds"] == 0, "private disposable bucket")
    sample = resources["google_storage_bucket_object.sample"]
    require(sample["name"] == "sample.txt" and sample["content"] == f"Phase 07 IAM fixture {run}\n", "고정 fixture")
    linked("google_storage_bucket_object.sample", "bucket", bucket["name"], "google_storage_bucket.iam.name")
    address = "google_project_iam_member.workload_viewer"
    binding = resources[address]
    require(binding["role"] == "roles/storage.objectViewer" and not binding.get("condition"), "workload viewer role")
    linked(address, "member", f"serviceAccount:p07-w-{run}@{project}.iam.gserviceaccount.com",
           'google_service_account.workload.email')


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("plan")
    for name in ("project", "run", "region", "user1", "user2"):
        parser.add_argument("--" + name, required=True)
    args = parser.parse_args()
    try:
        if args.plan == "-":
            value = json.load(sys.stdin)
        else:
            with open(args.plan, encoding="utf-8") as stream:
                value = json.load(stream)
        guard(value, args.project, args.run, args.region, args.user1, args.user2)
    except (ValueError, KeyError, TypeError, IndexError) as exc:
        parser.exit(1, "FAIL: Phase 07 plan guard: " + str(exc) + "\n")
    print("PASS: Phase 07 exact topology/IAM/network plan guard")
