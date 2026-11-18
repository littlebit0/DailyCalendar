"""Rule-based Signal/Siri command classification, compiled from the production source."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]

CHECKS = '''import Foundation
enum DailySiriAction: String { case yesterday, today, tomorrow, date, next, search, dday, add, update, delete }
func expect(_ text: String, _ action: DailySiriAction?) {
  let actual = DailySiriCommandClassifier.classify(text)
  if actual != action { fatalError("\\(text): expected \\(String(describing: action)), got \\(String(describing: actual))") }
}
expect("Show today's schedule", .today)
expect("What's my schedule tomorrow?", .tomorrow)
expect("Reschedule my meeting to tomorrow", .update)
expect("Show today's events", .today)
expect("Add an event tomorrow", .add)
expect("내일 일정 삭제", .delete)
expect("Schedule a meeting with Kim", .add)
expect("schedule lunch at noon", .add)
expect("내일 일정 추가", .add)
expect("Delete tomorrow's schedule", .delete)
expect("Change my schedule", .update)
expect("Please schedule lunch at noon", .add)
expect("Could you schedule lunch tomorrow", .add)
expect("can you schedule dinner with Kim", .add)
expect("I need to schedule a dentist visit", .add)
expect("Please show today's schedule", .today)
expect("Could you show my schedule tomorrow", .tomorrow)
expect("Can you tell me my schedule for tomorrow", .tomorrow)
expect("   ", nil)
expect("내일 일정 삭제하지 마", nil)
expect("내일 회의 취소하지 말아줘", nil)
expect("Don\\u{2019}t delete tomorrow's meeting", nil)
expect("삭제하지 말고 수정해줘", .update)
expect("등록금 납부 일정 검색", .search)
expect("휴강 취소된 수업 찾아줘", .search)
expect("등록금 납부 내일 3시 추가", .add)
expect("내일 회의 등록", .add)
expect("내일 회의 취소", .delete)
print("Siri command classifier checks passed")
'''

DURATION_CHECKS = '''import Foundation
let calendar = Calendar.current
let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
func at(_ hour: Int, _ minute: Int = 0) -> Date {
  calendar.date(bySettingHour: hour, minute: minute, second: 0, of: tomorrow)!
}
func expect(_ text: String, _ start: Date?, _ end: Date?) {
  let parsed = DailySpokenTemporalParser.parse(text)
  if parsed?.startAt != start || parsed?.endAt != end {
    fatalError("\\(text): got \\(String(describing: parsed?.startAt)) ~ \\(String(describing: parsed?.endAt))")
  }
}
expect("내일 오후 3시부터 2시간 회의 추가", at(15), at(17))
expect("내일 오후 3시부터 1시간 30분 회의 추가", at(15), at(16, 30))
expect("내일 오전 10시부터 45분 동안 회의", at(10), at(10, 45))
expect("내일 오후 3시부터 5시 회의", at(15), at(17))
expect("내일 오후 3시 30분 동안 회의", at(15, 30), nil)
expect("내일 오후 3시 회의", at(15), nil)
// A length without a clock time must not be read as 2 o'clock.
if DailySpokenTemporalParser.parse("내일 2시간 회의 추가") != nil { fatalError("length read as a clock time") }
print("Siri spoken duration checks passed")
'''


class SiriCommandClassifierTest(unittest.TestCase):
    @unittest.skipUnless(shutil.which('swiftc'), 'Swift compiler required')
    def test_schedule_noun_verb_and_reschedule(self):
        source = (ROOT / 'apple_siri/DailySiriIntents.swift').read_text()
        block = source.split('// BEGIN SIRI COMMAND CLASSIFIER\n', 1)[1].split('// END SIRI COMMAND CLASSIFIER', 1)[0]
        with tempfile.TemporaryDirectory() as d:
            main = Path(d) / 'main.swift'
            main.write_text(CHECKS + '\n' + block)
            executable = Path(d) / 'test'
            compiled = subprocess.run(['swiftc', str(main), '-o', str(executable)], capture_output=True, text=True)
            self.assertEqual(compiled.returncode, 0, compiled.stderr)
            result = subprocess.run([str(executable)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('Siri command classifier checks passed', result.stdout)

    @unittest.skipUnless(shutil.which('swiftc'), 'Swift compiler required')
    def test_spoken_duration_is_not_an_end_time(self):
        source = (ROOT / 'apple_siri/DailySiriIntents.swift').read_text()
        block = 'struct DailySpokenTemporalValues' + source.split('struct DailySpokenTemporalValues', 1)[1].split('enum DailySiriLanguage', 1)[0]
        with tempfile.TemporaryDirectory() as d:
            main = Path(d) / 'main.swift'
            main.write_text(DURATION_CHECKS + '\n' + block)
            executable = Path(d) / 'test'
            compiled = subprocess.run(['swiftc', str(main), '-o', str(executable)], capture_output=True, text=True)
            self.assertEqual(compiled.returncode, 0, compiled.stderr)
            result = subprocess.run([str(executable)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('Siri spoken duration checks passed', result.stdout)



if __name__ == '__main__':
    unittest.main()
