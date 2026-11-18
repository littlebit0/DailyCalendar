import importlib.util
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("checker", ROOT / "tool/check_android_version_code.py")
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)


class AndroidVersionCodeTests(unittest.TestCase):
    def test_matches_every_released_code(self):
        for version, code in {"2.7.3": 273, "3.0.1": 301, "3.5.2": 352, "4.1.1": 411, "4.2.0": 420}.items():
            self.assertEqual(checker.expected_version_code(version), code)
        self.assertEqual(checker.expected_version_code("4.1.1+7"), 411)

    def test_rejects_versions_that_would_share_a_code(self):
        # 4.1.10 and 4.2.0 would both be 420.
        for version in ("4.1.10", "4.10.0", "0.9.9", "4.1", "v4.1.1"):
            with self.assertRaises(ValueError):
                checker.expected_version_code(version)

    def test_mismatch_fails_and_repository_matches(self):
        gradle = "    defaultConfig {\n        versionCode = 411\n    }\n"
        self.assertEqual(checker.check("name: daily\nversion: 4.1.1\n", gradle), 411)
        with self.assertRaisesRegex(ValueError, "expected 412"):
            checker.check("version: 4.1.2\n", gradle)
        with self.assertRaises(ValueError):
            checker.check("version: 4.1.1\n", "versionCode = flutter.versionCode\n")
        checker.check((ROOT / "pubspec.yaml").read_text(),
                      (ROOT / "android/app/build.gradle.kts").read_text())


if __name__ == "__main__":
    unittest.main()
