import copy
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    'kookmin', ROOT / 'tool/timetable/import_kookmin.py')
kookmin = importlib.util.module_from_spec(spec)
spec.loader.exec_module(kookmin)
FIXTURE = json.loads((ROOT / 'tool/tests/fixtures/kookmin-real-rows.json').read_text())


class KookminPublishedRowsTest(unittest.TestCase):
    def converted(self):
        return kookmin.convert(FIXTURE['rows'], FIXTURE['dictionary'],
                               FIXTURE['shortPeriods'])

    def test_explicit_closure_is_excluded_and_actual_categories_are_retained(self):
        courses, _ = self.converted()
        self.assertEqual(len(courses), 7)
        for course in courses:
            source = next(row for row in FIXTURE['rows']
                          if row['subjectId'] == course['courseCode']
                          and row['classSequence'] == course['section'])
            self.assertFalse(source['closed'])
            self.assertNotEqual(next(iter(course['departmentClassifications'].values())), '00')

    def test_actual_concentrated_end_dates_use_runtime_period_schema(self):
        courses, _ = self.converted()
        ends = {'1231701': '2026-10-21', '0716902': '2026-10-23',
                '0395402': '2026-10-26'}
        for course in courses:
            if course['courseCode'] in ends:
                self.assertEqual(course['period'], {
                    'startDate': '2026-09-01', 'endDate': ends[course['courseCode']]})

    def test_special_service_and_training_do_not_repeat_unverified_dates(self):
        courses, unresolved = self.converted()
        self.assertEqual(set(unresolved), {'1095100-01', '0294104-01'})
        for course in courses:
            if course['courseCode'] in {'1095100', '0294104'}:
                self.assertEqual(course['schedules'], [])
                self.assertEqual(course['scheduleStatus'], 'unrecognized')
                self.assertTrue(course['sourceSchedule'])
        alpha = next(c for c in courses if c['courseCode'] == '1399800')
        self.assertEqual(alpha['scheduleStatus'], 'unscheduled')
        self.assertEqual(alpha['schedules'], [])

    def test_unpublished_department_is_preserved_as_code_without_invented_name(self):
        courses, _ = self.converted()
        unknown = next(c for c in courses if c['courseCode'] == '1147400')
        self.assertEqual(unknown['departments'], ['40053'])
        self.assertIn('학과명 미게시', unknown['departmentRemarks']['40053'])

    def test_actual_plan_department_proof_applies_only_to_verified_identity(self):
        row = next(row for row in FIXTURE['rows'] if row['subjectId'] == '1147400')
        proof = [{'departmentCode': '40053', 'name': '공학교육혁신센터',
                  'courseKeys': [row['id']],
                  'sourceEvidence': 'kookmin-unmapped-department-plan-education.json'}]
        courses, _ = kookmin.convert(FIXTURE['rows'], FIXTURE['dictionary'],
                                     FIXTURE['shortPeriods'], proof)
        course = next(c for c in courses if c['courseCode'] == '1147400')
        self.assertEqual(course['departments'], ['공학교육혁신센터'])
        self.assertNotIn('학과명 미게시', course['departmentRemarks']['공학교육혁신센터'])

    def test_invalid_clock_components_and_duplicate_identity_reject(self):
        bad = copy.deepcopy(FIXTURE['rows'])
        timed = next(row for row in bad if row['schedule']['lectureTimes'])
        timed['schedule']['lectureTimes'][0]['start']['minute'] = 60
        with self.assertRaises(ValueError):
            kookmin.convert(bad, FIXTURE['dictionary'], FIXTURE['shortPeriods'])

    def test_actual_official_week_anchors_exclude_only_documented_no_class_weeks(self):
        fixture = json.loads((ROOT / 'tool/tests/fixtures/kookmin-dated-proof.json').read_text())
        courses, unresolved = kookmin.convert(fixture['rows'], fixture['dictionary'], [],
                                              dated_proofs=fixture['proofs'])
        self.assertEqual(unresolved, [])
        thursday = next(c for c in courses if c['courseCode'] == '0368203')
        wednesday = next(c for c in courses if c['courseCode'] == '1131900')
        self.assertEqual(len(thursday['schedules']), 12)
        self.assertEqual(len(wednesday['schedules']), 13)
        self.assertNotIn('2026-09-24', {m['date'] for m in thursday['schedules']})
        self.assertIn('2026-09-23', {m['date'] for m in wednesday['schedules']})
        self.assertEqual(thursday['schedules'][-1]['date'], '2026-12-03')
        self.assertEqual(wednesday['schedules'][-1]['date'], '2026-12-02')
        bad = copy.deepcopy(fixture['proofs'])
        bad[0]['dateMeetings'][0]['date'] = '2026-09-24'
        bad[0]['dateMeetings'][0]['officialWeek'] = 4
        with self.assertRaises(ValueError):
            kookmin.convert(fixture['rows'], fixture['dictionary'], [], dated_proofs=bad)
        bad = copy.deepcopy(FIXTURE['rows'])
        bad.append(next(row for row in bad if not row['closed']))
        with self.assertRaises(ValueError):
            kookmin.convert(bad, FIXTURE['dictionary'], FIXTURE['shortPeriods'])


if __name__ == '__main__':
    unittest.main()
