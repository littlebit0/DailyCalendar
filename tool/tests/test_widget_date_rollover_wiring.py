"""Static wiring checks for the native #103 date rollover (Kotlin/C++ are not built locally)."""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
KOTLIN = ROOT / "android/app/src/main/kotlin/com/littlebit0/dailycalendar"
CPP = (ROOT / "windows/runner/windows_widget_bridge.cpp").read_text()
SWIFT = (ROOT / "apple_widgets/DailyWidgets.swift").read_text()


class WidgetDateRolloverWiringTest(unittest.TestCase):
    def test_android_widgets_read_the_rolled_snapshot(self):
        widgets = (KOTLIN / "DailyWidgets.kt").read_text()
        self.assertEqual(widgets.count("DailyAndroidWidgetStore.snapshot(context)"), 0)
        self.assertEqual(widgets.count("DailyAndroidWidgetStore.displaySnapshot(context)"), 3)
        store = (KOTLIN / "DailyAndroidWidgetStore.kt").read_text()
        self.assertIn("DailyWidgetDateRollover.rollForward", store)
        # Completion toggles must reach the per-day views too.
        self.assertIn('optJSONArray("dailyViews")', store)

    def test_android_rollover_returns_null_outside_the_cached_grid(self):
        source = (KOTLIN / "DailyWidgetDateRollover.kt").read_text()
        for needle in ('"snapshotDate"', '"dailyViews"', '"ddays"', "?: return null", "GregorianCalendar(zone)"):
            self.assertIn(needle, source)
        # Behaviour is covered by DailyWidgetDateRolloverTest (run by Gradle in CI).
        self.assertTrue((ROOT / "android/app/src/test/kotlin/com/littlebit0/dailycalendar/DailyWidgetDateRolloverTest.kt").exists())

    def test_windows_rolls_before_showing_and_on_new_snapshots(self):
        show = CPP[CPP.index("void WindowsWidgetBridge::ShowMiniCalendar") :][:200]
        self.assertIn("RollSnapshotToToday();", show)
        self.assertIn("snapshot_ = std::move(parsed);\n  RollSnapshotToToday();", CPP)
        self.assertIn("apply(view.today_events)", CPP)
        self.assertIn("daily_widgets::DecideRollover", CPP)
        self.assertIn("view.ddays", CPP)  # D-days come from the day's own ranked list

    def test_apple_provider_and_midnight_refresh(self):
        self.assertIn("DailyWidgetSnapshot.load(for: now)", SWIFT)
        self.assertIn("calendar.date(byAdding: .day, value: 1", SWIFT)
        self.assertNotIn("startOfDay(for: now).addingTimeInterval", SWIFT)
        # Every widget family shows the refresh state, not only the today view.
        self.assertGreaterEqual(SWIFT.count("snapshot.needsRefresh == true"), 3)

    @unittest.skipUnless(subprocess.run(["which", "swiftc"], capture_output=True).returncode == 0, "swiftc missing")
    def test_apple_rollover_logic(self):
        block = SWIFT[SWIFT.index("// BEGIN WIDGET ROLLOVER") : SWIFT.index("// END WIDGET ROLLOVER")]
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            (tmp / "rollover.swift").write_text("import Foundation\n" + block)
            (tmp / "main_test.swift").write_text((ROOT / "tool/tests/widget_date_rollover_test.swift").read_text())
            build = subprocess.run(
                ["swiftc", "-parse-as-library", "rollover.swift", "main_test.swift", "-o", "rt"],
                cwd=tmp, capture_output=True, text=True,
            )
            self.assertEqual(build.returncode, 0, build.stderr)
            run = subprocess.run([str(tmp / "rt")], capture_output=True, text=True)
            self.assertEqual(run.returncode, 0, run.stderr)


if __name__ == "__main__":
    unittest.main()
