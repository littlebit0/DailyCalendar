import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('kmu', ROOT / 'tool/timetable/import_kmu.py')
kmu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(kmu)


class KmuPublishedClockTest(unittest.TestCase):
    def test_actual_current_changed_performance_room_and_clock(self):
        self.assertEqual(kmu.meetings('목15:00~17:50(음101)'), [{
            'weekday': 4, 'startMinute': 900, 'endMinute': 1070, 'classroom': '음101'}])

    def test_actual_seventy_five_minute_days_share_published_room(self):
        self.assertEqual(kmu.meetings('수12:00~13:15 금15:00~16:15(영543)'), [
            {'weekday': 3, 'startMinute': 720, 'endMinute': 795, 'classroom': '영543'},
            {'weekday': 5, 'startMinute': 900, 'endMinute': 975, 'classroom': '영543'}])

    def test_source_unpublished_remote_remains_untimed(self):
        for source in [None, '원격수업()', '원격수업(4영역)']:
            self.assertEqual(kmu.meetings(source), [])

    def test_invalid_clock_and_overlap_reject(self):
        for source in ['월25:00~26:00(A)', '월09:60~11:00(A)',
                       '월11:00~09:00(A)', '월09:00~10:00(A)월09:30~10:30(B)',
                       '월09:00~10:00(A)알수없는표시']:
            with self.subTest(source=source), self.assertRaises(ValueError):
                kmu.meetings(source)


if __name__ == '__main__':
    unittest.main()
