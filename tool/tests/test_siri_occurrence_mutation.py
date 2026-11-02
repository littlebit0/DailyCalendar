"""Production Siri SQLite mutation paths against a disposable database, not app data."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]

class SiriOccurrenceMutationTest(unittest.TestCase):
    @unittest.skipUnless(shutil.which('swiftc'), 'Swift compiler required')
    def test_production_sql(self):
        source = (ROOT / 'apple_siri/DailySiriIntents.swift').read_text()
        identity = source.split('// BEGIN SIRI OCCURRENCE IDENTITY\n', 1)[1].split('// END SIRI OCCURRENCE IDENTITY', 1)[0]
        model = source.split('struct DailySiriEvent: Sendable {', 1)[1].split('\n#if os(iOS)', 1)[0]
        model = 'struct DailySiriEvent: Sendable {' + model
        visibility = source.split('// BEGIN LMS VISIBILITY POLICY\n', 1)[1].split('// END LMS VISIBILITY POLICY', 1)[0]
        database = source.split('private enum DailySiriDatabase {', 1)[1].split('\n@available(iOS 16.0, macOS 13.0, *)\nstruct DailyEventQuery', 1)[0]
        database = 'private enum DailySiriDatabase {' + database
        a = database.index('  private static func databaseURL()')
        b = database.index('  private static func normalized(', a)
        database = database[:a] + '  private static func databaseURL() -> URL? { testURL }\n\n' + database[b:]
        a = database.index('  private static func lmsVisibility()')
        b = database.index('  private static func withDatabase', a)
        database = database[:a] + '  private static func lmsVisibility() -> DailySiriLmsVisibility { DailySiriLmsVisibility(ownerID: nil, snapshot: nil) }\n\n' + database[b:]
        with tempfile.TemporaryDirectory() as d:
            main = Path(d) / 'main.swift'
            main.write_text((ROOT / 'tool/tests/siri_occurrence_mutation_test.swift').read_text() + '\n' + identity + model + visibility + database)
            executable = Path(d) / 'test'
            compiled = subprocess.run(['swiftc', str(main), '-o', str(executable)], capture_output=True, text=True)
            self.assertEqual(compiled.returncode, 0, compiled.stderr)
            result = subprocess.run([str(executable), str(Path(d) / 'events.sqlite'), str(ROOT / 'test/fixtures/recurrence_anchor_cases.json'), str(ROOT / 'test/fixtures/recurrence_detail_cases.json')], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('Siri occurrence mutation checks passed', result.stdout)
            self.assertIn('Siri recurrence detail fixtures passed', result.stdout)
            self.assertIn('Siri until-day inclusion checks passed', result.stdout)
            self.assertIn('Siri update requirement checks passed', result.stdout)
            self.assertIn('Siri read failure checks passed', result.stdout)
