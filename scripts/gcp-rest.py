#!/usr/bin/env python3
"""ADC access token을 메모리에서만 사용해 Google API를 호출한다."""

from __future__ import annotations

import argparse
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path


parser = argparse.ArgumentParser()
parser.add_argument("method", choices=["GET", "POST", "PUT", "PATCH", "DELETE"])
parser.add_argument("url")
parser.add_argument("--body", type=Path)
parser.add_argument("--content-type", default="application/json")
args = parser.parse_args()

token = subprocess.run(
    ["gcloud", "auth", "application-default", "print-access-token"],
    check=True,
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.DEVNULL,
).stdout.strip()
body = args.body.read_bytes() if args.body else None
request = urllib.request.Request(args.url, data=body, method=args.method)
request.add_header("Authorization", f"Bearer {token}")
if body is not None:
    request.add_header("Content-Type", args.content_type)
try:
    with urllib.request.urlopen(request, timeout=60) as response:
        sys.stdout.buffer.write(response.read())
except urllib.error.HTTPError as error:
    sys.stderr.buffer.write(error.read())
    raise SystemExit(error.code)
