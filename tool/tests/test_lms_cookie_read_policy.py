"""Exercise both production Apple cookie policies without WebViews or accounts."""

from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SOURCES = (
    ROOT / "macos/Runner/MainFlutterWindow.swift",
    ROOT / "ios/Runner/AppDelegate.swift",
)


class LmsCookieReadPolicyTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("swiftc"), "Swift compiler is required")
    def test_both_production_policies_with_foundation_cookies(self):
        for source_path in SOURCES:
            with self.subTest(platform=source_path.parts[-3]):
                source = source_path.read_text()
                policy = source.split("// BEGIN LMS COOKIE READ POLICY\n", 1)[1].split(
                    "// END LMS COOKIE READ POLICY", 1
                )[0]
                with tempfile.TemporaryDirectory(prefix="daily-lms-cookie-") as directory:
                    directory = Path(directory)
                    implementation = directory / "policy.swift"
                    implementation.write_text(
                        "import Foundation\nenum DailyLmsCookieReadPolicy {\n"
                        + policy + "}\n"
                    )
                    executable = directory / "policy-tests"
                    subprocess.run(
                        ["swiftc", "-parse-as-library", str(implementation),
                         str(ROOT / "tool/tests/lms_cookie_read_policy_test.swift"),
                         "-o", str(executable)],
                        check=True, capture_output=True, text=True,
                    )
                    result = subprocess.run(
                        [str(executable)], check=True, capture_output=True, text=True,
                    )
                    self.assertIn("LMS cookie read policy: 16 checks passed", result.stdout)

    def test_channel_keeps_private_store_and_strict_restore(self):
        for source_path in SOURCES:
            with self.subTest(platform=source_path.parts[-3]):
                source = source_path.read_text().split(
                    "private final class DailyLmsCookieStore {", 1
                )[1]
                read = source.split('case "read":', 1)[1].split('case "write":', 1)[0]
                self.assertIn("permitsSessionCookie(cookie, host: host)", read)
                self.assertIn("guard let store = stores[host], !store.isPersistent", source)
                self.assertIn("!view.configuration.websiteDataStore.isPersistent", source)
                self.assertIn(".domain: host, .path: \"/\"", source)
                self.assertIn('.secure: "TRUE", HTTPCookiePropertyKey("HttpOnly"): "TRUE"', source)


if __name__ == "__main__":
    unittest.main()
