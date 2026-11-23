import copy
import json
import unittest

from tool.timetable.apply_kongju_held_periods import PATHS, apply, convert_public, convert_untimed, periodic_blocks

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

    def test_saturday_late_periods_follow_table_213_saturday_row(self):
        sat = held('토13,14,15', ['normalDayPeriod10plusNotPublishedOrNightScopeUnknown'])
        self.assertIsNone(convert_public(sat, DATES))
        self.assertEqual([(s['weekday'], s['startMinute'], s['endMinute']) for s in sat['schedules']],
                         [(6, 930, 1080)])
        self.assertIn('2026-07-31 수정', sat['remarks'])
        # 토8,9 is table 212 (16:00), 토10 the Saturday row (13:00): two separate blocks.
        mixed = held('토8,9,10', ['normalDayPeriod10plusNotPublishedOrNightScopeUnknown'])
        self.assertIsNone(convert_public(mixed, DATES))
        self.assertEqual([(s['startMinute'], s['endMinute']) for s in mixed['schedules']],
                         [(780, 830), (960, 1080)])

    def test_no_period_rows_stay_held(self):
        none = held('', ['noPublishedWeekdayPeriod'])
        self.assertTrue(convert_public(none, DATES))
        self.assertEqual((none['scheduleStatus'], none['schedules']), ('unrecognized', []))

    def test_untimed_rows_become_unscheduled_with_fields_kept(self):
        for raw in ('', '-', '미개설', '원격수업'):
            c = held(raw, ['noPublishedWeekdayPeriod', 'actualRoomUnpublished'])
            self.assertEqual(convert_untimed(c), 'unscheduled')
            self.assertEqual((c['scheduleStatus'], c['schedules'], c['sourceSchedule']), ('unscheduled', [], raw))
            self.assertNotIn('보류', c['remarks'])
            self.assertIn('시간 미정으로 둡니다', c['remarks'])
            self.assertTrue(c['remarks'].endswith(' 이수구분: 원문.'))
        printed = held('토①', ['other'])
        self.assertEqual(convert_untimed(printed), 'reason:printed')
        self.assertEqual(printed['scheduleStatus'], 'unrecognized')

    def test_variant_with_own_title_and_professor_wins(self):
        c = held('월8/수7,8', ['sameNativeSourceVariantsClockRoomOrTeacherConflict'], '사범2관 (401)')
        c.update(courseName='수질오염론', professor='이정현', campus='singwan', courseCode='200775901')
        rows = c['sourceEducationalMetadata']['originalPublishedRowVariants']
        rows[0].update(courseTitle='수질오염론', professor='이정현')
        rows.append({'periodRaw': '목5,6,7', 'roomRaw': '사범2관 (401)', 'hours': '3',
                     'courseTitle': '신재생에너지와미래환경', 'professor': ''})
        self.assertIsNone(convert_public(c, DATES))
        self.assertEqual(sorted({s['weekday'] for s in c['schedules']}), [1, 3])
        same = copy.deepcopy(c)
        same.update(scheduleStatus='unrecognized', schedules=[])
        same['remarks'] = 'BASE. 보류: sameNativeSourceVariantsClockRoomOrTeacherConflict 이수구분: 원문.'
        same['sourceEducationalMetadata']['holdReasons'] = ['sameNativeSourceVariantsClockRoomOrTeacherConflict']
        same['sourceEducationalMetadata']['originalPublishedRowVariants'][1].update(
            courseTitle='수질오염론', professor='이정현')
        self.assertIsNone(convert_public(same, DATES))
        self.assertEqual(sorted({s['weekday'] for s in same['schedules']}), [1, 3, 4])
        self.assertIn('두 수업 시간', same['remarks'])

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
