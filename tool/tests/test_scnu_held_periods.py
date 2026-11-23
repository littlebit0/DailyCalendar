import copy
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    'apply_scnu', ROOT / 'tool/timetable/apply_scnu_held_periods.py')
apply_scnu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(apply_scnu)


def course(code, schedule, room, hours='3/3/0', department='학과'):
    return {'sourceId': f'scnu-2026-2-{code}-00', 'scheduleStatus': 'unrecognized',
            'departments': [department],
            'sourceSchedule': schedule, 'sourceScheduleAliases': [schedule],
            'sourceClassroom': room, 'schedules': [], 'nativePeriodBlocks': [],
            'publicEducationRows': [{'education': {'학/이/실점/론/험': hours}}],
            'remarks': '정규 수업 계획 일정 미생성: published period clock absent: 16',
            'departmentRemarks': {'학과': '정규 수업 계획 일정 미생성: x'}}


class ScnuHeldPeriodsTest(unittest.TestCase):
    def data(self):
        return {'courses': [
            course('GC0656', '수14,15,16', 'A18106'),
            course('XG1128', '월3,4수7 (1주-5주)', 'E50109', '1-1-0'),
            course('AD0718', '화,12/목8,9', 'E70316', '3/2/2'),
            course('KW0001', '광주여자대', '', department='학과'),
            course('KW0002', '', ''),
            course('ED0043', '토11,12', '미배정 강의실', '2/0/15주'),
            course('GJ0002', '광주여자대', '', department=apply_scnu.GJ_DEPARTMENT),
        ]}

    def test_published_periods_are_confirmed_and_untimed_rows_stay(self):
        data = self.data()
        self.assertEqual(len(apply_scnu.apply(data)), 5)
        night, weeks, comma, other, blank, saturday, exchange = data['courses']
        # 16교시 continues the 50-minute night slot: 20:30 to 23:00 on every Wednesday.
        self.assertEqual(night['schedules'][0], {'weekday': 3, 'startMinute': 1230,
                         'endMinute': 1380, 'classroom': 'A18106', 'date': '2026-09-02'})
        self.assertEqual(len(night['schedules']), 13)
        self.assertNotIn('일정 미생성', night['remarks'])
        self.assertTrue(night['remarks'].startswith('정규 수업 계획'))
        self.assertEqual([s['date'] for s in weeks['schedules']][-1], '2026-09-30')
        self.assertEqual({(s['weekday'], s['startMinute'], s['endMinute'])
                          for s in comma['schedules']}, {(2, 540, 660), (4, 960, 1080)})
        # 토11,12 = 토요일 야간1·2 on the 교학규정 제52조 Saturday clock: 13:00~14:40.
        self.assertEqual(saturday['schedules'][0], {'weekday': 6, 'startMinute': 780,
                         'endMinute': 880, 'classroom': '', 'date': '2026-09-05'})
        # Content-based remote exchange courses have no class time.
        self.assertEqual(exchange['scheduleStatus'], 'unscheduled')
        self.assertEqual(exchange['schedules'], [])
        self.assertIn('실시간 수업 시각이 없어', exchange['remarks'])
        self.assertNotIn('일정 미생성', exchange['remarks'])
        for held in (other, blank):
            self.assertEqual(held['scheduleStatus'], 'unrecognized')
            self.assertEqual(held['schedules'], [])

    def test_closed_timetable_section_is_added_once(self):
        row = {'sourceTable': 60, 'sourceContext': ['국어교육과'], 'education': {
            '코드': 'KE0666', '분반': '00', '교과목명': '국어의미론', '이수구분': '전공선택',
            '학/이/실점/론/험': '3/3/0', '강의시간': '화3  목6,7', '담당교수': '송복승',
            '강의실': 'E30301', '학년': '2'}}
        open_row = {**row, 'education': {**row['education'], '코드': 'KE0001'}}
        data = {'courses': [{'courseCode': 'KE0001', 'section': '00'}]}
        added = apply_scnu.add_closed(data, [row, open_row], [{'H': 'KE0666', 'J': '00', 'K': '폐강'}])
        self.assertEqual(added, ['scnu-2026-2-KE0666-00'])
        course = data['courses'][-1]
        self.assertEqual(course['scheduleStatus'], 'scheduled')
        self.assertIn(apply_scnu.CLOSED_LISTED, course['remarks'])
        self.assertEqual(course['schedules'][0], {'weekday': 2, 'startMinute': 660,
                         'endMinute': 720, 'classroom': 'E30301', 'date': '2026-09-01'})
        self.assertEqual(apply_scnu.add_closed(data, [row, open_row], []), [])

    def test_two_official_rows_become_two_meetings(self):
        both = course('XH1028', '월1,2수6', 'A10102')
        both['sourceId'] = 'scnu-2026-2-XH1028-00'
        both['sourceScheduleAliases'] = ['월1,2수6', '월3,4수7']
        both['sourceClassroomAliases'] = ['A10102']
        data = {'courses': [both]}
        self.assertEqual(apply_scnu.apply(data), ['scnu-2026-2-XH1028-00'])
        self.assertEqual({(s['weekday'], s['startMinute'], s['endMinute']) for s in both['schedules']},
                         {(1, 540, 780), (3, 840, 960)})

    def test_shared_code_rows_split_into_two_courses_once(self):
        def row(table_row, name, time, prof, room):
            return {'sourceTable': 35, 'sourceRow': table_row, 'sourceContext': ['창의교양'], 'education': {
                '코드': 'XG1174', '분반': '00', '교과목명': name, '학/이/실점/론/습': '3-3-0',
                '강의시간': time, '담당교수': prof, '강의실': room, '협력학과': '창업지원단'}}
        merged = {'sourceId': apply_scnu.SPLIT_ID, 'courseCode': 'XG1174', 'section': '00',
                  'remarks': apply_scnu.CLOSED_EARLIER,
                  'publicEducationRows': [row(40, '고전', '', '미개설', ''),
                                          row(42, '그린', '월2수6,7', '노양진', 'F10301')]}
        data = {'courses': [merged]}
        self.assertEqual(apply_scnu.split_shared(data), ['scnu-2026-2-XG1174-00-T35R42'])
        self.assertEqual(apply_scnu.split_shared(data), [])
        first, second = data['courses']
        self.assertEqual((first['courseName'], first['scheduleStatus']), ('고전', 'unrecognized'))
        self.assertIn('2026-1 수업시간표', second['remarks'])
        apply_scnu.apply(data)
        self.assertEqual(second['scheduleStatus'], 'scheduled')
        self.assertEqual(first['scheduleStatus'], 'unrecognized')

    def test_rerun_changes_nothing(self):
        data = self.data()
        apply_scnu.apply(data)
        again = copy.deepcopy(data)
        self.assertEqual(apply_scnu.apply(again), [])
        self.assertEqual(again, data)


if __name__ == '__main__':
    unittest.main()
