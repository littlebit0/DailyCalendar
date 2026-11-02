import copy
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('hansung', ROOT / 'tool/timetable/import_hansung.py')
H = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(H)
FIXTURE = json.loads((Path(__file__).parent / 'fixtures/hansung-real-educational-rows.json').read_text())


class HansungImportTest(unittest.TestCase):
    def prepare(self, data=None):
        data = data or FIXTURE
        return H.prepare(data['rows'], data['proofs'], set(data['neutralLines']))[0]

    def test_current_source_preserves_night_clock_restrictions_and_real_section(self):
        courses = {c['courseCode'] + '-' + c['section']: c for c in self.prepare()}
        night = courses['P012012-N']
        self.assertEqual(sorted({(m['weekday'], m['startMinute'], m['endMinute'])
                          for m in night['schedules']}), [(1, 1080, 1165), (4, 1165, 1245)])
        self.assertEqual(night['period'], {'startDate': '2026-08-31', 'endDate': '2026-12-06'})
        self.assertIn('계획서 수강대상:', '\n'.join(night['departmentRemarks'].values()))
        self.assertEqual(courses['GEN0925-@']['section'], '@')
        self.assertFalse({m['date'] for m in night['schedules']} & {'2026-09-24', '2026-10-05'})
        self.assertTrue(all('2026-08-31' <= m['date'] <= '2026-12-06' for m in night['schedules']))
        self.assertIn('2026-11-30', {m['date'] for m in night['schedules']})

    def test_holiday_intensive_and_prior_term_credit_do_not_become_weekly(self):
        courses = {c['courseCode'] + '-' + c['section']: c for c in self.prepare()}
        for key in ['P010182-A', 'P010143-A', 'P017022-Z']:
            self.assertEqual(courses[key]['schedules'], [])
            self.assertNotIn('period', courses[key])
        self.assertIn('선수·사전이수 안내:', '\n'.join(courses['P010182-A']['departmentRemarks'].values()))

    def test_unknown_partial_clocks_and_simultaneous_rooms_reject(self):
        for raw in ['탐구관307 수2~3M', '탐구관307 화2M~3M',
                    '탐구관307 토1~3M', '상상관602 월4~5 / 상상관603 월4~5']:
            with self.assertRaises(ValueError):
                H.schedules(raw)

    def test_wrong_current_identity_rejects_and_incomplete_week_never_approves(self):
        changed = copy.deepcopy(FIXTURE)
        changed['proofs']['P012012-N']['semester'] = '1'
        with self.assertRaises(ValueError):
            self.prepare(changed)
        changed = copy.deepcopy(FIXTURE)
        changed['proofs']['P012012-N']['weeks'].pop()
        night = next(c for c in self.prepare(changed) if c['courseCode'] == 'P012012')
        self.assertEqual(night['schedules'], [])

    def test_contacts_links_and_unrequested_plan_fields_do_not_ship(self):
        changed = copy.deepcopy(FIXTURE)
        for row in changed['rows']:
            row['bigo'] = '선수과목 필수 <br> x@example.org 02-1234-5678 https://meet.example/secret'
            row['employeeId'] = 'private'
        serialized = json.dumps(self.prepare(changed), ensure_ascii=False)
        for secret in ['x@example.org', '02-1234-5678', 'https://meet.example', 'employeeId', 'sourceResponseSha256']:
            self.assertNotIn(secret, serialized)
        self.assertIn('선수과목 필수', serialized)

    def test_clock_uses_break_inclusive_slots(self):
        self.assertEqual(H.clock(1, '1', '2'), (540, 630))
        self.assertEqual(H.clock(1, '10', '11'), (1080, 1165))
        self.assertEqual(H.clock(4, '11M', '12M'), (1165, 1245))
        self.assertEqual(H.clock(3, '13', '14'), (1245, 1335))
        self.assertEqual(H.clock(2, '1', '2M'), (540, 660))
        self.assertEqual(H.clock(5, '9', '9M'), (1020, 1080))
        self.assertEqual(H.clock(2, '10', '14M'), (1080, 1360))

    def test_regenerated_meetings_equal_the_committed_asset(self):
        asset = json.loads((ROOT / 'assets/timetable/hansung-main-2026-2.json').read_text(encoding='utf-8'))
        compared = 0
        for course in asset['courses']:
            if course['scheduleStatus'] != 'scheduled' or not course['schedules']:
                continue
            got = {(m['weekday'], m['startMinute'], m['endMinute'], m['classroom'])
                   for m in H.schedules(course['sourceClassroom'])}
            want = {(m['weekday'], m['startMinute'], m['endMinute'], m['classroom'])
                    for m in course['schedules']}
            self.assertEqual(got, want, course['sourceId'])
            compared += 1
        self.assertGreater(compared, 1000)


if __name__ == '__main__':
    unittest.main()
