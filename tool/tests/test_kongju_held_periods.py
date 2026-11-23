import copy
import json
import unittest

from tool.timetable.apply_kongju_held_periods import PATHS, apply, convert_public, periodic_blocks

DATES = {wd: [f'2026-09-0{wd}'] for wd in range(1, 7)}


def held(raw, reasons, room='교양206'):
    variant = {'periodRaw': raw, 'roomRaw': room, 'hours': '3'}
    return {'sourceId': 'kongju/current-public/2026/2/000000001', 'scheduleStatus': 'unrecognized',
            'schedules': [], 'remarks': 'BASE. 보류: ' + ', '.join(reasons) + ' 이수구분: 원문.',
            'departmentRemarks': {}, 'sourceSchedule': raw,
            'sourceEducationalMetadata': {'holdReasons': reasons, 'originalPublishedRowVariants': [variant]}}


class KongjuHeldPeriodsTest(unittest.TestCase):
    def test_weekday_night_periods_follow_table_213(self):
        c = held('화10 화8 화9', ['normalDayPeriod10plusNotPublishedOrNightScopeUnknown'])
        self.assertIsNone(convert_public(c, DATES))
        self.assertEqual(c['scheduleStatus'], 'scheduled')
        self.assertEqual([(s['startMinute'], s['endMinute'], s['classroom']) for s in c['schedules']],
                         [(960, 1130, '교양206')])
        self.assertNotIn('보류', c['remarks'])
        self.assertTrue(c['remarks'].endswith(' 이수구분: 원문.'))
        self.assertEqual(c['sourceSchedule'], '화10 화8 화9')

    def test_saturday_night_and_no_period_rows_stay_held(self):
        sat = held('토8,9,10', ['normalDayPeriod10plusNotPublishedOrNightScopeUnknown'])
        self.assertEqual(convert_public(sat, DATES), 'saturday10plus')
        none = held('', ['noPublishedWeekdayPeriod'])
        self.assertTrue(convert_public(none, DATES))
        for c in (sat, none):
            self.assertEqual((c['scheduleStatus'], c['schedules']), ('unrecognized', []))

    def test_continuation_line_needs_matching_hours(self):
        self.assertIsNotNone(periodic_blocks('화2,3,4\n6,7,8\n목2,3,4', '5공208', '9'))
        self.assertIsNone(periodic_blocks('화2,3,4\n6,7,8\n목2,3,4', '5공208', '6'))

    def test_rerun_on_assets_changes_nothing(self):
        datasets = [json.loads(p.read_text(encoding='utf-8')) for p in PATHS]
        before = copy.deepcopy(datasets)
        self.assertNotIn('scheduled', apply(datasets))
        self.assertEqual(datasets, before)


if __name__ == '__main__':
    unittest.main()
