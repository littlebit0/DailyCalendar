import datetime as dt
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('import_sungshin', ROOT / 'tool/timetable/import_sungshin.py')
sungshin = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sungshin)

MONDAY = {1: [dt.date(2026, 9, 7)]}


class SungshinImportTests(unittest.TestCase):
    def test_consecutive_periods_in_different_rooms_stay_separate(self):
        result = sungshin.meetings_for([(1, 540, 590), (1, 600, 650)], ['A101', 'B202'], MONDAY)
        self.assertEqual([(m['startMinute'], m['endMinute'], m['classroom']) for m in result],
                         [(540, 590, 'A101'), (600, 650, 'B202')])

    def test_consecutive_periods_in_one_room_still_merge(self):
        result = sungshin.meetings_for([(1, 540, 590), (1, 600, 650)], ['A101', 'A101'], MONDAY)
        self.assertEqual([(m['startMinute'], m['endMinute'], m['classroom']) for m in result],
                         [(540, 650, 'A101')])


if __name__ == '__main__':
    unittest.main()
