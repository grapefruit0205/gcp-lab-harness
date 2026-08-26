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


def detail_sections(text: str) -> dict[int, str]:
    sections = {}
    matches = list(re.finditer(r"^## Task (\d+)\. .+$", text, re.M))
    for index, match in enumerate(matches):
        number = int(match.group(1))
        if number in sections:
            raise ValueError(f"상세 안내 Task {number} 중복")
        end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        section = text[match.start():end].split("\n## 출처", 1)[0]
        sections[number] = section.strip()
    return sections


def validate_detail(original: str, detail: str, numbers: list[int]) -> int:
    sections = detail_sections(detail)
    if list(sections) != numbers:
        raise ValueError("상세 안내 Task 누락·순서·중복 오류")
    current = None
    expected = {n: [] for n in numbers}
    for line in original.splitlines():
        if match := re.match(r"^## 🧩 Task (\d+)\.", line):
            current = int(match.group(1))
        elif line.startswith("## "):
            current = None
        elif current and (match := re.match(r"^### (.+)$", line)):
            expected[current].append(match.group(1))
    count = 0
    for number, section in sections.items():
        headings = re.findall(r"^### (.+)$", section, re.M)
        if len(headings) != len(set(headings)):
            raise ValueError(f"Task {number} 상세 하위 제목 중복")
        if not headings or any(title not in headings for title in expected[number]):
            raise ValueError(f"Task {number} 원문 하위 제목 누락: {set(expected[number]) - set(headings)}")
        for part in re.split(r"^### .+$", section, flags=re.M)[1:]:
            if len(re.findall(r"^\d+\. \S", part, re.M)) < 2 or re.search(r"\b(?:TODO|TBD)\b|추후 작성", part):
                raise ValueError(f"Task {number} 세부 클릭/판정 절차 부족")
        count += len(expected[number])
    return count


def load_guide(phase: str) -> tuple[Path, str, int, int]:
    paths = sorted((REPO / "docs/phases").glob(f"phase-{phase}-*.md"))
    if len(paths) != 1:
        raise ValueError(f"Phase {phase} 문서는 정확히 하나여야 합니다")
    spec = importlib.util.spec_from_file_location("phase_contract", REPO / "scripts/phase-contract.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    contract = module.load_contract(REPO, paths[0])
    numbers = [task["number"] for task in contract["source_tasks"]]
    section = validate_section(paths[0].read_text(encoding="utf-8"), numbers)
    detail_path = REPO / f"docs/console/phase-{phase}.md"
    detail = detail_path.read_text(encoding="utf-8")
    source_headings = validate_detail((REPO / contract["source"]).read_text(encoding="utf-8"), detail, numbers)
    if f"../console/phase-{phase}.md" not in section:
        raise ValueError("Phase 요약에 상세 안내 링크가 없습니다")
    return paths[0], section + "\n\n---\n\n" + detail, len(numbers), source_headings


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--phase", choices=[f"{i:02}" for i in range(1, 16)])
    group.add_argument("--check-all", action="store_true")
    parser.add_argument("--task", type=int, help="--phase와 함께 해당 Task 상세만 출력")
    args = parser.parse_args()
    if args.task is not None and not args.phase:
        parser.error("--task는 --phase와 함께 사용합니다")
    try:
        if args.check_all:
            guides = [load_guide(f"{i:02}") for i in range(1, 16)]
            print(f"PASS: Phase 15개 · Task {sum(g[2] for g in guides)}개 · Task 안의 원문 하위 제목 {sum(g[3] for g in guides)}개 상세 안내 coverage (Cloud 미사용)")
        else:
            path, section, _, _ = load_guide(args.phase)
            if args.task is not None:
                sections = detail_sections(section)
                if args.task not in sections:
                    raise ValueError("해당 Task 번호가 없습니다")
                preamble = (REPO / f"docs/console/phase-{args.phase}.md").read_text(encoding="utf-8").split("\n## Task ", 1)[0]
                section = preamble + "\n\n" + sections[args.task]
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
