#!/usr/bin/env python3
"""콘솔 안내의 완전성·실패 경계·출력 계약 검사. 로그인/Cloud 변경 없음."""

import importlib.util
from pathlib import Path
import subprocess
import sys
import unittest

REPO = Path(__file__).resolve().parent.parent
SPEC = importlib.util.spec_from_file_location("console_checks", REPO / "scripts/console-checks.py")
GUIDE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GUIDE)


class ConsoleChecksTests(unittest.TestCase):
    def document(self, rows):
        return f"{GUIDE.HEADING}\n\n{GUIDE.HEADER}\n|---|---|---|---|\n{rows}\n\n## 다음 항목\n본문"

    def test_all_phases_match_original_tasks(self):
        total_headings = 0
        for phase in range(1, 16):
            with self.subTest(phase=phase):
                _, section, count, source_headings = GUIDE.load_guide(f"{phase:02}")
                self.assertGreater(count, 0)
                self.assertIn("../console-checks.md", section)
                total_headings += source_headings
        self.assertEqual(total_headings, 167)

    def test_missing_duplicate_and_reordered_tasks_rejected(self):
        for numbers in ([1], [1, 1], [2, 1], [1, 2, 3]):
            with self.subTest(numbers=numbers), self.assertRaises(ValueError):
                GUIDE.validate_section(self.document("\n".join(f"| {n} | 경로 | 통과 | 보조 |" for n in numbers)), [1, 2])

    def test_empty_and_placeholder_cells_rejected(self):
        for row in ("| 1 | 경로 | | 보조 |", "| 1 | 경로 | TBD | 보조 |", "| 1 | 경로 | 통과 | 추후 작성 |"):
            with self.subTest(row=row), self.assertRaises(ValueError):
                GUIDE.validate_section(self.document(row), [1])

    def test_heading_is_required_and_unique(self):
        for doc in ("## 없음", self.document("| 1 | 경로 | 통과 | 보조 |") + "\n" + GUIDE.HEADING):
            with self.subTest(doc=doc), self.assertRaises(ValueError):
                GUIDE.validate_section(doc, [1])

    def test_next_section_is_not_rendered(self):
        section = GUIDE.validate_section(self.document("| 1 | 경로 | 통과 | 보조 |"), [1])
        self.assertNotIn("다음 항목", section)

    def test_cli_is_read_only_and_warns_about_destroy(self):
        result = subprocess.run([sys.executable, str(REPO / "scripts/console-checks.py"), "--phase", "09"], capture_output=True, text=True, check=True)
        self.assertIn("실제 성공 판정이 아닙니다", result.stdout)
        self.assertIn("destroy", result.stdout)
        self.assertIn("cloud-sql-proxy", result.stdout)

    def test_invalid_phase_rejected(self):
        for phase in ("00", "16", "../09", "9"):
            result = subprocess.run([sys.executable, str(REPO / "scripts/console-checks.py"), "--phase", phase], capture_output=True)
            self.assertEqual(result.returncode, 2)

    def test_detail_missing_heading_rejected(self):
        original = "## 🧩 Task 1. 시험\n### 필수 하위항목\n"
        for detail in ("## Task 1. 시험\n### 다른 항목\n\n1. 경로\n2. 값", "## Task 1. 시험\n### 필수 하위항목\n\n1. 경로"):
            with self.assertRaises(ValueError): GUIDE.validate_detail(original, detail, [1])

    def test_detail_unheaded_task_still_needs_steps(self):
        with self.assertRaises(ValueError): GUIDE.validate_detail("## 🧩 Task 1. 시험", "## Task 1. 시험\n요약", [1])

    def test_detail_duplicate_heading_rejected(self):
        detail = "## Task 1. 시험\n" + "### 중복\n\n1. 경로\n2. 값\n" * 2
        with self.assertRaises(ValueError): GUIDE.validate_detail("## 🧩 Task 1. 시험", detail, [1])

    def test_single_task_command(self):
        result = subprocess.run([sys.executable, str(REPO / "scripts/console-checks.py"), "--phase", "10", "--task", "4"], capture_output=True, text=True, check=True)
        self.assertIn("query8", result.stdout)
        self.assertIn("artifacts/runs/<RUN_ID>/phase-10/evidence/", result.stdout)
        self.assertIn("Project history", result.stdout)
        self.assertNotIn("## Task 5", result.stdout)

    def test_invalid_task_rejected(self):
        for flags in (["--phase", "10", "--task", "99"], ["--check-all", "--task", "1"]):
            result = subprocess.run([sys.executable, str(REPO / "scripts/console-checks.py"), *flags], capture_output=True)
            self.assertNotEqual(result.returncode, 0)

    def test_completion_surfaces_require_guide(self):
        for path in ("AGENTS.md", "prompts/phase-review.md", "prompts/phase-execute.md", "prompts/single-model-phase.md",
                     "scripts/prepare-extension-review.sh", "scripts/prepare-single-model-review.sh", "scripts/single-model-phase.sh"):
            with self.subTest(path=path):
                self.assertIn("console-checks.py", (REPO / path).read_text())
        self.assertIn("--check-all", (REPO / "scripts/validate-design.sh").read_text())


if __name__ == "__main__":
    unittest.main()
