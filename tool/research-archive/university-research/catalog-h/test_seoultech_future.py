import copy
import json
from pathlib import Path
import unittest

from normalize_seoultech_future import normalize


class PublishedFutureScheduleTest(unittest.TestCase):
    def setUp(self):
        self.document = json.loads((Path(__file__).parent /
            'seoultech-future-public-schedules/703006-11001.json').read_text())

    def test_actual_dates_and_video_windows_are_separate(self):
        parsed = normalize(self.document)
        self.assertEqual(len(parsed['meetings']), 9)
        self.assertEqual(len(parsed['videoAvailability']), 6)
        self.assertEqual(parsed['meetings'][0]['date'], '2026-09-05')
        self.assertEqual(parsed['meetings'][0]['weekday'], 6)
        self.assertEqual(parsed['meetings'][0]['endMinute'], 960)
        self.assertEqual(parsed['videoAvailability'][0]['endDate'], '2026-09-28')

    def test_missing_clock_cannot_create_a_timed_meeting(self):
        broken = copy.deepcopy(self.document)
        broken['rows'][0]['LS_TM_CD_NM'] = '-'
        with self.assertRaises(ValueError):
            normalize(broken)

    def test_disagreeing_start_is_not_silently_replaced(self):
        broken = copy.deepcopy(self.document)
        broken['rows'][0]['LS_DT'] = '2026-09-05 13:30'
        with self.assertRaises(ValueError):
            normalize(broken)


if __name__ == '__main__':
    unittest.main()
