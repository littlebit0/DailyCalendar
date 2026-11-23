import copy
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    'apply_hanbat', ROOT / 'tool/timetable/apply_hanbat_held_periods.py')
apply_hanbat = importlib.util.module_from_spec(spec)
spec.loader.exec_module(apply_hanbat)


def course(sid, schedule, room, reason, name='과목', dept='학과'):
    return {'sourceId': sid, 'sourceSchedule': schedule, 'sourceClassroom': room,
            'courseName': name,
            'scheduleStatus': 'unrecognized', 'schedules': [],
            'remarks': '원문 비고' + apply_hanbat.HELD_PREFIX + reason,
            'metadata': {'heldReason': reason,
                         'originalEducationalFields': {'openingDepartment': dept}}}


class HanbatHeldPeriodsTest(unittest.TestCase):
    def data(self):
        return {'courses': [
            course('a', '월13,14', '생활체육관(B101)', '공식 시각 범위 밖 교시'),
            course('b', 'None', '', '개별 강의실 미확인'),
            course('c', '화13,14,15', '그린에너지관(609)', '공식 시각 범위 밖 교시'),
            course('d', '수1,수2.5', '기계관(501),기계관(501)', '분수 교시 실제 시작·종료 시각 미확인'),
            course('e', 'None', '', '개별 강의실 미확인', '모두의 인공지능', '노마드칼리지'),
            course('f', '화14,15', '', '개별 강의실 미확인', '인문학의 향기', '교무처'),
        ]}

    def test_extends_slot_and_keeps_courses_without_clock(self):
        data = self.data()
        self.assertEqual(apply_hanbat.apply(data), ['a', 'b', 'c', 'd', 'e', 'f'])
        a, b, c, d, e, f = data['courses']
        self.assertEqual(a['scheduleStatus'], 'scheduled')
        # 13교시 21:30 시작, 14교시는 55분 슬롯으로 이어 23:20까지, 한 구간으로 합침.
        self.assertEqual(a['schedules'][0], {'weekday': 1, 'startMinute': 1290, 'endMinute': 1400,
                                             'classroom': '생활체육관(B101)', 'date': '2026-09-07'})
        self.assertNotIn('2026-10-05', [m['date'] for m in a['schedules']])
        self.assertTrue(a['remarks'].startswith('원문 비고 공식 요일·교시로 정규 예약'))
        self.assertEqual(a['metadata']['heldReason'], '')
        # 15교시는 학과 공표 시간표대로 자정을 넘어 다음 날 00:00~00:15로 나눈다.
        self.assertEqual(c['schedules'][:2], [
            {'weekday': 2, 'startMinute': 1290, 'endMinute': 1440,
             'classroom': '그린에너지관(609)', 'date': '2026-09-01'},
            {'weekday': 3, 'startMinute': 0, 'endMinute': 15,
             'classroom': '그린에너지관(609)', 'date': '2026-09-02'}])
        for online in (e, f):  # 학교가 실시간 시각이 없다고 밝힌 온라인 강좌
            self.assertEqual(online['scheduleStatus'], 'unscheduled')
            self.assertEqual(online['schedules'], [])
        # 반교시 2.5 = 2교시 슬롯 끝 직후 30분(11:00~11:30), 1교시와 간격 60분이라 나눈다.
        self.assertEqual([(m['startMinute'], m['endMinute']) for m in d['schedules'][:2]],
                         [(540, 600), (660, 690)])
        # 원문 요일·교시가 없는 나머지 강좌도 시간 미정(2026-11-23 사용자 결정).
        self.assertEqual((b['scheduleStatus'], b['schedules']), ('unscheduled', []))
        self.assertIn('공식 개설표에 요일·교시가 없음', b['remarks'])

    def test_rerun_changes_nothing(self):
        data = self.data()
        apply_hanbat.apply(data)
        again = copy.deepcopy(data)
        self.assertEqual(apply_hanbat.apply(again), [])
        self.assertEqual(again, data)


if __name__ == '__main__':
    unittest.main()
