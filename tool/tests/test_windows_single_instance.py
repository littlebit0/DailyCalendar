"""A second launch of the Windows app must hand over to the running process.

C++ cannot be built on the machines that run this check, so it verifies the
wiring in the source; the Windows CI job compiles the code.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
MAIN = (ROOT / "windows/runner/main.cpp").read_text()
WINDOW = (ROOT / "windows/runner/flutter_window.cpp").read_text()
IDENTITY = (ROOT / "windows/runner/app_identity.h").read_text()


class WindowsSingleInstanceTest(unittest.TestCase):
    def test_second_launch_signals_the_first_and_exits_before_creating_a_window(self):
        guard = MAIN[MAIN.index("CreateMutexW") : MAIN.index("FlutterWindow window")]
        self.assertIn("kSingleInstanceMutexName", guard)
        branch = guard[guard.index("ERROR_ALREADY_EXISTS") :]
        self.assertLess(branch.index("AllowSetForegroundWindow"), branch.index("PostMessageW(HWND_BROADCAST"))
        self.assertIn("kShowWindowMessageName", branch)
        self.assertLess(branch.index("PostMessageW"), branch.index("return EXIT_SUCCESS;"))
        # The Dart engine (database, widget queue) starts only after the guard.
        self.assertLess(MAIN.index("CreateMutexW"), MAIN.index("flutter::DartProject project"))

    def test_first_instance_restores_its_window_on_the_signal(self):
        self.assertIn("RegisterWindowMessageW(daily::app_identity::kShowWindowMessageName)", WINDOW)
        handler = re.search(r"message == show_window_message_\) \{(.*?)\n  \}", WINDOW, re.S).group(1)
        self.assertIn("RestoreFromTray()", handler)
        self.assertIn("ChangeWindowMessageFilterEx(GetHandle(), show_window_message_", WINDOW)

    def test_release_and_test_editions_use_different_names(self):
        for constant in ("kSingleInstanceMutexName", "kShowWindowMessageName"):
            names = re.findall(constant + r"\[\] =\s*L\"([^\"]+)\"", IDENTITY)
            self.assertEqual(2, len(set(names)), constant)


if __name__ == "__main__":
    unittest.main()
