import copy
import json
import unittest

from tool.timetable.apply_gknu_held_periods import PATHS, apply, slots


class GknuHeldPeriodsTest(unittest.TestCase):
    def test_periods_past_ten_continue_the_hourly_slot(self):
        self.assertEqual(slots('목10,11,12,13[M1317]'), (4, 1080, 1320, 'M1317'))
        self.assertEqual(slots('월1,2,3[I0002]'), (1, 540, 720, 'I0002'))

    def test_convert_one_and_keep_unreadable(self):
        data = {'courses': [
            {'sourceSchedule': '수10,11,12[I0001]', 'scheduleStatus': 'unrecognized', 'schedules': [],
             'remarks': 'A. 야간 교시의 실제 종료 시각 미확인으로 예약 보류.', 'metadata': {'clockSupported': False}},
            {'sourceSchedule': '', 'scheduleStatus': 'unrecognized', 'schedules': [], 'remarks': '', 'metadata': {}},
        ]}
        self.assertEqual(apply(data, {3: ['2026-09-02']}), 1)
        first, second = data['courses']
        self.assertEqual(first['schedules'], [{'date': '2026-09-02', 'weekday': 3, 'startMinute': 1080,
                                               'endMinute': 1260, 'classroom': 'I0001'}])
        self.assertNotIn('보류', first['remarks'])
        self.assertEqual((second['scheduleStatus'], second['schedules']), ('unrecognized', []))

    def test_rerun_on_assets_changes_nothing(self):
        for path in PATHS:
            data = json.loads(path.read_text(encoding='utf-8'))
            before = copy.deepcopy(data)
            self.assertEqual(apply(data, {}), 0)
            self.assertEqual(data, before)


if __name__ == '__main__':
    unittest.main()
