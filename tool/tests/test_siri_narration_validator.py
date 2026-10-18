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
