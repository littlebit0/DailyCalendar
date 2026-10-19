import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SWIFT = (ROOT / "apple_widgets/DailyWidgets.swift").read_text()


class WidgetWeekdayColumnsTest(unittest.TestCase):
    def test_both_headers_use_the_shared_weekday_rule(self):
        # Month and week headers colour by actual weekday, not by column index.
        self.assertEqual(SWIFT.count("dailyWeekdayColor("), 3)  # definition + two headers
        self.assertEqual(SWIFT.count("dailyWeekdayLabels(weekStartsOnMonday:"), 3)  # definition + two headers
        self.assertNotIn("index == 0 ? Color.red", SWIFT)

    @unittest.skipUnless(subprocess.run(["which", "swiftc"], capture_output=True).returncode == 0, "swiftc missing")
    def test_weekday_of_each_column(self):
        block = SWIFT[SWIFT.index("// BEGIN WIDGET WEEKDAY COLUMNS") : SWIFT.index("// END WIDGET WEEKDAY COLUMNS")]
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            (tmp / "columns.swift").write_text(block)
            (tmp / "main_test.swift").write_text((ROOT / "tool/tests/widget_weekday_columns_test.swift").read_text())
            build = subprocess.run(
                ["swiftc", "-parse-as-library", "columns.swift", "main_test.swift", "-o", "wt"],
                cwd=tmp, capture_output=True, text=True,
            )
            self.assertEqual(build.returncode, 0, build.stderr)
            run = subprocess.run([str(tmp / "wt")], capture_output=True, text=True)
            self.assertEqual(run.returncode, 0, run.stderr)


if __name__ == "__main__":
    unittest.main()
