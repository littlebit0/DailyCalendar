import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    'seoultech', ROOT / 'tool/timetable/import_seoultech.py')
seoultech = importlib.util.module_from_spec(spec)
spec.loader.exec_module(seoultech)


class SeoultechPublishedSchedulesTest(unittest.TestCase):
    def test_actual_disjoint_architecture_schedule_preserves_both_blocks(self):
        meetings = seoultech.regular_meetings('월(2 ~ 3, 6 ~ 9), 목(4 ~ 9)')
        self.assertEqual([(m['weekday'], m['startMinute'], m['endMinute']) for m in meetings],
                         [(1, 600, 710), (1, 840, 1070), (4, 720, 1070)])

    def test_actual_zero_and_late_periods_are_separate(self):
        meetings = seoultech.regular_meetings('목(0, 14 ~ 14)')
        self.assertEqual([(m['startMinute'], m['endMinute']) for m in meetings],
                         [(480, 530), (1320, 1370)])

    def test_actual_chemistry_room_order_is_not_invented(self):
        meetings = seoultech.regular_meetings('화(5 ~ 6), 수(1 ~ 2)')
        self.assertEqual(len(meetings), 2)
        self.assertTrue(all(m['classroom'] == '' for m in meetings))

    def test_unverified_actual_half_periods_reject(self):
        for text in ['수(4 ~ 5A), 금(4 ~ 5A)', '목(10A, 10B ~ 11)', '월(0 ~ 1A)']:
            with self.subTest(text=text), self.assertRaises(ValueError):
                seoultech.regular_meetings(text)

    def test_unpublished_time_stays_empty_and_bad_ranges_reject(self):
        self.assertEqual(seoultech.regular_meetings(''), [])
        for text in ['월(15)', '월(3 ~ 1)', '월(2, 2)', '월(1) 임의표시']:
            with self.subTest(text=text), self.assertRaises(ValueError):
                seoultech.regular_meetings(text)


if __name__ == '__main__':
    unittest.main()
