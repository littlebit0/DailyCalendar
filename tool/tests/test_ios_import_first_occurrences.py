"""#923: the iOS Apple Calendar import keeps only each item's first occurrence per window."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / "ios/Runner/AppDelegate.swift").read_text()


class IosImportFirstOccurrencesTest(unittest.TestCase):
    def test_windows_are_reduced_before_the_next_is_read(self):
        chunks = SOURCE[SOURCE.index("private static func eventsInChunks"):SOURCE.index("// BEGIN FIRST OCCURRENCES")]
        self.assertIn("appendFirstOccurrences(", chunks)
        self.assertNotIn("collected +=", chunks)
        # The 1970-2100 range and three-year windows stay as they were (#109).
        self.assertIn("DateComponents(year: 1970, month: 1, day: 1)", chunks)
        self.assertIn("DateComponents(year: 2101, month: 1, day: 1)", chunks)
        self.assertIn("byAdding: .year, value: 3", chunks)

    @unittest.skipUnless(shutil.which("swiftc"), "Swift compiler required")
    def test_first_occurrences(self):
        block = SOURCE[SOURCE.index("// BEGIN FIRST OCCURRENCES"):SOURCE.index("// END FIRST OCCURRENCES")]
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            (tmp / "first.swift").write_text("import Foundation\nenum DailyAppleCalendarImport {\n" + block + "}\n")
            (tmp / "main_test.swift").write_text((ROOT / "tool/tests/ios_import_first_occurrences_test.swift").read_text())
            build = subprocess.run(
                ["swiftc", "-parse-as-library", "first.swift", "main_test.swift", "-o", "t"],
                cwd=tmp, capture_output=True, text=True,
            )
            self.assertEqual(build.returncode, 0, build.stderr)
            run = subprocess.run([str(tmp / "t")], capture_output=True, text=True)
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertIn("ios import first occurrence checks passed", run.stdout)


if __name__ == "__main__":
    unittest.main()
