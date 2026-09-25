import importlib.util
from pathlib import Path
from tempfile import TemporaryDirectory
from types import SimpleNamespace
import unittest
from unittest.mock import MagicMock, patch

spec = importlib.util.spec_from_file_location('smu', Path(__file__).resolve().parents[1] / 'timetable/import_sangmyung.py')
smu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(smu)

class TimetableImportTests(unittest.TestCase):
    def extract_pages(self, rows, header=None):
        pages = []
        for department, remarks in rows:
            row = ['1', '1', '1전선', 'HAAA0001', '테스트 과목', '3', '3', '0',
                   '', '월1,2,3(A101)', '1', '테스트 교수', remarks]
            pages.append(SimpleNamespace(
                extract_text=lambda department=department: f'2026학년도 2학기\n{department}',
                extract_tables=lambda row=row: [[list(header or smu.TABLE_HEADER), row]],
            ))
        context = MagicMock()
        context.__enter__.return_value = SimpleNamespace(pages=pages)
        with TemporaryDirectory() as directory:
            source = Path(directory) / 'table-fixture.pdf'
            source.write_bytes(b'Table extraction unit-test fixture')
            with patch.dict('sys.modules', {'pdfplumber': SimpleNamespace(open=lambda _: context)}):
                return smu.extract(source, 'seoul', 2026, '2', 'https://example.test/source.pdf', '2026-09-23')

    def test_numeric_and_letter_periods(self):
        self.assertEqual(smu.meeting_times('월1,2(A101) 수F(B201)'), [
            {'weekday':1,'startMinute':540,'endMinute':650,'classroom':'A101'},
            {'weekday':3,'startMinute':930,'endMinute':1005,'classroom':'B201'},
        ])
        self.assertEqual(smu.meeting_times('토15(Z200)')[0]['endMinute'],1430)

    def test_disconnected_periods_and_rooms_stay_separate(self):
        self.assertEqual(len(smu.meeting_times('월1,3(A101)')),2)
        self.assertEqual(len(smu.meeting_times('월1(A101) 월2(A102)')),2)

    def test_unknown_or_out_of_range_notation_is_rejected(self):
        for value in ['','시간미정','월16(A101)','월J(A101)','월1(A101)미정']:
            with self.subTest(value=value), self.assertRaises(ValueError):
                smu.meeting_times(value)

    def test_official_curriculum_codes_are_preserved_and_unknowns_fail(self):
        for value in ['1전심', '1전선', '1교직', '교선', '교필', '일선', '1MD']:
            self.assertEqual(smu.classification(value), value)
        self.assertEqual(smu.classification('1\n전심'), '1전심')
        for value in ['', '전공 추정', '필수']:
            with self.subTest(value=value), self.assertRaises(ValueError):
                smu.classification(value)

    def test_cross_listed_department_remarks_preserve_newlines_and_empty_rows(self):
        result = self.extract_pages([
            ('컴퓨터과학과', '신입생 전용\n재수강 신청 제한'),
            ('미디어학과', '미디어학과 학생 신청 가능\n확인 필요'),
            ('융합학과', ''),
        ])
        self.assertEqual(result['sourceRowCount'], 3)
        self.assertEqual(len(result['courses']), 1)
        course = result['courses'][0]
        self.assertEqual(course['departmentRemarks'], {
            '컴퓨터과학과': '신입생 전용\n재수강 신청 제한',
            '미디어학과': '미디어학과 학생 신청 가능\n확인 필요',
            '융합학과': '',
        })
        self.assertEqual(course['sourceId'], 'smu/seoul/2026/2/HAAA0001/1')
        self.assertEqual(course['sourcePages'], [1, 2, 3])
        self.assertEqual(course['schedules'][0]['endMinute'], 710)

    def test_conflicting_remarks_for_same_department_cannot_silently_overwrite(self):
        with self.assertRaisesRegex(ValueError, 'Conflicting department remarks'):
            self.extract_pages([('컴퓨터과학과', '신입생 전용'), ('컴퓨터과학과', '재수강 전용')])

    def test_remarks_column_must_match_official_table_header(self):
        header = list(smu.TABLE_HEADER)
        header[-1] = '다른 열'
        with self.assertRaisesRegex(ValueError, 'Unexpected table columns'):
            self.extract_pages([('컴퓨터과학과', '원문 비고')], header=header)

if __name__ == '__main__':
    unittest.main()
