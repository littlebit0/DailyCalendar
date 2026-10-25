import importlib.util
import json
from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('import_chosun', ROOT / 'tool/timetable/import_chosun.py')
chosun = importlib.util.module_from_spec(spec)
spec.loader.exec_module(chosun)

CODES = '\n'.join([
    '@d#ds_out01', 'CODE\tCD_NM', '11\t전공필수', '12\t교양선택',
    '@d#ds_out', 'CODE\tCD_NM', '02\t현장실습', '10\t일반',
    '',
])


def row(**over):
    base = {
        'YEAR': '2026', 'HAKGI_GB': '21', 'CORS_GB': '1', 'PYEGANG_YN': '',
        'GWAMOK_CD': 'A001', 'BUNBAN': '01', 'GWAMOK_NM': '자료구조', 'GYOSU_NM': '김교수',
        'HAKJEOM': '3', 'HAKGWA_NM': ' 컴퓨터공학과 ', 'ISU_GB': '11', 'GANGUI_GB': '10',
        'SUEOP_BANGSIK_NM': '대면', 'CYBER_GANGUI_GB': '0', 'WONEO_GANGJWA_NM': '',
        'TEAM_GYOSU_NM_HAKSAENGYONG': '', 'SUGANG_HAKGWA_ISU_GB': '', 'BIGO': '',
        'GANGUI_TIME_NM': '월 1A~2B(09:00~10:50)', 'GANGUISIL_NM': '공대 101',
    }
    base.update(over)
    return base


class ImportChosunTests(unittest.TestCase):
    def tables(self):
        with TemporaryDirectory() as folder:
            path = Path(folder) / 'codes.tsv'
            path.write_text(CODES, encoding='utf-8')
            tables = chosun.code_tables(path)
        return tables['ds_out01'], tables['ds_out']

    def test_code_tables_translate_codes_per_table(self):
        isu, kinds = self.tables()
        self.assertEqual(isu, {'11': '전공필수', '12': '교양선택'})
        self.assertEqual(kinds, {'02': '현장실습', '10': '일반'})

    def test_multi_meeting_rooms_pair_with_their_slots_in_order(self):
        meetings = chosun.meetings_for(row(
            GANGUI_TIME_NM='월 1A~2B(09:00~10:50), 수 3A~4B(11:00~12:50)',
            GANGUISIL_NM='공대 101, 공대 202'))
        self.assertEqual(meetings, [
            {'weekday': 1, 'startMinute': 540, 'endMinute': 650, 'classroom': '공대 101'},
            {'weekday': 3, 'startMinute': 660, 'endMinute': 770, 'classroom': '공대 202'},
        ])

    def test_room_names_may_contain_commas_but_not_comma_space(self):
        meetings = chosun.meetings_for(row(GANGUISIL_NM='사회관 101,102'))
        self.assertEqual(meetings[0]['classroom'], '사회관 101,102')

    def test_mismatched_rooms_or_unknown_slots_abort(self):
        with self.assertRaises(ValueError):
            chosun.meetings_for(row(GANGUISIL_NM='공대 101, 공대 202'))
        with self.assertRaises(ValueError):
            chosun.meetings_for(row(GANGUI_TIME_NM='월 1~2(09:00~10:50)'))
        with self.assertRaises(ValueError):
            chosun.meetings_for(row(GANGUI_TIME_NM='월 1A~2B(10:50~09:00)'))

    def test_scheduled_course_keeps_published_fields(self):
        isu, kinds = self.tables()
        course = chosun.course_for(row(BIGO=' 비고글 ', WONEO_GANGJWA_NM='영어'), isu, kinds)
        self.assertEqual(course['sourceId'], 'chosun/unknown/2026/2/A001/01')
        self.assertEqual(course['scheduleStatus'], 'scheduled')
        self.assertEqual(course['classification'], '전공필수')
        self.assertEqual(course['departments'], ['컴퓨터공학과'])
        self.assertEqual(len(course['schedules']), 1)
        self.assertNotIn('holdReasons', course)
        self.assertIn('비고 비고글', course['departmentRemarks']['컴퓨터공학과'])
        self.assertIn('원어강좌 영어', course['departmentRemarks']['컴퓨터공학과'])

    def test_remote_cyber_and_field_practice_rows_are_held_without_schedules(self):
        isu, kinds = self.tables()
        remote = chosun.course_for(row(SUEOP_BANGSIK_NM='비대면'), isu, kinds)
        cyber = chosun.course_for(row(CYBER_GANGUI_GB='1'), isu, kinds)
        practice = chosun.course_for(row(GANGUI_GB='02'), isu, kinds)
        for course in (remote, cyber, practice):
            self.assertEqual(course['scheduleStatus'], 'unrecognized')
            self.assertEqual(course['schedules'], [])
            self.assertTrue(course['holdReasons'])
            self.assertIn('시각 보류: ', course['departmentRemarks']['컴퓨터공학과'])
        self.assertIn('현장실습', practice['holdReasons'][0])
        # 보류돼도 원문이 적은 시각은 그대로 남는다.
        self.assertEqual(remote['sourceSchedule'], '월 1A~2B(09:00~10:50)')

    def run_main(self, rows):
        with TemporaryDirectory() as folder:
            folder = Path(folder)
            (folder / 'rows.json').write_text(
                json.dumps({'rows': rows, 'fetched': '2026-10-23'}), encoding='utf-8')
            (folder / 'codes.tsv').write_text(CODES, encoding='utf-8')
            result = subprocess.run(
                [sys.executable, str(ROOT / 'tool/timetable/import_chosun.py'),
                 str(folder / 'rows.json'), str(folder / 'codes.tsv'), str(folder / 'out.json')],
                capture_output=True, text=True)
            output = folder / 'out.json'
            data = json.loads(output.read_text(encoding='utf-8')) if output.exists() else None
        return result, data

    def test_main_drops_closed_rows_and_counts_statuses(self):
        result, data = self.run_main([
            row(), row(GWAMOK_CD='A002', SUEOP_BANGSIK_NM='비대면'),
            row(GWAMOK_CD='A003', PYEGANG_YN='폐강')])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((data['sourceRowCount'], data['closedRowCount']), (3, 1))
        self.assertEqual(data['courseScheduleStatusCounts'], {'scheduled': 1, 'unrecognized': 1})
        self.assertEqual([c['courseCode'] for c in data['courses']], ['A001', 'A002'])
        self.assertFalse(data['completionClaim'])

    def test_main_rejects_other_terms_and_duplicate_sections(self):
        result, _ = self.run_main([row(HAKGI_GB='11')])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('2026학년도 2학기 학부', result.stderr)
        result, _ = self.run_main([row(), row()])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('중복', result.stderr)


if __name__ == '__main__':
    unittest.main()
