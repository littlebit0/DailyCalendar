"""#921: Apple widget and alarm wording follows the app language."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
WIDGETS = (ROOT / "apple_widgets/DailyWidgets.swift").read_text()
APP = (ROOT / "ios/Runner/AppDelegate.swift").read_text()


def block(source, name):
    return source[source.index(f"// BEGIN {name}") : source.index(f"// END {name}")]


class AppleWidgetTextTest(unittest.TestCase):
    def test_views_take_their_wording_from_the_text_table(self):
        views = WIDGETS.replace(block(WIDGETS, "WIDGET TEXT"), "")
        for korean in (
            "오늘 일정이 없습니다", "오늘 일정 없음", "남은 일정이 없습니다", "이번 주 일정",
            "표시할 D-day가 없습니다", "앱을 열어 일정을 갱신하세요", "개 일정", '"종일"', '"진행 중"',
            "다시 알림", '"10분"', "일정 알람", "완료로 변경", "주간 및 월간 캘린더",
        ):
            self.assertNotIn(korean, views, korean)
        # The snapshot's language reaches the placeholder and the Live Activity.
        self.assertIn("localeTag: localeTag", views)
        self.assertEqual(views.count("DailyWidgetText(localeTag: context.attributes.metadata?.localeTag)"), 2)
        self.assertIn("context.attributes.metadata?.snoozeMinutes ?? 10", views)

    def test_alarm_configuration_uses_the_alarm_text(self):
        alarm = APP.replace(block(APP, "ALARM TEXT"), "")
        for korean in ("다시 알림", '"중지"'):
            self.assertNotIn(korean, alarm, korean)
        self.assertIn('arguments["localeTag"] as? String', alarm)
        self.assertIn("snoozeMinutes: snoozeMinutes, localeTag: text.localeTag", alarm)
        dart = (ROOT / "lib/core/widgets/calendar_widget_service.dart").read_text()
        self.assertIn("'localeTag': localeName", dart)

    @unittest.skipUnless(shutil.which("swiftc"), "Swift compiler required")
    def test_wording_in_four_languages(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            (tmp / "text.swift").write_text(
                "import Foundation\n"
                "enum DailySiriLanguage { case korean, english, japanese, traditionalChinese }\n"
                + block(WIDGETS, "WIDGET TEXT") + block(APP, "ALARM TEXT")
            )
            (tmp / "main_test.swift").write_text((ROOT / "tool/tests/apple_widget_text_test.swift").read_text())
            build = subprocess.run(
                ["swiftc", "-parse-as-library", "text.swift", "main_test.swift", "-o", "t"],
                cwd=tmp, capture_output=True, text=True,
            )
            self.assertEqual(build.returncode, 0, build.stderr)
            run = subprocess.run([str(tmp / "t")], capture_output=True, text=True)
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertIn("apple widget text checks passed", run.stdout)


if __name__ == "__main__":
    unittest.main()
