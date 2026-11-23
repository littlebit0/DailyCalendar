import copy
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    'apply_kookmin', ROOT / 'tool/timetable/apply_kookmin_held_periods.py')
apply_kookmin = importlib.util.module_from_spec(spec)
spec.loader.exec_module(apply_kookmin)


def course(code, section, schedule, room, status='unrecognized'):
    return {'sourceId': f'kookmin/main/2026/2/{code}/{section}', 'courseCode': code,
            'section': section, 'sourceSchedule': schedule, 'sourceClassroom': room,
            'scheduleStatus': status, 'schedules': [],
            'departmentRemarks': {'학과': '혼합수업\n' + apply_kookmin.BLOCK_NOTE}}


class KookminHeldPeriodsTest(unittest.TestCase):
    def data(self):
        return {'courses': [
            course('0160508', '51', '화요일 18:00~18:50\n화요일 18:55~19:45', '법학관3층2호실'),
            course('1659202', '51', '수요일 18:00~18:50', '법학관2층4호실'),
            course('0294104', '01', '일요일 08:00~10:00', ''),
        ]}

    def test_published_clocks_are_confirmed_as_is(self):
        data = self.data()
        self.assertEqual(apply_kookmin.apply(data), ['0160508-51', '0294104-01'])
        law, contradicted, sunday = data['courses']
        self.assertEqual(law['scheduleStatus'], 'scheduled')
        # A 5-minute gap is not merged, like import_kookmin.meetings_for.
        self.assertEqual(law['schedules'], [
            {'weekday': 2, 'startMinute': 1080, 'endMinute': 1130, 'classroom': '법학관3층2호실'},
            {'weekday': 2, 'startMinute': 1135, 'endMinute': 1185, 'classroom': '법학관3층2호실'}])
        self.assertEqual(law['departmentRemarks']['학과'],
                         '혼합수업\n' + apply_kookmin.CONFIRMED_NOTE)
        self.assertEqual(sunday['schedules'],
                         [{'weekday': 7, 'startMinute': 480, 'endMinute': 600, 'classroom': ''}])
        self.assertEqual(contradicted['scheduleStatus'], 'unrecognized')
        self.assertEqual(contradicted['schedules'], [])

    def test_closed_published_row_is_added_once_and_open_rows_are_not(self):
        fixture = __import__('json').loads(
            (ROOT / 'tool/tests/fixtures/kookmin-real-rows.json').read_text())
        courses = apply_kookmin.closed_courses(fixture['rows'], fixture['dictionary'])
        self.assertEqual([c['courseCode'] for c in courses], ['1655101'])
        self.assertIn(apply_kookmin.CLOSED_NOTE,
                      next(iter(courses[0]['departmentRemarks'].values())))
        data = {'courses': []}
        self.assertEqual(len(apply_kookmin.add_closed(data, courses)), 1)
        self.assertEqual(apply_kookmin.add_closed(data, courses), [])

    def test_rerun_changes_nothing(self):
        data = self.data()
        apply_kookmin.apply(data)
        again = copy.deepcopy(data)
        self.assertEqual(apply_kookmin.apply(again), [])
        self.assertEqual(again, data)


if __name__ == '__main__':
    unittest.main()
