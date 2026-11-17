"""Production iOS alarm replacement plan against a fake AlarmKit with schedule failures."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]

class IosAlarmReplacementTest(unittest.TestCase):
    @unittest.skipUnless(shutil.which('swiftc'), 'Swift compiler required')
    def test_production_plan(self):
        source = (ROOT / 'ios/Runner/AppDelegate.swift').read_text()
        plan = source.split('struct DailyAlarmPlan {', 1)[1].split('\nprivate final class DailyAlarmKit {', 1)[0]
        with tempfile.TemporaryDirectory() as d:
            main = Path(d) / 'test.swift'
            main.write_text((ROOT / 'tool/tests/ios_alarm_replacement_test.swift').read_text() + '\nstruct DailyAlarmPlan {' + plan)
            executable = Path(d) / 'test'
            compiled = subprocess.run(['swiftc', '-parse-as-library', str(main), '-o', str(executable)], capture_output=True, text=True)
            self.assertEqual(compiled.returncode, 0, compiled.stderr)
            result = subprocess.run([str(executable)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('iOS alarm replacement checks passed', result.stdout)

if __name__ == '__main__':
    unittest.main()
