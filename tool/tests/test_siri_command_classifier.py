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
expect("   ", nil)
print("Siri command classifier checks passed")
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


if __name__ == '__main__':
    unittest.main()
