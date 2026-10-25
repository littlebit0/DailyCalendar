import tempfile
import unittest
from pathlib import Path

from tool.timetable.import_dju import FILES, resolve

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


if __name__ == '__main__':
    unittest.main()
