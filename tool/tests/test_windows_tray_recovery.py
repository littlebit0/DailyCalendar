"""The Windows runner must never hide its window without a way back.

C++ cannot be built on the machines that run this check, so it verifies the
recovery wiring in the source; the Windows CI job compiles the code.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / "windows/runner/flutter_window.cpp").read_text()
HEADER = (ROOT / "windows/runner/flutter_window.h").read_text()


def body(name):
    start = SOURCE.index(name)
    depth = 0
    for index in range(SOURCE.index("{", start), len(SOURCE)):
        depth += SOURCE[index] == "{"
        depth -= SOURCE[index] == "}"
        if depth == 0:
            return SOURCE[start : index + 1]
    raise AssertionError(name)


class WindowsTrayRecoveryTest(unittest.TestCase):
    def test_taskbar_recreation_ensures_the_icon_without_duplicating_it(self):
        self.assertIn('RegisterWindowMessageW(L"TaskbarCreated")', SOURCE)
        handler = re.search(r"message == taskbar_created_message_\) \{(.*?)\n  \}", SOURCE, re.S).group(1)
        self.assertIn("EnsureTrayIcon()", handler)
        # A TaskbarCreated sent for a DPI change leaves a live icon behind.
        self.assertNotIn("tray_icon_added_ = false;", handler)
        self.assertIn("BeginTrayRecovery()", handler)

    def test_ensure_confirms_then_adds_then_adopts_an_existing_icon(self):
        ensure = body("bool FlutterWindow::EnsureTrayIcon")
        confirm = ensure.index("NIM_MODIFY")
        add = ensure.index("NIM_ADD")
        adopt = ensure.index("NIM_MODIFY", add)
        self.assertLess(confirm, add)
        self.assertLess(add, adopt)

    def test_close_hides_only_when_the_tray_icon_is_confirmed(self):
        close = SOURCE[SOURCE.index("case WM_CLOSE:") : SOURCE.index("case WM_COMMAND:")]
        self.assertLess(close.index("EnsureTrayIcon()"), close.index("SW_HIDE"))
        self.assertIn("SW_MINIMIZE", close)

    def test_a_failed_restore_exposes_the_window_and_retries_a_bounded_number_of_times(self):
        recovery = body("void FlutterWindow::BeginTrayRecovery")
        self.assertIn("SW_SHOWMINNOACTIVE", recovery)
        self.assertIn("SetTimer(", recovery)
        timer = SOURCE[SOURCE.index("case WM_TIMER:") : SOURCE.index("case WM_CLOSE:")]
        self.assertIn("kTrayRetryMaxAttempts", timer)
        self.assertIn("KillTimer(", timer)
        self.assertIn("KillTimer(", body("void FlutterWindow::OnDestroy"))

    def test_the_registered_message_is_allowed_through_uipi(self):
        create = body("bool FlutterWindow::OnCreate")
        self.assertLess(
            create.index("RegisterWindowMessageW"),
            create.index("ChangeWindowMessageFilterEx(GetHandle(), taskbar_created_message_"),
        )
        self.assertIn("MSGFLT_ALLOW", create)

    def test_header_declares_what_the_source_uses(self):
        for name in ("EnsureTrayIcon", "BeginTrayRecovery", "FillTrayIconData", "tray_retry_attempts_"):
            self.assertIn(name, HEADER)


if __name__ == "__main__":
    unittest.main()
