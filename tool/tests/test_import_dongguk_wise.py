import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('import_dongguk_wise', ROOT / 'tool/timetable/import_dongguk_wise.py')
wise = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wise)


def row(text, theory='3.0', practice='0.0', credit='3.0', room='A307', **extra):
    base = {'SBJ_NO': 'LAC14626', 'DVCLS': '01', 'SBJ_NM': '한국문화의변동과 불교', 'PROF_KOR_DSC': '오정열',
            'TMTBL_KOR_DSC': text, 'ROOM_KOR_DSC': room, 'CPDIV_CD_NM': '교양교육', 'DETL_CURI_CD_NM': '융합교양',
            'LESN_STY_CD': '일반강의', 'LESN_TYP_CD': '이론', 'OBJ_SCHGRD': '1학년', 'THRY_HCNT': theory,
            'PRAC_HCNT': practice, 'CDT': credit, 'LESN_REGN_CD_NM': '경주', 'REMK_DSC': None,
            'CLSLESN_DT': None, 'CLSLESN_RESN_DSC': None, 'COLG_NM': '불교문화대학', 'DPT_NM': '불교학부', 'MJR_NM': None}
    base.update(extra)
    return base


def spans(course):
    return sorted({(m['weekday'], m['startMinute'], m['endMinute']) for m in course['schedules']})


class ImportDonggukWiseTests(unittest.TestCase):
    def test_front_bracket_starts_and_tilde_bracket_ends(self):
        # 1.5교시(09:30) ~ 4교시(12:30) is 180 minutes = 3.0 시수.
        c = wise.course(row('월 1.5교시(09:30) ~ 4교시(12:30)'))
        self.assertEqual(c['scheduleStatus'], 'scheduled')
        self.assertEqual(spans(c), [(1, 570, 750)])
        self.assertEqual(c['departments'], ['불교문화대학', '불교학부'])
        self.assertIn('원문 괄호 시각', c['remarks'])

    def test_shared_clock_for_several_weekdays(self):
        c = wise.course(row('화, 목 7교시(15:00) ~ 8교시(16:30)'))
        self.assertEqual(spans(c), [(2, 900, 990), (4, 900, 990)])

    def test_same_day_spans_under_an_hour_apart_join(self):
        c = wise.course(row('수 5.5교시(13:30) ~ 7교시(15:30), 수 7.5교시(15:30) ~ 9교시(17:30)', theory='4.0', credit='3.0'))
        self.assertEqual(spans(c), [(3, 810, 1050)])

    def test_dates_skip_exams_holidays_and_stop_before_finals(self):
        dates = [d.isoformat() for d in wise.class_dates(1)]
        self.assertEqual(dates[0], '2026-09-07')
        self.assertNotIn('2026-10-05', dates)
        self.assertNotIn('2026-10-19', dates)
        self.assertNotIn('2026-10-26', dates)
        self.assertEqual(dates[-1], '2026-12-07')
        self.assertNotIn('2026-09-24', [d.isoformat() for d in wise.class_dates(4)])

    def test_week_limited_text_is_held(self):
        c = wise.course(row('1주차 - 7주차 목 6교시(14:00) ~ 7.5교시(16:00), 8주차 - 8주차 목 6교시(14:00) ~ 6.5교시(15:00)',
                            theory='1.0', credit='1.0'))
        self.assertEqual(c['scheduleStatus'], 'unrecognized')
        self.assertEqual(c['schedules'], [])
        self.assertEqual(c['_held'][0], '주차 한정')

    def test_weekly_time_contradicting_hours_and_credits_is_held(self):
        c = wise.course(row('월, 수 3교시(11:00) ~ 4.5교시(13:00)', theory='2.0', credit='2.0'))
        self.assertEqual(c['scheduleStatus'], 'unrecognized')
        self.assertEqual(c['_held'][0], '시수·학점 불일치')

    def test_bracket_off_the_period_grid_is_rejected(self):
        c = wise.course(row('월 1교시(09:10) ~ 3.5교시(12:00)'))
        self.assertEqual(c['scheduleStatus'], 'unrecognized')
        self.assertEqual(c['_held'][0], '표기 해석 불가')

    def test_empty_clock_is_untimed_and_rooms_are_tidied(self):
        c = wise.course(row(None, room=None, LESN_STY_CD='사이버강의'))
        self.assertEqual(c['scheduleStatus'], 'unscheduled')
        self.assertEqual(c['sourceSchedule'], '')
        self.assertEqual(wise.room_text('E102        , E202'), 'E102, E202')

    def test_build_rejects_duplicate_section(self):
        with self.assertRaises(ValueError):
            wise.build([row('월 1.5교시(09:30) ~ 4교시(12:30)')] * 2)


if __name__ == '__main__':
    unittest.main()
