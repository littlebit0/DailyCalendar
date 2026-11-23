import copy
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    'apply_hanbat', ROOT / 'tool/timetable/apply_hanbat_held_periods.py')
apply_hanbat = importlib.util.module_from_spec(spec)
spec.loader.exec_module(apply_hanbat)


def course(sid, schedule, room, reason):
    return {'sourceId': sid, 'sourceSchedule': schedule, 'sourceClassroom': room,
            'scheduleStatus': 'unrecognized', 'schedules': [],
            'remarks': '원문 비고' + apply_hanbat.HELD_PREFIX + reason,
            'metadata': {'heldReason': reason}}


class HanbatHeldPeriodsTest(unittest.TestCase):
    def data(self):
        return {'courses': [
            course('a', '월13,14', '생활체육관(B101)', '공식 시각 범위 밖 교시'),
            course('b', 'None', '', '개별 강의실 미확인'),
            course('c', '화13,14,15', '그린에너지관(609)', '공식 시각 범위 밖 교시'),
            course('d', '수1,수2.5', '기계관(501),기계관(501)', '분수 교시 실제 시작·종료 시각 미확인'),
        ]}

    def test_extends_slot_and_keeps_courses_without_clock(self):
        data = self.data()
        self.assertEqual(apply_hanbat.apply(data), ['a'])
        a, b, c, d = data['courses']
        self.assertEqual(a['scheduleStatus'], 'scheduled')
        # 13교시 21:30 시작, 14교시는 55분 슬롯으로 이어 23:20까지, 한 구간으로 합침.
        self.assertEqual(a['schedules'][0], {'weekday': 1, 'startMinute': 1290, 'endMinute': 1400,
                                             'classroom': '생활체육관(B101)', 'date': '2026-09-07'})
        self.assertNotIn('2026-10-05', [m['date'] for m in a['schedules']])
        self.assertTrue(a['remarks'].startswith('원문 비고 공식 요일·교시로 정규 예약'))
        self.assertEqual(a['metadata']['heldReason'], '')
        for held in (b, c, d):
            self.assertEqual(held['scheduleStatus'], 'unrecognized')
            self.assertEqual(held['schedules'], [])

    def test_rerun_changes_nothing(self):
        data = self.data()
        apply_hanbat.apply(data)
        again = copy.deepcopy(data)
        self.assertEqual(apply_hanbat.apply(again), [])
        self.assertEqual(again, data)


if __name__ == '__main__':
    unittest.main()
