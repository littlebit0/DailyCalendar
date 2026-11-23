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

    def test_circled_weekday_practice_uses_same_period(self):
        data = self.data()
        data['courses'] += [
            course('e', '화6 7 [공학3-13225],화⑧ ⑨ [공학3-13226(PC실)]', '공학3-13225 / 공학3-13226(PC실)',
                   '원문 원문자 교시(① 등)의 실제 시각 미확인'),
            course('f', '토① ② [집중강의(야외)]', '집중강의(야외)', '원문 원문자 교시(① 등)의 실제 시각 미확인'),
            course('kunsan/unknown/2026/2/104025/12', '목① [해양1-701207]', '해양1-701207',
                   '원문 원문자 교시(① 등)의 실제 시각 미확인'),
        ]
        partial = course('g', '월1 2 ③ ④ [인문관-1244(PC실)]', '인문관-1244(PC실)',
                         '원문 원문자 교시(① 등)의 실제 시각 미확인')
        partial.update(scheduleStatus='scheduled', schedules=[{'weekday': 1}],
                       remarks=partial['remarks'] + '\n부분 시간표: 숫자 교시만 반영했습니다.',
                       sourceEducation={'projection': 'publishedRegularTimetablePartial',
                                        'unresolvedSourcePeriodScope': []})
        data['courses'].append(partial)
        apply_kunsan.apply(data)
        self.assertEqual(apply_kunsan.apply_circled(data), ['c', 'e', 'g'])
        by = {c['sourceId']: c for c in data['courses']}
        # 원문자 ①②는 1·2교시(09:10~11:10). 강의실이 다르면 이어지는 교시라도 합치지 않는다.
        self.assertEqual(by['c']['schedules'][0]['startMinute'], 550)
        self.assertEqual(by['c']['schedules'][0]['endMinute'], 670)
        self.assertEqual({(m['startMinute'], m['endMinute'], m['classroom']) for m in by['e']['schedules']},
                         {(850, 970, '공학3-13225'), (970, 1090, '공학3-13226(PC실)')})
        self.assertEqual({(m['startMinute'], m['endMinute']) for m in by['g']['schedules']}, {(550, 790)})
        self.assertNotIn('부분 시간표', by['g']['remarks'])
        self.assertNotIn('원문자 교시(① 등)', by['c']['remarks'])
        self.assertNotIn('unresolvedSourcePeriodScope', by['g']['sourceEducation'])
        # 토요일 원문자(과목별 자리표시)와 이론·실습 0시수 강좌는 보류.
        for sid in ('f', 'kunsan/unknown/2026/2/104025/12'):
            self.assertEqual(by[sid]['scheduleStatus'], 'unrecognized')
        self.assertEqual(apply_kunsan.apply_circled(data), [])

    def test_saturday_circled_confirms_unless_zero_hour_mismatch_or_shared_slot(self):
        def sat(sid, code, schedule, room):
            c = course(sid, schedule, room, '원문 원문자 교시(① 등)의 실제 시각 미확인')
            c['courseCode'] = code
            return c
        data = {'counts': {}, 'courses': [
            sat('lesson', '109430', '토② [음악관-10108]', '음악관-10108'),
            sat('shared1', '109430', '토① [음악관-10107]', '음악관-10107'),
            sat('shared2', '102966', '토① [음악관-10107]', '음악관-10107'),
            sat('field', '104025', '토① [공학3-13103]', '공학3-13103'),
            sat('ski', '101765', '토① ② [집중강의(야외)]', '집중강의(야외)'),
            sat('kunsan/unknown/2026/2/110404/12', '110404', '토① ② ④ ⑤ [음악관-10111]', '음악관-10111'),
            course('jst', '', '', 'JST 공개 목록에 실제 시간표·담당교원 미게시'),
        ]}
        self.assertEqual(apply_kunsan.apply_saturday([data]), ['lesson'])
        by = {c['sourceId']: c for c in data['courses']}
        self.assertEqual({(m['weekday'], m['startMinute'], m['endMinute']) for m in by['lesson']['schedules']},
                         {(6, 610, 670)})
        self.assertEqual(len(by['lesson']['schedules']), len(apply_kunsan.DATES[6]))
        self.assertEqual(apply_kunsan.apply_untimed(data), ['field', 'ski', 'jst'])
        self.assertIn('동기방학 집중 실습', by['field']['remarks'])
        self.assertIn('12월 집중강의', by['ski']['remarks'])
        for sid in ('shared1', 'shared2', 'kunsan/unknown/2026/2/110404/12'):
            self.assertEqual(by[sid]['scheduleStatus'], 'unrecognized')
        self.assertEqual(data['counts'], {'scheduled': 1, 'unrecognized': 3, 'unscheduled': 3})
        self.assertEqual(apply_kunsan.apply_saturday([data]), [])
        self.assertEqual(apply_kunsan.apply_untimed(data), [])

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
