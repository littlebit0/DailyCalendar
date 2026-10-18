"""The Windows runner must never hide its window without a way back."""
from pathlib import Path
import re
import unittest

SOURCE = (Path(__file__).resolve().parents[2] / "windows/runner/flutter_window.cpp").read_text()


class WindowsTrayRecoveryTest(unittest.TestCase):
    def test_taskbar_recreation_re_adds_the_icon(self):
        self.assertIn('RegisterWindowMessageW(L"TaskbarCreated")', SOURCE)
        handler = re.search(r"message == taskbar_created_message_\) \{(.*?)\n  \}", SOURCE, re.S)
        self.assertIsNotNone(handler)
        self.assertIn("tray_icon_added_ = false;", handler.group(1))
        self.assertIn("AddTrayIcon();", handler.group(1))

    def test_close_hides_only_when_the_tray_icon_exists(self):
        close = SOURCE[SOURCE.index("case WM_CLOSE:") : SOURCE.index("case WM_COMMAND:")]
        hide = close.index("SW_HIDE")
        self.assertLess(close.index("if (tray_icon_added_)"), hide)
        self.assertIn("SW_MINIMIZE", close)


if __name__ == "__main__":
    unittest.main()
