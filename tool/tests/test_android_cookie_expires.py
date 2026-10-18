"""The vendored Android cookie manager must use RFC 6265's 24-hour clock."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (
    ROOT
    / "third_party/flutter_inappwebview_android/android/src/main/java"
    / "com/pichillilorenzo/flutter_inappwebview_android/MyCookieManager.java"
).read_text()


class CookieExpiresPatternTest(unittest.TestCase):
    def test_formatter_and_parser_use_a_24_hour_clock(self):
        patterns = re.findall(r'new SimpleDateFormat\("([^"]*)"', SOURCE)
        cookie_patterns = [p for p in patterns if "dd MMM yyyy" in p]
        # One formatter (Expires out) and one parser (Expires in).
        self.assertEqual(len(cookie_patterns), 2, patterns)
        for pattern in cookie_patterns:
            self.assertIn("HH:mm:ss", pattern)
            self.assertNotIn("hh", pattern)


if __name__ == "__main__":
    unittest.main()
