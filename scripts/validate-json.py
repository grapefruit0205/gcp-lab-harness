#!/usr/bin/env python3
"""JSON 파일을 저장소의 JSON Schema로 검증한다."""

import json
import sys
from pathlib import Path

import jsonschema


if len(sys.argv) != 3:
    print(f"사용법: {sys.argv[0]} <schema.json> <document.json>", file=sys.stderr)
    raise SystemExit(2)

schema_path = Path(sys.argv[1])
document_path = Path(sys.argv[2])
with schema_path.open(encoding="utf-8") as source:
    schema = json.load(source)
with document_path.open(encoding="utf-8") as source:
    document = json.load(source)
jsonschema.validate(instance=document, schema=schema)
