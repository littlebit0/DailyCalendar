"""The vendored iOS SDK must declare the file-date API it uses."""
from pathlib import Path
import plistlib
import unittest

ROOT = Path(__file__).resolve().parents[2]
PLUGIN = ROOT / "third_party/package_info_plus/ios"
MANIFEST = PLUGIN / "package_info_plus/Sources/package_info_plus/PrivacyInfo.xcprivacy"


class PackageInfoPrivacyManifestTest(unittest.TestCase):
    def test_file_timestamp_access_has_a_declared_reason(self):
        manifest = plistlib.loads(MANIFEST.read_bytes())
        declared = {
            entry["NSPrivacyAccessedAPIType"]: entry["NSPrivacyAccessedAPITypeReasons"]
            for entry in manifest["NSPrivacyAccessedAPITypes"]
        }
        self.assertEqual(
            declared.get("NSPrivacyAccessedAPICategoryFileTimestamp"), ["0A2A.1"]
        )
        # The SDK itself is not a tracker and collects nothing.
        self.assertIs(manifest["NSPrivacyTracking"], False)
        self.assertEqual(manifest["NSPrivacyCollectedDataTypes"], [])

    def test_both_integration_paths_ship_the_manifest(self):
        podspec = (PLUGIN / "package_info_plus.podspec").read_text()
        package = (PLUGIN / "package_info_plus/Package.swift").read_text()
        self.assertIn("PrivacyInfo.xcprivacy", podspec)
        self.assertIn("PrivacyInfo.xcprivacy", package)

    def test_the_reason_matches_what_the_plugin_reads(self):
        source = (
            PLUGIN / "package_info_plus/Sources/package_info_plus/FPPPackageInfoPlusPlugin.m"
        ).read_text()
        self.assertIn("attributesOfItemAtPath", source)


if __name__ == "__main__":
    unittest.main()
