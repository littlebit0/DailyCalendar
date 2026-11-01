import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('import_konkuk', ROOT / 'tool/timetable/import_konkuk.py')
konkuk = importlib.util.module_from_spec(spec)
spec.loader.exec_module(konkuk)


class ImportKonkukScheduleTests(unittest.TestCase):
    def test_seoul_periods_rooms_and_delivery_tags(self):
        status, meetings = konkuk.seoul_meetings('월03-04(공학관 101),수05(모시래학사(여동)-본관 115)(e-러닝)')
        self.assertEqual(status, 'scheduled')
        self.assertEqual(meetings, [
            {'weekday': 1, 'startMinute': 600, 'endMinute': 660, 'classroom': '공학관 101'},
            {'weekday': 3, 'startMinute': 660, 'endMinute': 690,
             'classroom': '모시래학사(여동)-본관 115'},
        ])

    def test_seoul_empty_unknown_and_reversed_periods(self):
        self.assertEqual(konkuk.seoul_meetings(''), ('unscheduled', []))
        self.assertEqual(konkuk.seoul_meetings('(협의)'), ('unscheduled', []))
        self.assertEqual(konkuk.seoul_meetings('토99'), ('unrecognized', []))
        self.assertEqual(konkuk.seoul_meetings('월05-03'), ('unrecognized', []))
        self.assertEqual(konkuk.seoul_meetings('월03,협의'), ('unrecognized', []))

    def test_glocal_clock_times_rooms_and_tags(self):
        status, meetings = konkuk.glocal_meetings('화0900-1050(상허관 201),목1300-1350(b-러닝)')
        self.assertEqual(status, 'scheduled')
        self.assertEqual(meetings, [
            {'weekday': 2, 'startMinute': 540, 'endMinute': 650, 'classroom': '상허관 201'},
            {'weekday': 4, 'startMinute': 780, 'endMinute': 830, 'classroom': ''},
        ])

    def test_glocal_rejects_malformed_or_impossible_clock_times(self):
        self.assertEqual(konkuk.glocal_meetings(''), ('unscheduled', []))
        for text in ('화0990-1050', '화1050-0900', '화0900-2500', '화09:00-10:50', '화0900-1050,'):
            self.assertEqual(konkuk.glocal_meetings(text), ('unrecognized', []), text)


if __name__ == '__main__':
    unittest.main()
