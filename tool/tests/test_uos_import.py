import copy
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('uos', ROOT/'tool/timetable/import_uos.py')
uos = importlib.util.module_from_spec(spec)
spec.loader.exec_module(uos)


class UosImportTest(unittest.TestCase):
    def setUp(self):
        self.rows = json.loads((ROOT/'tool/tests/fixtures/uos-real-rows.json').read_text())

    def test_actual_short_period_uses_printed_dates_not_week_count(self):
        courses = uos.parse_rows(self.rows, 2026, '2')
        short = [c for c in courses if 'sourceAdministrativePeriod' in c]
        self.assertEqual(len(short), 2)
        self.assertEqual([c['sourceAdministrativePeriod'] for c in short], [
            {'startDate': '2026-09-29', 'endDate': '2026-10-26'},
            {'startDate': '2026-10-27', 'endDate': '2026-11-23'},
        ])
        self.assertIn('A형 9주차', next(iter(short[1]['departmentRemarks'].values())))
        self.assertTrue(all(c['scheduleStatus'] == 'unrecognized' and not c['schedules'] for c in short))
        self.assertTrue(all('period' not in c for c in short))

    def test_unknown_late_clock_blocks_whole_course(self):
        courses = uos.parse_rows(self.rows, 2026, '2')
        course = next(c for c in courses if c['courseCode'] == '45129')
        self.assertEqual(course['scheduleStatus'], 'unrecognized')
        self.assertEqual(course['schedules'], [])
        self.assertIn('[10,11,12,13]', course['sourceSchedule'])

    def test_simultaneous_source_rooms_do_not_become_double_meetings(self):
        with self.assertRaises(ValueError):
            uos.meetings('월[8]/33-101,월[8]/5-202')

    def test_actual_missing_time_stays_missing_and_room_comma_is_retained(self):
        courses = uos.parse_rows(self.rows, 2026, '2')
        missing = [c for c in courses if not c['sourceSchedule']]
        self.assertEqual(len(missing), 2)
        self.assertTrue(all(c['scheduleStatus'] == 'unscheduled' and not c['schedules'] for c in missing))
        self.assertTrue(any(',' in m['classroom'] for c in courses for m in c['schedules']))

    def test_invalid_period_and_duplicate_identity_are_rejected(self):
        bad = copy.deepcopy(self.rows)
        bad[1][12] = 'A형 9주차(20261123~20261027)'
        with self.assertRaises(ValueError):
            uos.parse_rows(bad, 2026, '2')
        with self.assertRaises(ValueError):
            uos.parse_rows(self.rows + [self.rows[1]], 2026, '2')

    def test_official_async_and_credit_recognition_slots_never_repeat(self):
        rows = json.loads((ROOT/'tool/tests/fixtures/uos-operating-source-rows.json').read_text())
        proof = json.loads((ROOT/'tool/tests/fixtures/uos-operating-proof.json').read_text())
        courses = uos.apply_operating_proof(uos.parse_rows(rows, 2026, '2'), proof)
        self.assertEqual(len(courses), 33)
        self.assertTrue(all(not c['schedules'] for c in courses))
        self.assertEqual(sum(c['scheduleStatus'] == 'unscheduled' for c in courses), 26)
        self.assertEqual(sum(c['scheduleStatus'] == 'unrecognized' for c in courses), 7)
        for c in courses:
            self.assertTrue(c['sourceSchedule'])
            if c['courseCode'] == '01951':
                self.assertIn('비실시간', '\n'.join(c['departmentRemarks'].values()))

    def test_operating_proof_must_match_actual_current_course_identity(self):
        rows = json.loads((ROOT/'tool/tests/fixtures/uos-operating-source-rows.json').read_text())
        proof = json.loads((ROOT/'tool/tests/fixtures/uos-operating-proof.json').read_text())
        proof['records'][0]['title'] = 'different source title'
        with self.assertRaises(ValueError):
            uos.apply_operating_proof(uos.parse_rows(rows, 2026, '2'), proof)


if __name__ == '__main__':
    unittest.main()
