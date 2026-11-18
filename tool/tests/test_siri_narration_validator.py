"""Generated Siri narration must keep every fact of the original response."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]

CHECKS = '''import Foundation
func check(_ candidate: String, _ expected: Bool, _ note: String) {
  let original = """
2026년 10월 14일 수요일 일정입니다.
09:00~10:00에 합성회의A 일정이 있습니다.
15:00~16:00에 합성회의B 일정이 있습니다.
"""
  let actual = DailySiriNarrationValidator.isFaithful(candidate, to: original, titles: ["합성회의A", "합성회의B"])
  if actual != expected { fatalError("\\(note): expected \\(expected), got \\(actual)") }
}
check("""
2026년 10월 14일 수요일 일정입니다.
09:00~10:00에 합성회의A 일정이 있습니다.
15:00~16:00에 합성회의B 일정이 있습니다.
""", true, "unchanged")
check("""
2026년 10월 14일 수요일 일정이에요.
오전 09:00~10:00에 합성회의A가 있어요.
15:00~16:00에는 합성회의B가 있어요.
""", true, "rephrased with the same facts")
check("""
2026년 10월 14일 수요일 일정입니다.
08:00~10:00에 합성회의A 일정이 있습니다.
15:00~16:00에 합성회의B 일정이 있습니다.
""", false, "changed time")
check("""
2026년 10월 14일 수요일 일정입니다.
09:00~10:00에 합성회의B 일정이 있습니다.
15:00~16:00에 합성회의A 일정이 있습니다.
""", false, "swapped titles")
check("""
2026년 10월 14일 금요일 일정입니다.
09:00~10:00에 합성회의A 일정이 있습니다.
15:00~16:00에 합성회의B 일정이 있습니다.
""", false, "wrong weekday")
check("""
2026년 10월 14일 수요일 일정입니다.
09:00~10:00에 합성회의A 일정이 없습니다.
15:00~16:00에 합성회의B 일정이 있습니다.
""", false, "existence negated")
check("""
2026년 10월 14일 수요일 일정입니다.
09:00~10:00에 합성회의A 일정이 있습니다. 15:00~16:00에 합성회의B 일정이 있습니다.
""", false, "line count changed")
check("""
2026년 10월 14일 수요일 일정입니다.
09:00~10:00에 합성회의A 일정이 있습니다.
15:00~16:00에 합성회의A 일정이 있습니다.
""", false, "duplicated title replaces another")
check("", false, "empty")

func checkEnglish(_ original: String, _ candidate: String, _ titles: [String], _ expected: Bool, _ note: String) {
  let actual = DailySiriNarrationValidator.isFaithful(candidate, to: original, titles: titles)
  if actual != expected { fatalError("\\(note): expected \\(expected), got \\(actual)") }
}
checkEnglish("Meeting is scheduled from 9:00 AM~10:00 AM.", "Meeting isn\\u{2019}t scheduled from 9:00 AM~10:00 AM.", ["Meeting"], false, "typographic negation")
checkEnglish("Meeting is scheduled from 9:00 AM~10:00 AM.", "Meeting is scheduled from 9:00 AM~10:00 AM.", ["Meeting"], true, "english unchanged")
checkEnglish("Meeting is scheduled from 9:00 AM~10:00 AM.", "你的 Meeting 不存在 9:00 AM~10:00 AM.", ["Meeting"], false, "chinese negation")
checkEnglish("Oct 14\\n\\nMeeting is scheduled on Oct 14.", "Oct 14\\nPlease double-check your calendar.\\nMeeting is scheduled on Oct 14.", ["Meeting"], false, "blank separator filled")
checkEnglish("Oct 14\\n\\nMeeting is scheduled on Oct 14.", "Oct 14\\n\\nMeeting is scheduled on Oct 14.", ["Meeting"], true, "blank separator kept")
checkEnglish("Meeting is an all-day event on Oct 14.", "Project Meeting is an all-day event on Oct 14.", ["Meeting"], false, "extended title")
checkEnglish("Meeting is an all-day event on Oct 14.", "Canceled Meeting is an all-day event on Oct 14.", ["Meeting"], false, "prefixed title")
checkEnglish("Meeting is an all-day event on Oct 14.", "The Meeting is an all-day event on Oct 14.", ["Meeting"], true, "article before title")
checkEnglish("Meeting is an all-day event on Oct 14.", "Meetings is an all-day event on Oct 14.", ["Meeting"], false, "suffixed latin title")
checkEnglish("Meeting is an all-day event on Oct 14.", "Meeting is a half-day event on Oct 14.", ["Meeting"], false, "all-day changed")
checkEnglish("Meeting is an all-day event on Oct 14.", "Meeting lasts all day on Oct 14.", ["Meeting"], true, "all-day rephrased")
checkEnglish("2026년 10월 14일 회의 일정입니다.", "2026년 10월 14일 정기회의 일정입니다.", ["회의"], false, "korean prefix")
checkEnglish("2026년 10월 14일 회의 일정입니다.", "2026년 10월 14일 회의는 일정이에요.", ["회의"], true, "korean particle")
checkEnglish("오전 9:00~오전 10:00에 회의 일정이 있습니다.", "오후 9:00~오전 10:00에 회의 일정이 있습니다.", ["회의"], false, "korean AM changed to PM")
checkEnglish("오전 9:00~오전 10:00에 회의 일정이 있습니다.", "9:00~10:00에 회의 일정이 있습니다.", ["회의"], false, "korean AM dropped")
checkEnglish("오전 9:00~오전 10:00에 회의 일정이 있습니다.", "오전 9:00~오전 10:00에 회의가 있어요.", ["회의"], true, "korean AM kept")
checkEnglish("Meeting is scheduled from 9:00 AM~10:00 AM.", "Meeting is scheduled from 9:00 PM~10:00 AM.", ["Meeting"], false, "english AM changed to PM")
checkEnglish("Meeting is scheduled from 9:00 AM~10:00 AM.", "Meeting runs from 9:00 a.m.~10:00 a.m.", ["Meeting"], true, "english AM respelled")
checkEnglish("15:00~16:00에 회의 일정이 있습니다.", "오전 15:00~16:00에 회의 일정이 있습니다.", ["회의"], false, "24-hour line gains a wrong AM")
checkEnglish("15:00~16:00에 회의 일정이 있습니다.", "오후 15:00~16:00에 회의 일정이 있습니다.", ["회의"], true, "24-hour line gains a matching PM")
checkEnglish("Meeting is an all-day event on Nov 15.", "Meeting is an all-day event on Dec 15.", ["Meeting"], false, "english month changed")
checkEnglish("Meeting is an all-day event on Nov 15.", "Meeting is an all-day event on November 15.", ["Meeting"], true, "english month spelled out")
print("Siri narration validator checks passed")
'''


class SiriNarrationValidatorTest(unittest.TestCase):
    @unittest.skipUnless(shutil.which('swiftc'), 'Swift compiler required')
    def test_validator(self):
        source = (ROOT / 'apple_siri/DailySiriIntents.swift').read_text()
        block = source.split('// BEGIN SIRI NARRATION VALIDATOR\n', 1)[1].split('// END SIRI NARRATION VALIDATOR', 1)[0]
        with tempfile.TemporaryDirectory() as d:
            main = Path(d) / 'main.swift'
            main.write_text(CHECKS + '\n' + block)
            executable = Path(d) / 'test'
            compiled = subprocess.run(['swiftc', str(main), '-o', str(executable)], capture_output=True, text=True)
            self.assertEqual(compiled.returncode, 0, compiled.stderr)
            result = subprocess.run([str(executable)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('Siri narration validator checks passed', result.stdout)


if __name__ == '__main__':
    unittest.main()
