import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    'kongju_book', ROOT / 'tool/timetable/fill_kongju_lecture_book.py')
book_mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(book_mod)

HEADER = ['이수\n구분', '과목번호', '과  목  명', '학점', '담당교수', '강의시간(강의실)']


def table(source_table, context, rows):
    cells = [{'row': 0, 'col': i, 'text': t} for i, t in enumerate(HEADER)]
    for r, row in enumerate(rows, start=1):
        cells += [{'row': r, 'col': i, 'text': t} for i, t in enumerate(row)]
    return {'sourceTable': source_table, 'precedingEducationalContext': context, 'cells': cells}


BOOK = {'educationalTables': [
    # 사범대학 section: heading, ditto carried down, team-taught duplicate rows.
    table(260, ['22. 미술교육과 []'], [
        ['전선', '200350101', '영상II', '1', '이명보', '수9,10'],
        ['″', '200497201', '판화', '3', '김판화', '목1,2'],
        ['〃', '200493403', '조형실습', '3', '김민범', '월1'],
        ['전선', '200493403', '조형실습', '3', '정기역', '월1'],
    ]),
    # 천안공과대학 section: contract department, 7-digit code + section.
    table(325, ['23. 생산기계공학과(계약학과) []'], [
        ['전선', '200564001', '엑셀과통계', '3', '임정란', '토1,2,3'],
    ]),
]}


def dataset(courses):
    return {'schemaVersion': 2, 'universityId': 'kongju', 'campus': 'singwan',
            'academicYear': 2026, 'semester': '2', 'courses': courses}


def course(code, section='', **fields):
    base = {'sourceId': f'kongju/x/{code}{section}', 'courseCode': code, 'section': section,
            'courseName': 'x', 'professor': '', 'classification': '', 'departments': [],
            'departmentCredits': {}, 'departmentClassifications': {},
            'schedules': [{'weekday': 1, 'startMinute': 540, 'endMinute': 600, 'classroom': 'R1'}],
            'sourceSchedule': '월1', 'sourceClassroom': 'R1'}
    base.update(fields)
    return base


class KongjuLectureBookTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        (self.dir / 'book.json').write_text(json.dumps(BOOK, ensure_ascii=False))
        self.org = self.dir / 'org.json'
        self.org.write_text(json.dumps({'schemaVersion': 1, 'university': 'kongju', 'mappings': [
            {'sourceLabel': '미술교육과', 'campus': 'singwan', 'college': '사범대학'}]}))

    def tearDown(self):
        self.tmp.cleanup()

    def run_fill(self, courses):
        path = self.dir / 'kongju-singwan-2026-2.json'
        path.write_text(json.dumps(dataset(courses), ensure_ascii=False))
        book_mod.main(self.dir / 'book.json', [path], self.org)
        return {c['courseCode']: c for c in json.loads(path.read_text())['courses']}

    def test_ditto_marks_carry_the_value_above_within_a_table(self):
        rows = book_mod.book_rows(self.dir / 'book.json')
        self.assertEqual(rows['200497201']['classification'], '전선')
        self.assertEqual(rows['200497201']['heading'], '미술교육과')

    def test_duplicate_rows_keep_only_agreeing_fields(self):
        row = book_mod.book_rows(self.dir / 'book.json')['200493403']
        self.assertEqual(row['classification'], '전선')
        self.assertEqual(row['professor'], '')

    def test_department_level_ditto_is_replaced(self):
        out = self.run_fill([course('200497201', classification='″', departments=['미술교육과'],
                                    departmentClassifications={'미술교육과': '″'})])
        c = out['200497201']
        self.assertEqual(c['classification'], '전선')
        self.assertEqual(c['departmentClassifications'], {'미술교육과': '전선'})

    def test_existing_values_and_schedules_are_preserved(self):
        original = course('200350101', professor='기존교수', classification='전필',
                          departments=['미술교육과'], departmentClassifications={'미술교육과': '전필'})
        out = self.run_fill([copy.deepcopy(original)])['200350101']
        for key in ('professor', 'classification', 'departmentClassifications', 'schedules',
                    'sourceSchedule', 'sourceClassroom', 'courseName'):
            self.assertEqual(out[key], original[key], key)

    def test_contract_course_matches_code_plus_section_and_gets_department(self):
        out = self.run_fill([course('2005640', '01')])['2005640']
        self.assertEqual((out['classification'], out['professor'], out['credits']), ('전선', '임정란', 3.0))
        self.assertEqual(out['departments'], ['생산기계공학과'])
        self.assertEqual(out['departmentClassifications'], {'생산기계공학과': '전선'})
        mapping = [m for m in json.loads(self.org.read_text())['mappings']
                   if m['sourceLabel'] == '생산기계공학과']
        self.assertEqual([(m['college'], m['campus']) for m in mapping], [('천안공과대학', 'singwan')])

    def test_second_run_changes_nothing(self):
        self.run_fill([course('200497201', classification='″', departments=['미술교육과'],
                              departmentClassifications={'미술교육과': '″'}), course('2005640', '01')])
        path = self.dir / 'kongju-singwan-2026-2.json'
        before = path.read_text(), self.org.read_text()
        book_mod.main(self.dir / 'book.json', [path], self.org)
        self.assertEqual((path.read_text(), self.org.read_text()), before)


if __name__ == '__main__':
    unittest.main()
