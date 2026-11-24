import tempfile
import unittest
from pathlib import Path

from tool.timetable.import_dju import FILES, meetings, resolve

OFFICIAL = [
    '1. 교양교과목 강의시간표_08.18.xlsx',
    '2. 전공교과목 강의시간표_08.18.xlsx',
    '3. 일반선택 및 교직교과목 강의시간표_08.18.xlsx',
]


class ResolveSourceTests(unittest.TestCase):
    def test_official_korean_filenames_are_found(self):
        with tempfile.TemporaryDirectory() as d:
            for n in OFFICIAL:
                (Path(d) / n).write_bytes(b'')
            found = [resolve(d, n, k).name for n, _, _, k in FILES]
            self.assertEqual(found, OFFICIAL)

    def test_canonical_names_still_work(self):
        with tempfile.TemporaryDirectory() as d:
            for n, *_ in FILES:
                (Path(d) / n).write_bytes(b'')
            for n, _, _, k in FILES:
                self.assertEqual(resolve(d, n, k).name, n)

    def test_missing_file_raises(self):
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaises(FileNotFoundError):
                resolve(d, FILES[0][0], FILES[0][3])


class MeetingTests(unittest.TestCase):
    def test_period_table_and_continued_slots(self):
        # 1교시 09:00, 60-minute slots; 9교시 17:00~18:00, 14교시 continues to 23:00.
        self.assertEqual(meetings('화(1,2,3)', '22220'), [
            {'weekday': 2, 'startMinute': 540, 'endMinute': 720, 'classroom': '22220'}])
        self.assertEqual(meetings('토(13,14)', ''), [
            {'weekday': 6, 'startMinute': 1260, 'endMinute': 1380}])

    def test_gap_splits_block(self):
        self.assertEqual(
            [(m['weekday'], m['startMinute'], m['endMinute']) for m in meetings('월(1),화(1,7)', 'R')],
            [(1, 540, 600), (2, 540, 600), (2, 900, 960)])

    def test_unknown_text_is_rejected(self):
        with self.assertRaises(AssertionError):
            meetings('월(1),미배정', '')


if __name__ == '__main__':
    unittest.main()
