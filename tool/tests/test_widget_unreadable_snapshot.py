"""#926: an Apple widget never shows an unreadable snapshot as "no events today"."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SWIFT = (ROOT / "apple_widgets/DailyWidgets.swift").read_text()


def between(start, end):
    return SWIFT[SWIFT.index(start) : SWIFT.index(end)]


def snapshot_model():
    """The production snapshot model and loader, reading from a test directory."""
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
    ])


class WidgetUnreadableSnapshotTest(unittest.TestCase):
    def test_today_and_lock_screen_views_show_the_refresh_state(self):
        today = between("struct DailyTodayWidgetView: View {", "#if os(iOS)\nstruct DailyLockScreenTodayView")
        self.assertLess(today.index("needsRefresh == true"), today.index('"오늘 일정이 없습니다"'))
        lock = between("struct DailyLockScreenTodayView: View {", "struct DailyTodayWidgetRootView")
        # inline, circular and rectangular each branch before their empty text.
        self.assertEqual(lock.count("entry.snapshot.needsRefresh == true"), 3)
        self.assertLess(lock.index("needsRefresh == true"), lock.index('"오늘 일정 없음"'))
        self.assertLess(lock.rindex("needsRefresh == true"), lock.index('"남은 일정이 없습니다"'))

    def test_home_screen_titles_are_privacy_sensitive(self):
        for start, end in (
            ("struct DailyTodayWidgetView: View {", "#if os(iOS)\nstruct DailyLockScreenTodayView"),
            ("private struct DailyWidgetEventLabel: View {", "private struct DailyTodoToggle"),
            ("struct DailyDdayWidgetView: View {", "private struct DailyWidgetBackgroundModifier"),
        ):
            self.assertIn(".privacySensitive()", between(start, end), start)

    @unittest.skipUnless(shutil.which("swiftc"), "Swift compiler required")
    def test_unreadable_snapshot_asks_for_a_refresh(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            (tmp / "model.swift").write_text(snapshot_model())
            (tmp / "main_test.swift").write_text(
                (ROOT / "tool/tests/widget_unreadable_snapshot_test.swift").read_text()
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
            self.assertIn("widget unreadable snapshot checks passed", run.stdout)


if __name__ == "__main__":
    unittest.main()
