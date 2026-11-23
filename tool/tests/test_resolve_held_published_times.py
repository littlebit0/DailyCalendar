import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    'resolve_held', Path(__file__).parents[1] / 'timetable/resolve_held_published_times.py',
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def cnu_course(**edu):
    fields = {'LSN_METHOD_CD_NM': None, 'CLOSE_YN': '0', 'CNCL_LT_YN': None}
    fields.update(edu.pop('fields', {}))
    return {
        'sourceId': 'cnu/unknown/2026-2/1000-0000-00',
        'scheduleStatus': 'unrecognized',
        'departmentRemarks': {'학과': module.CNU_HOLD},
        'sourceEducation': {
            'originalEducationFields': fields,
            'registrationStatus': 'activeBlocked',
            'individualReviewStatus': 'wholeSemanticReviewPending',
            'actualDisplayedClocks': [
                {'weekday': 4, 'startMinute': 630, 'endMinute': 720, 'location': '교301'},
            ],
            **edu,
        },
    }


def hufs_course(src, remark=''):
    return {
        'sourceId': 'hufs/seoul/2026/2/X000000/01',
        'scheduleStatus': 'unrecognized',
        'sourceSchedule': src,
        'period': {'startDate': '2026-09-01', 'endDate': '2026-12-21'},
        'departmentRemarks': {'학과': remark + module.HUFS_HOLD},
    }


class UntimedTest(unittest.TestCase):
    def test_no_published_time_is_untimed(self):
        for src in ('', '시간미지정강좌', '시간미지정강좌,시간미지정강좌'):
            self.assertTrue(module.untimed({'sourceId': 'hanyang/x', 'sourceSchedule': src}), src)

    def test_partial_rows_stay_timed_and_closed_rows_are_not_judged(self):
        self.assertFalse(module.untimed({'sourceId': 'hanyang/x', 'sourceSchedule': '화(09:00-10:00),시간미지정강좌'}))
        # 2026-11-23 사용자 결정: 폐강 표기는 판단하지 않는다.
        self.assertTrue(module.untimed({
            'sourceId': 'cnu/x', 'sourceSchedule': '',
            'departmentRemarks': {'학과': '현재 폐강된 강좌입니다.'},
        }))
        self.assertTrue(module.untimed({'sourceId': 'hanyang/x', 'sourceSchedule': '집중수업'}))

    def test_koreatech_zero_hours_except_conflicting_row(self):
        self.assertTrue(module.untimed({'sourceId': 'koreatech/unknown/2026-2/CHA831-01', 'sourceSchedule': '0'}))
        self.assertFalse(module.untimed({'sourceId': 'koreatech/unknown/2026-2/MEC367-03', 'sourceSchedule': '0'}))
        self.assertFalse(module.untimed({'sourceId': 'hoseo/x', 'sourceSchedule': '0'}))


class CnuTest(unittest.TestCase):
    def test_published_clock_becomes_dated_weekly_plan(self):
        course = cnu_course()
        meetings = module.cnu_meetings(course)
        dates = [m['date'] for m in meetings]
        self.assertEqual(course['period'], {'startDate': '2026-09-01', 'endDate': '2026-12-18'})
        self.assertEqual(dates[0], '2026-09-03')
        self.assertEqual(dates[-1], '2026-12-17')
        self.assertNotIn('2026-09-24', dates)  # 추석
        self.assertNotIn('2026-12-10', dates)  # 12/8~11 보충기간
        self.assertTrue(all((m['startMinute'], m['endMinute'], m['classroom']) == (630, 720, '교301') for m in meetings))

    def test_operating_mode_review_and_closure_do_not_block_a_published_clock(self):
        for course in (
            cnu_course(fields={'LSN_METHOD_CD_NM': '혼합'}),
            cnu_course(fields={'CLOSE_YN': '1'}),
            cnu_course(registrationStatus='blockedIndividualFieldOperationUnresolved',
                       fieldOperationReview={'fieldClockRoomIndividuallyConfirmed': False}),
            cnu_course(individualReviewStatus='currentPublicPlanAbsent'),
        ):
            self.assertTrue(module.cnu_meetings(course))
        self.assertIsNone(module.cnu_meetings(cnu_course(actualDisplayedClocks=[])))


class HufsTest(unittest.TestCase):
    def test_periods_use_official_slots_and_existing_date_rule(self):
        meetings = module.hufs_meetings(hufs_course('금 5 6 (1205)'))
        dates = [m['date'] for m in meetings]
        self.assertTrue(all((m['weekday'], m['startMinute'], m['endMinute']) == (5, 780, 900) for m in meetings))
        self.assertNotIn('2026-09-25', dates)
        self.assertNotIn('2026-10-09', dates)
        self.assertEqual(dates[-1], '2026-12-04')  # regular dates end Dec 7

    def test_mode_notes_do_not_block_and_period_13_continues_the_table(self):
        self.assertTrue(module.hufs_meetings(hufs_course('월 1 2 (1203)', '비대면 · ')))
        meetings = module.hufs_meetings(hufs_course('월 12 13 (1203)'))
        self.assertEqual({(m['startMinute'], m['endMinute']) for m in meetings}, {(1200, 1320)})
        self.assertIsNone(module.hufs_meetings(hufs_course('월 13 14 (1203)')))
        self.assertIsNone(module.hufs_meetings(hufs_course('')))


def scheduled(dates, weekday, **extra):
    return {'sourceId': 'x/s', 'scheduleStatus': 'scheduled', **extra,
            'schedules': [{'weekday': weekday, 'startMinute': 540, 'endMinute': 600, 'classroom': '', 'date': d}
                          for d in dates]}


class DateRuleTest(unittest.TestCase):
    def test_copies_existing_weekday_dates_and_fills_weekends(self):
        mondays = ['2026-09-07', '2026-09-14', '2026-09-28']  # 9/21 휴업
        fridays = ['2026-09-04', '2026-09-11', '2026-09-18', '2026-10-02']  # 9/25 공휴일
        data = {'courses': [scheduled(mondays, 1), scheduled(fridays, 5)]}
        rule, _ = module.date_rule(data)
        self.assertEqual(rule[1], mondays)
        self.assertEqual(rule[5], fridays)
        self.assertEqual(rule[6], ['2026-09-05', '2026-09-12', '2026-09-19'])  # 9/26·10/3 공휴일
        self.assertNotIn('2026-09-26', rule[6])

    def test_weekend_never_passes_the_last_scheduled_class_day(self):
        # 금요일 12/18이 마지막 수업일이면 12/19·20 주말을 만들지 않는다(호서 학기종료일 12/18).
        fridays = ['2026-12-04', '2026-12-11', '2026-12-18']
        rule, _ = module.date_rule({'courses': [scheduled(fridays, 5)]})
        self.assertEqual(rule[6][-1], '2026-12-12')
        self.assertEqual(rule[7][-1], '2026-12-13')

    def test_weekend_between_two_closed_weekdays_is_skipped(self):
        fridays = ['2026-10-16', '2026-10-30']  # 10/23 시험 주간
        mondays = ['2026-10-19', '2026-11-02']  # 10/26 시험 주간
        rule, _ = module.date_rule({'courses': [scheduled(fridays, 5), scheduled(mondays, 1)]})
        self.assertNotIn('2026-10-24', rule[6])
        self.assertIn('2026-10-31', rule[6])


class ParserTest(unittest.TestCase):
    def test_hoseo_periods_merge_and_extend_to_14(self):
        course = {'sourceSchedule': '화1~2, 화3, 토14', 'sourceClassroom': '아)2공509'}
        self.assertEqual(module.hoseo_weekly(course), [
            {'weekday': 2, 'startMinute': 600, 'endMinute': 780, 'classroom': '아)2공509'},
            {'weekday': 6, 'startMinute': 1380, 'endMinute': 1440, 'classroom': '아)2공509'},
        ])
        self.assertEqual(module.hoseo_weekly({'sourceSchedule': '월1, 수2', 'sourceClassroom': 'A / B'})[0]['classroom'], '')

    def test_koreatech_half_periods_and_conflicts(self):
        course = {'sourceId': 'koreatech/unknown/2026-2/X-01', 'sourceSchedule': '수06A~06B,10A~14B', 'remarks': ''}
        self.assertEqual([(m['startMinute'], m['endMinute']) for m in module.koreatech_weekly(course)],
                         [(840, 900), (1080, 1380)])
        self.assertEqual(module.koreatech_weekly({**course, 'sourceSchedule': '수07B(온라인)'})[0]['startMinute'], 930)
        self.assertIsNone(module.koreatech_weekly({**course, 'remarks': '예약 보류: 원본 숫자 분반 중복 및 상충 시간'}))

    def test_hanyang_rooms_and_medical_rows_use_term_dates(self):
        course = {'sourceSchedule': '월(16:00-17:30),시간미지정강좌', 'sourceClassroom': '  ,서울 경영관 101강의실,  '}
        self.assertEqual(module.hanyang_weekly(course),
                         [{'weekday': 1, 'startMinute': 960, 'endMinute': 1050, 'classroom': '서울 경영관 101강의실'}])
        medical = {**course, 'metadata': {'reservationProjection': {
            'heldReasons': ['medicalOwnCourseOperatingPeriodUnconfirmed']}}}
        self.assertEqual(module.hanyang_weekly(medical), module.hanyang_weekly(course))


class BatchTest(unittest.TestCase):
    def write(self, folder, name, courses):
        data = {'universityId': name.split('-')[0], 'courses': courses}
        (folder / f'{name}-2026-2.json').write_text(json.dumps(data, ensure_ascii=False), encoding='utf-8')

    def test_batch_reads_suspended_datasets_and_writes_utf8(self):
        with tempfile.TemporaryDirectory() as tmp:
            root, suspended = Path(tmp, 'assets'), Path(tmp, 'suspended')
            root.mkdir()
            suspended.mkdir()
            self.write(root, 'cnu-unknown', [cnu_course()])
            for name in ('hufs-seoul', 'hufs-global'):
                self.write(root, name, [hufs_course('수 1 2 (C101)')])
            for name in module.UNTIMED_FILES:
                if not name.startswith(('hufs', 'cnu')):
                    folder = suspended if name.startswith('hanyang') else root
                    self.write(folder, name, [{'sourceId': f'{name}/1', 'scheduleStatus': 'unrecognized', 'sourceSchedule': ''}])
            module.main(root, suspended)
            cnu = json.loads((root / 'cnu-unknown-2026-2.json').read_text(encoding='utf-8'))
            self.assertEqual(cnu['courses'][0]['scheduleStatus'], 'scheduled')
            self.assertNotIn(module.CNU_HOLD, cnu['courses'][0]['departmentRemarks']['학과'])
            hanyang = json.loads((suspended / 'hanyang-seoul-2026-2.json').read_text(encoding='utf-8'))
            self.assertEqual(hanyang['courses'][0]['scheduleStatus'], 'unscheduled')

    def test_missing_input_fails_before_any_write(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.write(root, 'cnu-unknown', [cnu_course()])
            before = (root / 'cnu-unknown-2026-2.json').read_text(encoding='utf-8')
            with self.assertRaises(FileNotFoundError):
                module.main(root, Path(tmp, 'none'))
            self.assertEqual((root / 'cnu-unknown-2026-2.json').read_text(encoding='utf-8'), before)


if __name__ == '__main__':
    unittest.main()
