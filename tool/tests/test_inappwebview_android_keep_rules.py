"""The vendored WebView plugin's R8 rules must keep names but allow shrinking.

Issue #402: an unmodified `-keep class ...** { *; }` blocked R8 from removing
or optimizing any code in the plugin package. Names stay kept because Dart
method-channel calls resolve enum constants by name and stack traces/logs rely
on them; unreachable code may be removed and the rest optimized.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
PLUGIN = ROOT / "third_party/flutter_inappwebview_android/android"
RULES = (PLUGIN / "proguard-rules.pro").read_text()
JAVA = PLUGIN / "src/main/java"
PACKAGE = "com.pichillilorenzo.flutter_inappwebview_android"


def _rules():
    text = re.sub(r"#.*", "", RULES)
    return [" ".join(rule.split()) for rule in re.split(r"(?=^-)", text, flags=re.M) if rule.strip()]


class InAppWebViewKeepRulesTest(unittest.TestCase):
    def test_package_rule_allows_shrinking_and_optimization_but_not_renaming(self):
        package_rules = [r for r in _rules() if f"class {PACKAGE}.**" in r]
        self.assertEqual(len(package_rules), 1, package_rules)
        head = package_rules[0].split(" class ")[0]
        modifiers = set(head.split(",")[1:])
        self.assertTrue(head.startswith("-keep,"), head)
        self.assertEqual(modifiers, {"allowshrinking", "allowoptimization"})

    def test_library_release_is_not_minified_on_its_own(self):
        # A library-level R8 pass has no app entry points; with a shrinkable
        # package rule it strips InAppWebViewFlutterPlugin to an empty class.
        gradle = (PLUGIN / "build.gradle").read_text()
        release = re.search(r"release\s*\{([^}]*)\}", gradle).group(1)
        self.assertRegex(release, r"minifyEnabled\s+false")
        self.assertIn("consumerProguardFiles 'proguard-rules.pro'", gradle)

    def test_javascript_bridge_methods_stay_kept(self):
        self.assertIn(
            "-keepclassmembers class * { @android.webkit.JavascriptInterface <methods>; }",
            _rules(),
        )

    def test_explicit_class_rules_point_at_existing_classes(self):
        for rule in _rules():
            for name in re.findall(rf"class ({re.escape(PACKAGE)}[\w.$*]*)", rule):
                if name.endswith(".**"):
                    continue
                source = JAVA / (name.split("$")[0].replace(".", "/") + ".java")
                self.assertTrue(source.exists(), f"{rule} -> {source}")


if __name__ == "__main__":
    unittest.main()
