import copy
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    'apply_scnu', ROOT / 'tool/timetable/apply_scnu_held_periods.py')
apply_scnu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(apply_scnu)


def course(code, schedule, room, hours='3/3/0'):
    return {'sourceId': f'scnu-2026-2-{code}-00', 'scheduleStatus': 'unrecognized',
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
            course('KW0001', '광주여자대', ''),
            course('KW0002', '', ''),
        ]}

    def test_published_periods_are_confirmed_and_untimed_rows_stay(self):
        data = self.data()
        self.assertEqual(len(apply_scnu.apply(data)), 3)
        night, weeks, comma, other, blank = data['courses']
        # 16교시 continues the 50-minute night slot: 20:30 to 23:00 on every Wednesday.
        self.assertEqual(night['schedules'][0], {'weekday': 3, 'startMinute': 1230,
                         'endMinute': 1380, 'classroom': 'A18106', 'date': '2026-09-02'})
        self.assertEqual(len(night['schedules']), 13)
        self.assertNotIn('일정 미생성', night['remarks'])
        self.assertTrue(night['remarks'].startswith('정규 수업 계획'))
        self.assertEqual([s['date'] for s in weeks['schedules']][-1], '2026-09-30')
        self.assertEqual({(s['weekday'], s['startMinute'], s['endMinute'])
                          for s in comma['schedules']}, {(2, 540, 660), (4, 960, 1080)})
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

    def test_rerun_changes_nothing(self):
        data = self.data()
        apply_scnu.apply(data)
        again = copy.deepcopy(data)
        self.assertEqual(apply_scnu.apply(again), [])
        self.assertEqual(again, data)


if __name__ == '__main__':
    unittest.main()
