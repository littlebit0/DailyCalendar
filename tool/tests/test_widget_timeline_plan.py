"""#919: the Apple widget timeline already holds the next midnight and today's event boundaries."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SWIFT = (ROOT / "apple_widgets/DailyWidgets.swift").read_text()


def between(start, end):
    return SWIFT[SWIFT.index(start) : SWIFT.index(end)]


def production_source():
    """The production snapshot model, loader and timeline plan, reading from a test directory."""
    container = "FileManager.default.containerURL(\n            forSecurityApplicationGroupIdentifier: appGroup\n          )"
    loader = between("struct DailyWidgetSnapshot: Codable {", "struct DailyWidgetEntry: TimelineEntry {")
    assert loader.count(container) == 2
    lookup = '(Bundle.main.object(forInfoDictionaryKey: "DailySharedStoreNamespace") as? String)'
    store = between("// BEGIN DAILY SHARED STORE NAMESPACE", "// END DAILY SHARED STORE NAMESPACE")
    assert lookup in store
    return "\n".join([
        "import Foundation",
        "let testDirectory = URL(fileURLWithPath: CommandLine.arguments[1])",
        'let snapshotFileName = "snapshot.json"',
        store.replace(lookup, "Optional<String>.none"),
        between("struct DailyWidgetEvent: Codable, Identifiable {", "private enum DailyWidgetTodoActionStore {"),
        between("struct DailyWidgetDay: Codable, Identifiable {", "private struct DailyWidgetEventSpan"),
        between("struct DailyWidgetDday: Codable, Identifiable {", "// BEGIN WIDGET WEEKDAY COLUMNS"),
        loader.replace(container, "Optional(testDirectory)"),
        between("// BEGIN WIDGET TIMELINE PLAN", "// END WIDGET TIMELINE PLAN"),
    ])


class WidgetTimelinePlanTest(unittest.TestCase):
    def test_provider_uses_the_plan(self):
        provider = between("struct DailyWidgetProvider: TimelineProvider {", "// BEGIN WIDGET TIMELINE PLAN")
        self.assertIn("dailyWidgetTimelinePlan(now: .now)", provider)
        self.assertIn("policy: .after(plan.reload)", provider)

    @unittest.skipUnless(shutil.which("swiftc"), "Swift compiler required")
    def test_timeline_entries(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            (tmp / "model.swift").write_text(production_source())
            (tmp / "main_test.swift").write_text(
                (ROOT / "tool/tests/widget_timeline_plan_test.swift").read_text()
            )
            build = subprocess.run(
                ["swiftc", "-parse-as-library", "model.swift", "main_test.swift", "-o", "t"],
                cwd=tmp, capture_output=True, text=True,
            )
            self.assertEqual(build.returncode, 0, build.stderr)
            data = tmp / "data"
            data.mkdir()
            run = subprocess.run([str(tmp / "t"), str(data)], capture_output=True, text=True)
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertIn("widget timeline plan checks passed", run.stdout)


if __name__ == "__main__":
    unittest.main()
