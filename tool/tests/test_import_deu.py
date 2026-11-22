"""Dong-eui 2026-2 importer: merge, closure and period-literal rules, plus asset totals."""
import collections
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('deu', ROOT / 'tool/timetable/import_deu.py')
D = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(D)
ASSET = json.loads((ROOT / 'assets/timetable/deu-main-2026-2.json').read_text(encoding='utf-8'))


def row(kind, key, target, lecture, more=(), department=None, title='소통과협력', cls='계교'):
    cells = {'구분': cls, '강좌번호': key, '교과목명': title, '학점/시간': '3/3',
             '담당교수': '홍길동', '강의': lecture}
    if kind != 'b':
        cells['수강대상'] = target
    return {'kind': kind, 'attachNo': 1, 'page': 1, 'y': 100, 'cells': cells,
            'more': [{'수강대상': m} for m in more], 'department': department, 'area': None}


class DeuImportTest(unittest.TestCase):
    def test_periods_stay_literal_and_rows_merge_without_duplicates(self):
        rows = [
            row('c', '100137-004', '조선해양공학과(1)', '원격사이버강좌 (별도제한)'),
            row('c', '100137-004', '토목공학과(1)', '원격사이버강좌 (별도제한)', more=['도시공학과(1)']),
            row('a', '201061-002', '디지털융합학과(1)', '생과310[월1-3](45)'),
            row('b', '401763-001', None, '2인207[화4],[수2-3](50)', department='국어국문학과',
                title='1 이야기와소설의이해', cls='전필'),
        ]
        courses, excluded = D.build(rows, [])
        by = {c['courseCode'] + '-' + c['section']: c for c in courses}
        self.assertEqual(excluded, [])
        online = by['100137-004']
        self.assertEqual(online['departments'], ['조선해양공학과', '토목공학과', '도시공학과'])
        self.assertEqual(online['scheduleStatus'], 'unscheduled')
        self.assertEqual(len(online['remarks'].split(' | ')), 3)  # one source line, credits, status
        period = by['201061-002']
        self.assertEqual((period['scheduleStatus'], period['schedules'], period['sourceSchedule'],
                          period['sourceClassroom']), ('unrecognized', [], '[월1-3]', '생과310'))
        major = by['401763-001']
        self.assertEqual((major['courseName'], major['departments'], major['sourceSchedule']),
                         ('이야기와소설의이해', ['국어국문학과'], '[화4],[수2-3]'))

    def test_closed_courses_are_excluded_and_conflicts_raise(self):
        rows = [row('a', '300267-003', '전체(1)', '공과215[월1](58)'),
                row('a', '300267-004', '전체(1)', '공과215[월2](58)')]
        courses, excluded = D.build(rows, [{'교과목코드': '300267-003'}])
        self.assertEqual(excluded, ['300267-003'])
        self.assertEqual([c['section'] for c in courses], ['004'])
        with self.assertRaises(ValueError):
            D.build([row('a', '300267-004', '전체(1)', '공과215[월2](58)'),
                     row('a', '300267-004', '전체(1)', '공과215[화2](58)')], [])

    def test_clipped_audience_cell_keeps_its_text(self):
        self.assertEqual(D.audience('미래모빌리티학과(1)'), ('미래모빌리티학과', '1'))
        self.assertEqual(D.audience('시니어스포츠지도학과('), ('시니어스포츠지도학과', None))

    def test_asset_totals(self):
        courses = ASSET['courses']
        self.assertEqual(ASSET['sourceRowCount'], 1263)
        self.assertEqual(len(courses), 1253)
        self.assertEqual(len({c['sourceId'] for c in courses}), 1253)
        self.assertEqual(len(ASSET['excludedClosedCourses']), 7)
        status = collections.Counter(c['scheduleStatus'] for c in courses)
        self.assertEqual(status, {'unrecognized': 1193, 'unscheduled': 60})
        self.assertTrue(all(c['schedules'] == [] for c in courses))
        self.assertTrue(all(D.SLOT.search(c['sourceSchedule']) for c in courses
                            if c['scheduleStatus'] == 'unrecognized'))


if __name__ == '__main__':
    unittest.main()
