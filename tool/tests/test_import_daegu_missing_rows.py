import importlib.util
import json
from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'tool/timetable/import_daegu_missing_rows.py'
spec = importlib.util.spec_from_file_location('import_daegu', SCRIPT)
daegu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(daegu)

# Column strip positions of the real PDF dump: (text, x, y, ?, ?, column).
COL = {name: i for i, name in enumerate(daegu.NAMES) if name}


def seg(text, y, name):
    return [text, 0, y, 0, 0, COL[name]]


def row(y, number, **cells):
    out = [seg(number, y, '수강번호')]
    out += [seg(text, y, name) for name, text in cells.items()]
    return out


def page_lines(*extra):
    return [['전공 강의시간표', 0, 40], ['대구대학교 2026-2', 0, 90], *extra]


class DaeguRowExtractionTests(unittest.TestCase):
    def test_headerless_continuation_rows_are_still_extracted(self):
        # No 교과목명 header line on this page: the table continues from the last one.
        lines = {5: page_lines()}
        cols = {5: [*row(200, '1001', 학년='1', 구분='전필', 교과목명='가'),
                    *row(260, '1002', 교과목명='나')]}
        rows = daegu.extract_major_rows(lines, cols)
        self.assertEqual([r['nativeRegistrationNumber'] for r in rows], ['1001', '1002'])
        self.assertEqual({r['tableIndex'] for r in rows}, {0})

    def test_merged_cells_carry_down_only_inside_one_printed_table(self):
        header = ['교과목명', 0, 230]
        lines = {5: page_lines(header)}
        cols = {5: [*row(200, '1001', 학년='1', 구분='전필', 교과목명='가'),
                    *row(215, '1002', 교과목명='나'),
                    *row(260, '1003', 교과목명='다')]}
        rows = daegu.extract_major_rows(lines, cols)
        by = {r['nativeRegistrationNumber']: r['education'] for r in rows}
        # 1002 is in the same table as 1001 and inherits the merged 학년/구분.
        self.assertEqual((by['1002']['학년'], by['1002']['구분']), ('1', '전필'))
        # A header line between 1002 and 1003 starts a new table: the carry resets.
        self.assertEqual((by['1003']['학년'], by['1003']['구분']), ('', ''))
        self.assertEqual([r['tableIndex'] for r in rows], [0, 0, 1])

    def test_pages_without_the_major_table_title_are_skipped(self):
        lines = {5: [['교양 강의시간표', 0, 40]]}
        cols = {5: row(200, '1001', 교과목명='가')}
        self.assertEqual(daegu.extract_major_rows(lines, cols), [])


class DaeguMainTests(unittest.TestCase):
    def run_main(self, folder, old, asset):
        lines = [{'page': 5, 'lines': page_lines(['교과목명', 0, 120])}]
        cols = [{'page': 5, 'lines': [
            *row(200, '1001', 학년='1', 구분='전필', 수강학과='컴공', 교과목명='가', 학점='3'),
            *row(260, '2002', 학년='1', 구분='전필', 수강학과='컴공', 교과목명='나', 학점='3',
                 강의시간='월(09:00-10:15)', 강의실='공대101'),
        ]}]
        files = {'lines': lines, 'cols': cols, 'offerings': old, 'closures': [],
                 'special': [], 'asset': asset}
        paths = {}
        for name, data in files.items():
            paths[name] = Path(folder) / f'{name}.json'
            paths[name].write_text(json.dumps(data, ensure_ascii=False), encoding='utf-8')
        report = Path(folder) / 'report.json'
        result = subprocess.run(
            [sys.executable, str(SCRIPT), '--lines', str(paths['lines']),
             '--cols', str(paths['cols']), '--offerings', str(paths['offerings']),
             '--closures', str(paths['closures']), '--special', str(paths['special']),
             '--asset', str(paths['asset']), '--report', str(report)],
            capture_output=True, text=True)
        return result, paths['asset'], report

    def old_row(self, number, name):
        return {'sourcePage': 5, 'nativeRegistrationNumber': number,
                'education': {'수강번호': number, '교과목명': name}}

    def test_new_registration_numbers_are_appended_and_existing_courses_kept(self):
        with TemporaryDirectory() as folder:
            asset = {'courses': [{'courseCode': '1001', 'courseName': '가'}]}
            result, path, report = self.run_main(folder, [self.old_row('1001', '가')], asset)
            self.assertEqual(result.returncode, 0, result.stderr)
            data = json.loads(path.read_text(encoding='utf-8'))
            self.assertEqual([c['courseCode'] for c in data['courses']], ['1001', '2002'])
            self.assertEqual(data['courses'][0], {'courseCode': '1001', 'courseName': '가'})
            summary = json.loads(report.read_text(encoding='utf-8'))
            self.assertEqual((summary['comparedWithEarlierRows'], summary['addedCourses']), (1, 1))

    def test_a_prior_major_row_the_rebuild_misses_aborts_without_touching_the_asset(self):
        with TemporaryDirectory() as folder:
            asset = {'courses': [{'courseCode': '1001', 'courseName': '가'}]}
            old = [self.old_row('1001', '가'), self.old_row('9999', '사라진 행')]
            before = json.dumps(asset, ensure_ascii=False)
            result, path, report = self.run_main(folder, old, asset)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('earlier major rows not rebuilt', result.stderr)
            self.assertEqual(json.loads(path.read_text(encoding='utf-8')), json.loads(before))
            self.assertFalse(report.exists())

    def test_a_field_that_differs_from_the_earlier_row_aborts(self):
        with TemporaryDirectory() as folder:
            asset = {'courses': []}
            result, path, report = self.run_main(folder, [self.old_row('1001', '다른 이름')], asset)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(report.exists())
            self.assertEqual(json.loads(path.read_text(encoding='utf-8')), asset)


if __name__ == '__main__':
    unittest.main()
