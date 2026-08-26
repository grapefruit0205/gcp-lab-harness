#!/usr/bin/env python3
"""Phase별 콘솔 확인 안내를 출력하고 원본 Task와의 누락을 검사한다. Cloud 미사용."""

from __future__ import annotations

import argparse
import importlib.util
from pathlib import Path
import re
import sys

REPO = Path(__file__).resolve().parent.parent
HEADING = "## Task별 콘솔 확인"
HEADER = "| Task | 콘솔 경로·대상 | 통과 기준 | 한계·보조 확인 |"


def extract_section(document: str) -> str:
    lines = document.splitlines()
    if lines.count(HEADING) != 1:
        raise ValueError("Task별 콘솔 확인 제목은 정확히 하나여야 합니다")
    start = lines.index(HEADING)
    end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith("## ")), len(lines))
    return "\n".join(lines[start:end]).strip()


def validate_section(document: str, expected_numbers: list[int]) -> str:
    section = extract_section(document)
    if HEADER not in section.splitlines():
        raise ValueError("콘솔 경로·통과 기준·보조 확인 표가 없습니다")
    numbers = []
    for line in section.splitlines():
        if not re.match(r"^\|\s*\d+\s*\|", line):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) != 4 or not all(cells):
            raise ValueError("각 Task에는 경로·대상, 통과 기준, 한계·보조 확인이 모두 필요합니다")
        if any(re.search(r"\b(?:TODO|TBD)\b|추후 작성", cell, re.I) for cell in cells):
            raise ValueError("미작성 Task 안내가 있습니다")
        numbers.append(int(cells[0]))
    if numbers != expected_numbers:
        raise ValueError(f"콘솔 확인 Task 누락·중복·순서 오류: 기대={expected_numbers}, 실제={numbers}")
    return section


def load_guide(phase: str) -> tuple[Path, str, int]:
    paths = sorted((REPO / "docs/phases").glob(f"phase-{phase}-*.md"))
    if len(paths) != 1:
        raise ValueError(f"Phase {phase} 문서는 정확히 하나여야 합니다")
    spec = importlib.util.spec_from_file_location("phase_contract", REPO / "scripts/phase-contract.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    contract = module.load_contract(REPO, paths[0])
    numbers = [task["number"] for task in contract["source_tasks"]]
    section = validate_section(paths[0].read_text(encoding="utf-8"), numbers)
    return paths[0], section, len(numbers)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--phase", choices=[f"{i:02}" for i in range(1, 16)])
    group.add_argument("--check-all", action="store_true")
    args = parser.parse_args()
    try:
        if args.check_all:
            counts = [load_guide(f"{i:02}")[2] for i in range(1, 16)]
            print(f"PASS: Phase 15개 · Task {sum(counts)}개 콘솔 확인 안내 coverage (Cloud 미사용)")
        else:
            path, section, _ = load_guide(args.phase)
            print(f"# Phase {args.phase} 콘솔 확인 안내\n")
            print("확인 방법이며 실제 성공 판정이 아닙니다. 자신의 프로젝트와 해당 run을 선택하세요.")
            print("삭제 전에는 아래 기준을 확인하고, 이미 destroy했다면 리소스 부재와 저장 증거로 구분합니다.")
            print(f"문서: {path}\n공통 확인법: {REPO / 'docs/console-checks.md'}\n")
            print(section)
    except (ValueError, OSError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1) from error


if __name__ == "__main__":
    main()
