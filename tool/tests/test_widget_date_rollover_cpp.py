"""Compiles and runs the pure C++ rollover helpers used by the Windows mini calendar."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class WidgetDateRolloverCppTest(unittest.TestCase):
    @unittest.skipUnless(shutil.which("clang++") or shutil.which("g++"), "a C++ compiler is required")
    def test_rollover_helpers(self):
        compiler = shutil.which("clang++") or shutil.which("g++")
        with tempfile.TemporaryDirectory() as directory:
            executable = Path(directory) / "rollover"
            build = subprocess.run(
                [compiler, "-std=c++17", "-Wall", "-Werror", "-UNDEBUG",
                 str(ROOT / "tool/tests/widget_date_rollover_test.cpp"), "-o", str(executable)],
                capture_output=True, text=True,
            )
            self.assertEqual(build.returncode, 0, build.stderr)
            run = subprocess.run([str(executable)], capture_output=True, text=True)
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertIn("checks passed", run.stdout)


if __name__ == "__main__":
    unittest.main()
