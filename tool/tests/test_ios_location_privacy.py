"""Check source purpose strings; exported IPA validation remains a separate step."""

import json
from pathlib import Path
import plistlib
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
KEYS = (
    "NSLocationWhenInUseUsageDescription",
    "NSLocationAlwaysAndWhenInUseUsageDescription",
)


class IOSLocationPrivacyTests(unittest.TestCase):
    def test_location_api_purpose_strings_are_present(self):
        info = plistlib.loads((ROOT / "ios/Runner/Info.plist").read_bytes())
        for key in KEYS:
            with self.subTest(key=key):
                self.assertIsInstance(info.get(key), str)
                self.assertTrue(info[key].strip())
        self.assertIn("KMA forecast", info[KEYS[1]])
        self.assertIn("does not track your location in the background", info[KEYS[1]])

    def test_background_location_is_not_enabled(self):
        info = plistlib.loads((ROOT / "ios/Runner/Info.plist").read_bytes())
        self.assertNotIn("location", info.get("UIBackgroundModes", []))

    @unittest.skipUnless(sys.platform == "darwin", "Apple plutil parses localized strings")
    def test_all_supported_languages_have_location_purpose_strings(self):
        for locale in ("ko", "en", "ja", "zh-Hant"):
            path = ROOT / "ios/Runner" / f"{locale}.lproj/InfoPlist.strings"
            result = subprocess.run(
                ["plutil", "-convert", "json", "-o", "-", str(path)],
                check=True, capture_output=True, text=True,
            )
            strings = json.loads(result.stdout)
            for key in KEYS:
                with self.subTest(locale=locale, key=key):
                    self.assertIsInstance(strings.get(key), str)
                    self.assertTrue(strings[key].strip())


if __name__ == "__main__":
    unittest.main()
