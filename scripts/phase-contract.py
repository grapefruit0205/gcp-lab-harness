#!/usr/bin/env python3
"""원본 Lab Task와 Phase 매핑을 검증하고 기계 판독 계약을 출력한다."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


TASK_RE = re.compile(r"^## 🧩 Task (\d+)\.\s*(.+?)\s*$")
ROW_RE = re.compile(
    r"^\| Task (\d+)\.\s*(.+?)\s*\|\s*"
    r"(automated|cli-equivalent|manual-boundary|blocked|conditional|automated-required|automated/conditional)\s*\|\s*(.+?)\s*\|$"
)
REFERENCE_RE = re.compile(r"^- 원본: `([^`]+)`\s*$")


def die(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def normalize_title(value: str) -> str:
    value = re.sub(r"\([^)]*\)", "", value)
    return re.sub(r"[\s·_-]+", "", value).strip().lower()


def load_contract(repo: Path, phase_doc: Path) -> dict:
    doc_lines = phase_doc.read_text(encoding="utf-8").splitlines()
    reference = next((m.group(1) for line in doc_lines if (m := REFERENCE_RE.match(line))), None)
    if not reference:
        die(f"{phase_doc}에 원본 경로가 없습니다")
    reference_path = (repo / reference).resolve()
    try:
        reference_path.relative_to((repo / "references/google-cloud-labs-ko/labs").resolve())
    except ValueError:
        die(f"원본 경로가 보존 영역 밖입니다: {reference_path}")
    if not reference_path.is_file():
        die(f"원본 파일이 없습니다: {reference_path}")

    original = []
    for line in reference_path.read_text(encoding="utf-8").splitlines():
        if match := TASK_RE.match(line):
            original.append((int(match.group(1)), match.group(2).strip()))

    mapped = []
    for line in doc_lines:
        if match := ROW_RE.match(line):
            mapped.append(
                {
                    "number": int(match.group(1)),
                    "title": match.group(2).strip(),
                    "classification": match.group(3),
                    "evidence_contract": match.group(4).strip(),
                }
            )

    if not original or len(original) != len(mapped):
        die(
            f"{phase_doc.name} Task 수가 원본과 다릅니다: "
            f"original={len(original)}, mapped={len(mapped)}"
        )
    for index, ((source_number, source_title), target) in enumerate(zip(original, mapped), start=1):
        if source_number != index or target["number"] != index:
            die(f"{phase_doc.name} Task 번호가 연속적이지 않습니다: {index}")
        if normalize_title(source_title) != normalize_title(target["title"]):
            die(
                f"{phase_doc.name} Task {index} 제목 불일치: "
                f"원본={source_title!r}, 매핑={target['title']!r}"
            )

    phase_match = re.match(r"phase-(\d{2})-", phase_doc.name)
    if not phase_match:
        die(f"Phase 문서명이 올바르지 않습니다: {phase_doc.name}")
    phase = phase_match.group(1)
    return {
        "schema_version": 1,
        "phase": phase,
        "source": str(reference_path.relative_to(repo)),
        "source_tasks": [
            {
                "id": f"task-{item['number']}",
                "number": item["number"],
                "title": item["title"],
                "classification": item["classification"],
                "evidence_contract": item["evidence_contract"],
            }
            for item in mapped
        ],
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("phase_doc", type=Path)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    phase_doc = args.phase_doc.resolve()
    try:
        phase_doc.relative_to((repo / "docs/phases").resolve())
    except ValueError:
        die("Phase 문서는 docs/phases 아래에 있어야 합니다")
    contract = load_contract(repo, phase_doc)
    if args.check:
        print(
            f"PASS: Phase {contract['phase']} 원본 Task "
            f"{len(contract['source_tasks'])}개 coverage 계약 일치"
        )
    else:
        json.dump(contract, sys.stdout, ensure_ascii=False, indent=2)
        sys.stdout.write("\n")


if __name__ == "__main__":
    main()
