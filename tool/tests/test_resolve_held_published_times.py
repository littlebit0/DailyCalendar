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

    def test_partial_or_closed_rows_stay_held(self):
        self.assertFalse(module.untimed({'sourceId': 'hanyang/x', 'sourceSchedule': '화(09:00-10:00),시간미지정강좌'}))
        self.assertFalse(module.untimed({
            'sourceId': 'cnu/x', 'sourceSchedule': '',
            'departmentRemarks': {'학과': '현재 폐강된 강좌입니다.'},
        }))

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

    def test_operation_or_review_holds_are_kept(self):
        for course in (
            cnu_course(fields={'LSN_METHOD_CD_NM': '혼합'}),
            cnu_course(fields={'CLOSE_YN': '1'}),
            cnu_course(registrationStatus='blockedIndividualFieldOperationUnresolved',
                       fieldOperationReview={'fieldClockRoomIndividuallyConfirmed': False}),
            cnu_course(individualReviewStatus='currentPublicPlanAbsent'),
            cnu_course(actualDisplayedClocks=[]),
        ):
            self.assertIsNone(module.cnu_meetings(course))


class HufsTest(unittest.TestCase):
    def test_periods_use_official_slots_and_existing_date_rule(self):
        meetings = module.hufs_meetings(hufs_course('금 5 6 (1205)'))
        dates = [m['date'] for m in meetings]
        self.assertTrue(all((m['weekday'], m['startMinute'], m['endMinute']) == (5, 780, 900) for m in meetings))
        self.assertNotIn('2026-09-25', dates)
        self.assertNotIn('2026-10-09', dates)
        self.assertEqual(dates[-1], '2026-12-04')  # regular dates end Dec 7

    def test_mode_notes_and_unpublished_periods_stay_held(self):
        self.assertIsNone(module.hufs_meetings(hufs_course('월 1 2 (1203)', '비대면 · ')))
        self.assertIsNone(module.hufs_meetings(hufs_course('월 12 13 (1203)')))
        self.assertIsNone(module.hufs_meetings(hufs_course('')))


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
                if not name.startswith('hufs'):
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
