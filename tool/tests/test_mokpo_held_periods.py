import copy
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    'apply_mokpo', ROOT / 'tool/timetable/apply_mokpo_held_periods.py')
apply_mokpo = importlib.util.module_from_spec(spec)
spec.loader.exec_module(apply_mokpo)


def course(sid, schedule, remark):
    return {'sourceId': sid, 'sourceSchedule': schedule, 'sourceClassroom': '인문대학 351',
            'scheduleStatus': 'unrecognized', 'schedules': [],
            'departmentRemarks': {'국어국문학과': remark}}


class MokpoHeldPeriodsTest(unittest.TestCase):
    def data(self):
        return {'courses': [
            course('a', '월10,11,12 수13,14,15',
                   '원 이수구분: 0005 전공선택. \n운영 검토: Additional literal reference.'),
            course('b', '', '원 이수구분: 0005 전공선택. 미개설'),
        ]}

    def test_confirms_official_periods_and_keeps_rows_without_time(self):
        data = self.data()
        self.assertEqual(apply_mokpo.apply(data), ['a'])
        a, b = data['courses']
        self.assertEqual(a['scheduleStatus'], 'scheduled')
        self.assertEqual(a['schedules'][:2], [
            {'weekday': 3, 'startMinute': 900, 'endMinute': 990, 'date': '2026-09-02',
             'classroom': '인문대학 351'},
            {'weekday': 1, 'startMinute': 810, 'endMinute': 900, 'date': '2026-09-07',
             'classroom': '인문대학 351'}])
        self.assertEqual(len(a['schedules']), 13 + 14)
        self.assertNotIn('Additional', a['departmentRemarks']['국어국문학과'])
        self.assertIn('정규 예약', a['departmentRemarks']['국어국문학과'])
        self.assertEqual(b['scheduleStatus'], 'unrecognized')
        self.assertEqual(b['schedules'], [])

    def test_late_periods_continue_thirty_minute_slots(self):
        self.assertEqual(apply_mokpo.blocks('목25,26,27,28,29,30'), [(4, 1260, 1440)])

    def test_restores_source_rows_and_renamed_code_once(self):
        old = {'sourceId': 'mokpo/dorim/2026/2/KG631/00', 'campus': 'dorim', 'courseCode': 'KG631',
               'section': '00', 'sourceDepartmentCode': '413'}
        datasets = [{'campus': c, 'courses': [{'sourceDepartmentCode': '893', 'courseCode': 'Z',
                                               'section': c}]} for c in ('damyang', 'dorim', 'unknown')]
        datasets[1]['courses'].append(old)
        added = apply_mokpo.restore_source_rows(datasets)
        self.assertEqual(len(added), 10)
        self.assertEqual(old['sourceId'], 'mokpo/dorim/2026/2/KG721/00')
        z09 = datasets[0]['courses'][1]
        self.assertEqual((z09['sourceId'], z09['scheduleStatus']), ('mokpo/damyang/2026/2/ZAA006/09', 'unrecognized'))
        self.assertEqual(sum(len(d['courses']) for d in datasets), 3 + 1 + 9)
        self.assertEqual(apply_mokpo.restore_source_rows(datasets), [])

    def test_supplement_fills_blank_unco_time_from_official_timetable_once(self):
        z = {'sourceId': 'z', 'courseCode': 'ZZA002', 'section': '00', 'sourceSchedule': '',
             'sourceClassroom': '', 'scheduleStatus': 'unrecognized', 'schedules': [],
             'departmentRemarks': {'학생지원과': '원 이수구분: 0006 일반선택. \n운영 검토: Actual clock absent.'}}
        blank = dict(z, sourceId='y', courseCode='ZZA006', departmentRemarks={'x': ''})
        data = {'courses': [z, blank]}
        self.assertEqual(apply_mokpo.apply_supplement(data), ['z'])
        self.assertEqual(z['schedules'][0], {'weekday': 5, 'startMinute': 900, 'endMinute': 1080,
                                             'date': '2026-09-04', 'classroom': '미정'})
        self.assertEqual(z['sourceSchedule'], '')
        self.assertNotIn('운영 검토', z['departmentRemarks']['학생지원과'])
        self.assertEqual(blank['scheduleStatus'], 'unrecognized')
        self.assertEqual(apply_mokpo.apply_supplement(data), [])

    def test_rerun_changes_nothing(self):
        data = self.data()
        apply_mokpo.apply(data)
        again = copy.deepcopy(data)
        self.assertEqual(apply_mokpo.apply(again), [])
        self.assertEqual(again, data)


if __name__ == '__main__':
    unittest.main()
