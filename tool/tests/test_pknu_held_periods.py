import copy
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    'apply_pknu', ROOT / 'tool/timetable/apply_pknu_held_periods.py')
apply_pknu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(apply_pknu)


def course(code, schedule, room, unit, scheme='3-3-0', campus='대연캠퍼스'):
    remark = ('원문 비고. ' + apply_pknu.HELD + 'current remote/mixed method actual per-period '
              'operation unresolved 캠퍼스; ' + apply_pknu.STALE_TT)
    return {'sourceId': f'pknu-2026-2-{code}', 'courseCode': code.split('-')[0],
            'section': code.split('-')[1], 'sourceSchedule': schedule, 'sourceClassroom': room,
            'scheduleStatus': 'unrecognized', 'schedules': [],
            'sourceNativePeriods': apply_pknu.native_periods(schedule),
            'sourceSnapshotMinuteUnit': unit, 'sourceCurrentEducation': {'PNT_THEO_PRAC': scheme},
            'sourceSnapshotCampus': campus,
            'remarks': remark, 'departmentRemarks': {'학과': remark}}


class PknuHeldPeriodsTest(unittest.TestCase):
    def data(self):
        return {'courses': [
            course('112671-101', '화5 목5', 'C23-312', '75'),
            course('100000-101', '', '', ''),
            course('100763-101', '월3 수2', 'C25-1', '75'),  # 2차: 75분을 월·수에도 적용
            course('102854-101', '화7,8 수8', 'A , B', '50'),  # 7/30 이후 교시 변경, 시수로 50분
            course('113093-101', '', '', '50'),  # 2차: 7/30 개설표 교시·강의실
            course('K00003-901', '', '', '', campus='가상캠퍼스'),  # 2차: KCU 원격 → 시간 미정
            course('112636-101', '', '', ''),  # 2차: 현장실습 → 시간 미정
            course('100001-101', '', '', '50', campus='가상캠퍼스'),  # 근거 없음 → 그대로
        ]}

    def test_official_periods_confirmed_and_others_kept(self):
        data = self.data()
        self.assertEqual(apply_pknu.apply(data), [
            'pknu-2026-2-112671-101', 'pknu-2026-2-100763-101', 'pknu-2026-2-102854-101',
            'pknu-2026-2-113093-101', 'pknu-2026-2-K00003-901', 'pknu-2026-2-112636-101'])
        tt, empty, monwed, changed, july, kcu, practice, unknown = data['courses']
        self.assertEqual(tt['schedules'][0], {
            'weekday': 2, 'startMinute': 900, 'endMinute': 990, 'classroom': 'C23-312',
            'sourcePeriod': 5, 'sourceMinuteUnit': 75, 'date': '2026-09-01'})
        self.assertNotIn('2026-10-05', [m['date'] for m in tt['schedules']])
        self.assertNotIn(apply_pknu.STALE_TT, tt['remarks'])
        self.assertIn(apply_pknu.CONFIRMED, tt['departmentRemarks']['학과'])
        # 여러 강의실은 교시별 대응이 없어 비우고, 화7·8은 한 구간으로 합친다.
        self.assertEqual(changed['schedules'][0], {
            'weekday': 2, 'startMinute': 900, 'endMinute': 1020, 'classroom': '',
            'sourcePeriod': 7, 'sourceMinuteUnit': 50, 'date': '2026-09-01'})
        # 월3 = 75분 3교시 12:00~13:15(슬롯 13:30), 9/2 수2 = 10:30~11:45.
        self.assertEqual(monwed['schedules'][0]['startMinute'], 630)
        self.assertEqual((monwed['schedules'][1]['startMinute'], monwed['schedules'][1]['endMinute']),
                         (720, 810))
        # 금5(C21-335C)와 금6~8(C21-128)은 강의실이 달라 나눈다.
        self.assertEqual([(m['startMinute'], m['endMinute'], m['classroom'])
                          for m in july['schedules'][:2]],
                         [(780, 840, 'C21-335C'), (840, 1020, 'C21-128')])
        for no_clock in (kcu, practice):
            self.assertEqual(no_clock['scheduleStatus'], 'unscheduled')
            self.assertEqual(no_clock['schedules'], [])
        for held in (empty, unknown):
            self.assertEqual(held['scheduleStatus'], 'unrecognized')
            self.assertEqual(held['schedules'], [])

    def test_english_header_is_parsed(self):
        self.assertEqual(apply_pknu.native_periods('Tue.6,7 Thu.6'), [
            {'weekday': 2, 'period': 6}, {'weekday': 2, 'period': 7}, {'weekday': 4, 'period': 6}])

    def test_rerun_changes_nothing(self):
        data = self.data()
        apply_pknu.apply(data)
        again = copy.deepcopy(data)
        self.assertEqual(apply_pknu.apply(again), [])
        self.assertEqual(again, data)


if __name__ == '__main__':
    unittest.main()
