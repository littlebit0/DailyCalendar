import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location(
    'held_confirm_common', Path(__file__).parents[1] / 'timetable' / 'held_confirm_common.py')
common = importlib.util.module_from_spec(spec)
spec.loader.exec_module(common)


def course(dates_by_weekday, status='scheduled'):
    return {'scheduleStatus': status, 'schedules': [
        {'weekday': w, 'startMinute': 540, 'endMinute': 600, 'classroom': 'A', 'date': d}
        for w, ds in dates_by_weekday.items() for d in ds]}


# 2026-09: Mondays 7, 14, 21(holiday), 28; Tuesdays 8, 15, 22, 29.
MONDAYS = ['2026-09-07', '2026-09-14', '2026-09-28']
TUESDAYS = ['2026-09-08', '2026-09-15', '2026-09-22', '2026-09-29']


class WeekdayDatesTest(unittest.TestCase):
    def test_most_common_date_set_wins_over_irregular_rows(self):
        dataset = {'courses': [course({1: MONDAYS}), course({1: MONDAYS}),
                               course({1: ['2026-09-07']}),  # irregular partial row
                               course({1: ['2026-09-21']}, status='unrecognized')]}
        self.assertEqual(common.weekday_dates(dataset)[1], MONDAYS)

    def test_missing_weekday_covers_pattern_weeks_minus_observed_holidays(self):
        dataset = {'courses': [course({1: MONDAYS, 2: TUESDAYS})]}
        dates = common.weekday_dates(dataset)
        # Weeks come from the regular dates (Mondays 9/7-9/28); a weekday no
        # scheduled row uses gets one date per such week.
        self.assertEqual(dates[7], ['2026-09-13', '2026-09-20', '2026-09-27', '2026-10-04'])
        self.assertEqual(dates[3], ['2026-09-09', '2026-09-16', '2026-09-23', '2026-09-30'])

    def test_no_dated_rows_means_undated_dataset(self):
        dataset = {'courses': [{'scheduleStatus': 'scheduled', 'schedules': [
            {'weekday': 1, 'startMinute': 540, 'endMinute': 600, 'classroom': ''}]}]}
        self.assertEqual(common.weekday_dates(dataset), {})


class ExpandAndMergeTest(unittest.TestCase):
    def test_expand_places_each_meeting_on_its_weekday_dates(self):
        meetings = [{'weekday': 2, 'startMinute': 600, 'endMinute': 690, 'classroom': 'B'}]
        out = common.expand(meetings, {2: ['2026-09-08', '2026-09-15']})
        self.assertEqual([m['date'] for m in out], ['2026-09-08', '2026-09-15'])
        self.assertTrue(all(m['weekday'] == 2 and m['startMinute'] == 600 for m in out))

    def test_expand_without_dates_keeps_weekly_meetings(self):
        meetings = [{'weekday': 2, 'startMinute': 600, 'endMinute': 690, 'classroom': 'B'}]
        self.assertEqual(common.expand(meetings, {}), meetings)

    def test_merge_joins_short_gaps_and_lists_same_time_rooms(self):
        merged = common.merge([
            {'weekday': 1, 'startMinute': 540, 'endMinute': 600, 'classroom': 'A'},
            {'weekday': 1, 'startMinute': 600, 'endMinute': 660, 'classroom': 'A'},
            {'weekday': 1, 'startMinute': 780, 'endMinute': 840, 'classroom': 'A'},
            {'weekday': 2, 'startMinute': 540, 'endMinute': 600, 'classroom': 'A'},
            {'weekday': 2, 'startMinute': 540, 'endMinute': 600, 'classroom': 'B'},
        ])
        self.assertEqual([(m['weekday'], m['startMinute'], m['endMinute'], m['classroom']) for m in merged],
                         [(1, 540, 660, 'A'), (1, 780, 840, 'A'), (2, 540, 600, 'A, B')])

    def test_merge_without_join_keeps_source_blocks(self):
        merged = common.merge([
            {'weekday': 1, 'startMinute': 540, 'endMinute': 615, 'classroom': 'A'},
            {'weekday': 1, 'startMinute': 630, 'endMinute': 705, 'classroom': 'A'},
        ], join=False)
        self.assertEqual(len(merged), 2)

    def test_merge_rejects_times_past_midnight(self):
        with self.assertRaises(ValueError):
            common.merge([{'weekday': 1, 'startMinute': 1410, 'endMinute': 1470, 'classroom': ''}])


class ConfirmTest(unittest.TestCase):
    def test_confirm_replaces_hold_phrase_with_note(self):
        row = {'scheduleStatus': 'unrecognized', 'schedules': [],
               'departmentRemarks': {'X': '대상: 전체\n시각 미확인: 추가 불가'}}
        common.confirm(row, [{'weekday': 1}], 'NOTE', ('시각 미확인: 추가 불가',))
        self.assertEqual(row['scheduleStatus'], 'scheduled')
        self.assertEqual(row['departmentRemarks']['X'], '대상: 전체\nNOTE')


if __name__ == '__main__':
    unittest.main()
