#!/usr/bin/env python3
"""Phase 06 공개 예외는 Minecraft TCP 25565에만 허용한다."""

import argparse
import ipaddress
import json
import sys


def validate_cidr(value):
    ipaddress.IPv4Network(value, strict=False)


def validate_rule(rule, cidr, port):
    sources = rule.get("source_ranges", rule.get("sourceRanges"))
    tags = rule.get("target_tags", rule.get("targetTags"))
    allowed = rule.get("allow")
    if allowed is None:
        allowed = [
            {"protocol": item.get("IPProtocol"), "ports": item.get("ports")}
            for item in rule.get("allowed", [])
        ]
    if sources != [cidr] or tags != ["minecraft-server"]:
        raise ValueError("승인 source CIDR 또는 minecraft-server target tag 불일치")
    if allowed != [{"protocol": "tcp", "ports": [port]}]:
        raise ValueError(f"TCP {port} 단일 포트 외 허용 규칙 발견")
    if rule.get("direction") != "INGRESS" or rule.get("disabled", False):
        raise ValueError("활성 INGRESS 규칙이 아님")
    for field in (
        "deny", "denied", "source_tags", "sourceTags",
        "source_service_accounts", "sourceServiceAccounts",
        "target_service_accounts", "targetServiceAccounts",
    ):
        if rule.get(field):
            raise ValueError(f"허용하지 않은 추가 firewall selector: {field}")


def validate_pair(app, ssh, cidr):
    validate_cidr(cidr)
    validate_rule(app, cidr, "25565")
    validate_rule(ssh, "35.235.240.0/20", "22")
    if not app.get("network") or app["network"] != ssh.get("network"):
        raise ValueError("Minecraft와 IAP SSH의 network 불일치")


def validate_plan(plan, cidr):
    rules = {
        item["address"]: item["change"]["after"]
        for item in plan.get("resource_changes", [])
        if item.get("mode") == "managed" and item.get("type") == "google_compute_firewall"
    }
    if set(rules) != {"google_compute_firewall.minecraft", "google_compute_firewall.iap_ssh"}:
        raise ValueError("Phase 06 firewall는 Minecraft와 IAP SSH 두 규칙이어야 함")
    # 새 network의 ID는 create plan에서 unknown일 수 있다. 두 규칙의 연결은
    # Terraform test가 검사하며, live 검사에서는 실제 network를 반드시 비교한다.
    app = dict(rules["google_compute_firewall.minecraft"])
    ssh = dict(rules["google_compute_firewall.iap_ssh"])
    if app.get("network") is None and ssh.get("network") is None:
        app["network"] = ssh["network"] = "planned-network"
    validate_pair(app, ssh, cidr)


def validate_update(plan, cidr):
    validate_plan(plan, cidr)
    changes = [
        item for item in plan.get("resource_changes", [])
        if item["change"]["actions"] not in (["no-op"], ["read"])
    ]
    if (len(changes) != 1
            or changes[0]["address"] != "google_compute_firewall.minecraft"
            or changes[0]["change"]["actions"] != ["update"]):
        raise ValueError("기존 서버의 변경은 Minecraft firewall in-place update 1개만 허용")
    change = changes[0]["change"]
    before = {key: value for key, value in change["before"].items() if key != "source_ranges"}
    after = {key: value for key, value in change["after"].items() if key != "source_ranges"}
    if before != after or any(change.get("after_unknown", {}).values()):
        raise ValueError("source_ranges 외 변경 또는 unknown 값이 있어 재적용을 거부")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("cidr", "plan", "update", "live"))
    parser.add_argument("--cidr", required=True)
    parser.add_argument("files", nargs="*")
    args = parser.parse_intermixed_args()
    try:
        validate_cidr(args.cidr)
        count = {"cidr": 0, "plan": 1, "update": 1, "live": 2}[args.mode]
        if len(args.files) != count:
            raise ValueError(f"{args.mode} 입력 JSON은 {count}개 필요")
        objects = []
        for path in args.files:
            with open(path, encoding="utf-8") as stream:
                objects.append(json.load(stream))
        if args.mode == "plan":
            validate_plan(objects[0], args.cidr)
        elif args.mode == "update":
            validate_update(objects[0], args.cidr)
        elif args.mode == "live":
            validate_pair(objects[0], objects[1], args.cidr)
    except (OSError, ValueError, TypeError, KeyError) as error:
        print(f"FAIL: Phase 06 network policy: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
