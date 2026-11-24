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

    def test_week_limited_text_uses_tuesday_to_monday_teaching_weeks(self):
        c = wise.course(row('1주차 - 7주차 목 6교시(14:00) ~ 7.5교시(16:00), 8주차 - 8주차 목 6교시(14:00) ~ 6.5교시(15:00)',
                            theory='1.0', credit='1.0'))
        self.assertEqual(c['scheduleStatus'], 'scheduled')
        # Week 1 is 9/1~9/7; Chuseok 9/24 (week 4) is skipped, the midterm weeks are not.
        self.assertEqual([(m['date'], m['startMinute'], m['endMinute']) for m in c['schedules']],
                         [('2026-09-03', 840, 960), ('2026-09-10', 840, 960), ('2026-09-17', 840, 960),
                          ('2026-10-01', 840, 960), ('2026-10-08', 840, 960), ('2026-10-15', 840, 960),
                          ('2026-10-22', 840, 900)])
        self.assertEqual(wise.week_date(1, 1).isoformat(), '2026-09-07')
        self.assertEqual(wise.week_date(15, 1).isoformat(), '2026-12-14')

    def test_week_16_runs_past_term_end_and_extends_the_period(self):
        # NUR42422 '16주차 - 16주차 금' is 12/18, the SPBL day named in the nursing notice.
        c = wise.course(row('16주차 - 16주차 금 10교시(18:00) ~ 11.5교시(20:00), 9주차 - 9주차 금 7교시(15:00) ~ 10.5교시(19:00)',
                            theory='0.0', practice='4.0', credit='2.0'))
        self.assertEqual([(m['date'], m['startMinute'], m['endMinute']) for m in c['schedules']],
                         [('2026-10-30', 900, 1140), ('2026-12-18', 1080, 1200)])
        self.assertEqual(c['period']['endDate'], '2026-12-18')

    def test_weekly_time_contradicting_hours_keeps_official_clock(self):
        c = wise.course(row('월, 수 3교시(11:00) ~ 4.5교시(13:00)', theory='2.0', credit='2.0'))
        self.assertEqual(c['scheduleStatus'], 'scheduled')
        self.assertEqual(spans(c), [(1, 660, 780), (3, 660, 780)])
        self.assertIn('공식 요일·시각을 그대로 사용', c['remarks'])

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
