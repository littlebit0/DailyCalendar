import copy
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    'apply_kunsan', ROOT / 'tool/timetable/apply_kunsan_held_periods.py')
apply_kunsan = importlib.util.module_from_spec(spec)
spec.loader.exec_module(apply_kunsan)

BASE = '학교가 2026년 7월 23일 공시한 정규 수업 계획입니다.'


def course(sid, schedule, room, reason):
    return {'sourceId': sid, 'courseCode': sid, 'section': '01', 'sourceSchedule': schedule,
            'sourceClassroom': room, 'scheduleStatus': 'unrecognized', 'schedules': [],
            'remarks': f'비고: 합반 / {reason}\n{BASE}', 'departmentRemarks': {},
            'sourceEducation': {'projection': 'unresolvedSourcePreserved'}}


class KunsanHeldPeriodsTest(unittest.TestCase):
    def data(self):
        return {'counts': {}, 'individualBlocked': [], 'courses': [
            course('a', '월11 12 13 [원격강의]', '원격강의', '원격·혼합 운영의 실제 동시 출석 방식 미확인'),
            course('b', '수4,금3 4 [원격강의]', '원격강의', '원격·혼합 운영의 실제 동시 출석 방식 미확인'),
            course('c', '월① ② [캠퍼스관-308]', '캠퍼스관-308', '원문 원문자 교시(① 등)의 실제 시각 미확인'),
            course('d', '', '', 'JST 공개 목록에 실제 시간표·담당교원 미게시'),
        ]}

    def test_confirms_numeric_periods_and_keeps_circled_and_empty(self):
        data = self.data()
        self.assertEqual(apply_kunsan.apply(data), ['a', 'b'])
        a, b, c, d = data['courses']
        self.assertEqual(a['scheduleStatus'], 'scheduled')
        # 11~13교시는 1~10교시와 같은 60분 슬롯으로 이어 19:10~22:10.
        self.assertEqual(a['schedules'][0], {'weekday': 1, 'startMinute': 1150, 'endMinute': 1330,
                                             'classroom': '원격강의', 'date': '2026-08-31',
                                             'deliveryMode': 'inPerson'})
        self.assertEqual(len(a['schedules']), 13)
        self.assertTrue(a['remarks'].startswith('비고: 합반\n' + BASE))
        self.assertIn('19:10', a['remarks'])
        # 금요일 수업은 12/8(화)·12/9(수) 보강일에 이어진다.
        friday = [s['date'] for s in b['schedules'] if s['startMinute'] == 670 and s['weekday'] != 3]
        self.assertEqual(friday[-2:], ['2026-12-04', '2026-12-08'])
        self.assertIn({'weekday': 3, 'startMinute': 670, 'endMinute': 790, 'classroom': '원격강의',
                       'date': '2026-12-09', 'deliveryMode': 'inPerson'}, b['schedules'])
        self.assertEqual(data['counts'], {'scheduled': 2, 'unrecognized': 2, 'unscheduled': 0})
        for held in (c, d):
            self.assertEqual(held['scheduleStatus'], 'unrecognized')
            self.assertEqual(held['schedules'], [])

    def test_saturday_skips_holidays(self):
        self.assertNotIn('2026-09-26', apply_kunsan.DATES[6])
        self.assertNotIn('2026-10-03', apply_kunsan.DATES[6])
        self.assertEqual(len(apply_kunsan.DATES[6]), 12)

    def test_rerun_changes_nothing(self):
        data = self.data()
        apply_kunsan.apply(data)
        again = copy.deepcopy(data)
        self.assertEqual(apply_kunsan.apply(again), [])
        self.assertEqual(again, data)


if __name__ == '__main__':
    unittest.main()
