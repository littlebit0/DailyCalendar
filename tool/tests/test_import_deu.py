"""Dong-eui 2026-2 importer: merge, closure and period-clock rules, plus asset totals."""
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
    def test_periods_become_clock_meetings_and_rows_merge_without_duplicates(self):
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
                          period['sourceClassroom']),
                         ('scheduled', [{'weekday': 1, 'startMinute': 540, 'endMinute': 720,
                                         'classroom': '생과310'}], '[월1-3]', '생과310'))
        major = by['401763-001']
        self.assertEqual((major['courseName'], major['departments'], major['sourceSchedule']),
                         ('이야기와소설의이해', ['국어국문학과'], '[화4],[수2-3]'))
        # A room printed once carries to the next slot: 화4 = 12:00-13:00, 수2-3 = 10:00-12:00.
        self.assertEqual([(m['weekday'], m['startMinute'], m['endMinute'], m['classroom'])
                          for m in major['schedules']], [(2, 720, 780, '2인207'), (3, 600, 720, '2인207')])

    def test_meetings_merge_only_same_room_and_hold_clipped_cells(self):
        self.assertEqual(D.meetings('1인302[월3],[월4-5](30)'),
                         [{'weekday': 1, 'startMinute': 660, 'endMinute': 840, 'classroom': '1인302'}])
        self.assertEqual(len(D.meetings('1인302[월3],1인303[월4-5](30)')), 2)
        self.assertEqual(D.meetings('지천관[토12](20)')[0]['endMinute'], 21 * 60)  # 12교시 20:00-21:00
        self.assertIsNone(D.meetings('지천관621[토8-9],지천관620[토'))

    def test_closure_listed_courses_stay_and_conflicts_raise(self):
        rows = [row('a', '300267-003', '전체(1)', '공과215[월1](58)'),
                row('a', '300267-004', '전체(1)', '공과215[월2](58)')]
        courses, listed = D.build(rows, [{'교과목코드': '300267-003'}])
        self.assertEqual(listed, ['300267-003'])
        self.assertEqual([c['section'] for c in courses], ['003', '004'])
        self.assertIn('폐강 여부는 판단하지 않음', courses[0]['remarks'])
        self.assertNotIn('폐강', courses[1]['remarks'])
        with self.assertRaises(ValueError):
            D.build([row('a', '300267-004', '전체(1)', '공과215[월2](58)'),
                     row('a', '300267-004', '전체(1)', '공과215[화2](58)')], [])

    def test_clipped_audience_cell_keeps_its_text(self):
        self.assertEqual(D.audience('미래모빌리티학과(1)'), ('미래모빌리티학과', '1'))
        self.assertEqual(D.audience('시니어스포츠지도학과('), ('시니어스포츠지도학과', None))

    def test_asset_totals(self):
        courses = ASSET['courses']
        self.assertEqual(ASSET['sourceRowCount'], 1263)
        self.assertEqual(len(courses), 1260)
        self.assertEqual(len({c['sourceId'] for c in courses}), 1260)
        self.assertEqual(len(ASSET['closureListedCourses']), 7)
        status = collections.Counter(c['scheduleStatus'] for c in courses)
        self.assertEqual(status, {'scheduled': 1199, 'unrecognized': 1, 'unscheduled': 60})
        self.assertTrue(all(bool(c['schedules']) == (c['scheduleStatus'] == 'scheduled') for c in courses))
        self.assertTrue(all(D.SLOT.search(c['sourceSchedule']) for c in courses
                            if c['scheduleStatus'] != 'unscheduled'))


if __name__ == '__main__':
    unittest.main()
