import copy
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    'apply_changwon', ROOT / 'tool/timetable/apply_changwon_held_periods.py')
apply_changwon = importlib.util.module_from_spec(spec)
spec.loader.exec_module(apply_changwon)


def course(sid, schedule, reasons):
    remark = '원문 비고 15AB는추정하지 않았습니다.' + apply_changwon.HELD_PREFIX + '; '.join(reasons)
    return {'sourceId': sid, 'sourceSchedule': schedule, 'scheduleStatus': 'unrecognized',
            'schedules': [], 'period': {}, 'remarks': remark, 'departmentRemarks': {'학과': remark},
            'sourceEducation': {'currentPublicPlanFields': {'시험일시': '~'},
                                'regularReservationReview': {'kind': 'held', 'holdReasons': reasons}}}


class ChangwonHeldPeriodsTest(unittest.TestCase):
    def data(self):
        return {'courses': [
            course('a', '목10A(99999),목10B,목11A,목11B,목12A,목12B,',
                   ['native remote/mixed operation, individual weekly session mapping unknown']),
            course('b', '', ['no weekly period']),
        ]}

    def test_confirms_official_periods_and_keeps_rows_without_time(self):
        data = self.data()
        self.assertEqual(apply_changwon.apply(data), ['a'])
        a, b = data['courses']
        self.assertEqual(a['scheduleStatus'], 'scheduled')
        self.assertEqual(a['schedules'][0], {'weekday': 4, 'startMinute': 1100, 'endMinute': 1250,
                                             'classroom': '99999', 'date': '2026-09-03'})
        self.assertEqual(a['sourceEducation']['regularReservationReview']['holdReasons'], [])
        self.assertTrue(a['remarks'].startswith('원문 비고 15AB는추정하지 않았습니다. 공식 요일·교시'))
        self.assertEqual(a['departmentRemarks']['학과'], a['remarks'])
        self.assertEqual(b['scheduleStatus'], 'unrecognized')
        self.assertEqual(b['schedules'], [])

    def test_rerun_changes_nothing(self):
        data = self.data()
        apply_changwon.apply(data)
        again = copy.deepcopy(data)
        self.assertEqual(apply_changwon.apply(again), [])
        self.assertEqual(again, data)


if __name__ == '__main__':
    unittest.main()
