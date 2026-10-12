import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('sejong', Path(__file__).parents[1]/'timetable'/'import_sejong.py')
sejong = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sejong)


class SejongImportTest(unittest.TestCase):
    def test_rooms_follow_published_days_and_groups(self):
        slots = sejong.meetings('월 09:00~11:00, 화 목 09:00~10:30', '호302, 센B205')
        self.assertEqual([(s['weekday'], s['classroom']) for s in slots], [(1, '호302'), (2, '센B205'), (4, '센B205')])
        slots = sejong.meetings('화 09:00~11:00, 수 금 09:00~10:30', '호302, 센B205, 영601')
        self.assertEqual([(s['weekday'], s['classroom']) for s in slots], [(2, '호302'), (3, '센B205'), (5, '영601')])

    def test_bad_times_and_ambiguous_rooms_fail(self):
        for schedule, rooms in [('월 09:80~11:00', '집1'), ('월 12:00~11:00', '집1'), ('화 목 09:00~10:30', '1,2,3')]:
            with self.assertRaises(ValueError):
                sejong.meetings(schedule, rooms)
        self.assertEqual(sejong.meetings('', ''), [])

    def test_department_scoped_sections_do_not_collapse(self):
        def row(number, dept, schedule):
            r = [None]*24
            r[:10] = [number, '유형2', dept, '학과'+dept, '011839', '001', '세종인을위한전공탐색', '공통교양필수', '1', '1.0']
            r[14], r[15], r[16], r[18] = schedule, '집408', '교수', '타학과 수강불가'
            return r
        rows = [sejong.HEADER, row(1, '3611', '화 18:00~19:00'), row(2, '3614', '월 19:00~20:00')]
        courses = sejong.parse_rows(rows, 2026, '2', 2)
        self.assertEqual(len({c['sourceId'] for c in courses}), 2)
        self.assertEqual(courses[0]['courseCode'], courses[1]['courseCode'])
        self.assertIn('타학과 수강불가', courses[0]['departmentRemarks']['학과3611'])
        with self.assertRaises(ValueError):
            sejong.parse_rows(rows[:-1], 2026, '2', 2)


if __name__ == '__main__':
    unittest.main()
