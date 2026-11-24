import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('import_daegu_closed', ROOT / 'tool/timetable/import_daegu_closed_rows.py')
daegu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(daegu)


def row(page, **education):
    base = {k: '' for k in daegu.GENERAL}
    base.update({'수강번호': '1256', '교과목명': '가', '수강학과': '경찰행정', '학점': '2'}, **education)
    cells = [base[k] for k in daegu.GENERAL]
    return {'sourcePage': page, 'tableIndex': 0, 'sourceRow': 1, 'sourceTitleLines': ['교양·교직 강의시간표'],
            'nativeRegistrationNumber': base['수강번호'], 'education': base, 'sourceCells': cells}


class ClosedRowCourseTests(unittest.TestCase):
    def test_printed_clock_is_scheduled_with_long_room_and_closure_note(self):
        c = daegu.build_course('1256', [row(87, 강의시간='월(14:00-15:50)', 강의실='공공인재-13'),
                                        row(140, 강의시간='월(14:00-15:50)', 강의실='공공인재-1302')])
        self.assertEqual(c['scheduleStatus'], 'scheduled')
        self.assertEqual({m['classroom'] for m in c['schedules']}, {'공공인재-1302'})
        # Mondays 9/7..12/7 minus 10/5 (holiday) and 9/1 is a Tuesday.
        self.assertEqual(len(c['schedules']), 13)
        self.assertEqual(c['sourceSnapshotSchedules'][0]['classroom'], '공공인재-13')
        self.assertIn('긴 표기로 통일', c['remarks'])
        self.assertIn('폐강 공지 대상이어도 공식 시간표 행', c['remarks'])
        self.assertIn(daegu.MARK, c['remarks'])

    def test_virtual_room_without_clock_is_unscheduled(self):
        c = daegu.build_course('1256', [row(87, 강의실='DU∼MOOC')])
        self.assertEqual((c['scheduleStatus'], c['schedules']), ('unscheduled', []))
        self.assertNotIn('일정 미생성', c['remarks'])

    def test_missing_or_differing_clock_or_room_stays_unrecognized(self):
        cases = [[row(87, 강의실='미지정')],
                 [row(87, 강의시간='월(09:00-10:15)', 강의실='A-1'), row(90, 강의시간='화(09:00-10:15)', 강의실='A-1')],
                 [row(87, 강의시간='월(09:00-10:15)', 강의실='A-1'), row(90, 강의시간='월(09:00-10:15)', 강의실='B-2')],
                 [row(87, 강의시간='월(09:00-10:15)')]]
        for src in cases:
            c = daegu.build_course('1256', src)
            self.assertEqual((c['scheduleStatus'], c['schedules']), ('unrecognized', []))
            self.assertIn('일정 미생성', c['remarks'])
            self.assertNotIn(daegu.MARK, c['remarks'])


class ClosedRowExtractionTests(unittest.TestCase):
    def test_convergence_pages_are_only_untitled_tables(self):
        page = [['클라시카자유학', 45, 104], ['수강학과', 104, 126]]
        self.assertEqual(daegu.convergence_title(page), ['클라시카자유학'])
        self.assertIsNone(daegu.convergence_title(page + [['전공 강의시간표', 246, 65]]))
        self.assertIsNone(daegu.convergence_title([['연계융복합전공', 199, 112]]))

    def test_self_check_reports_any_field_not_rebuilt(self):
        asset = [{'publicEducationRows': [row(87, 강의실='공공인재-13')]}]
        self.assertEqual(daegu.self_check([row(87, 강의실='공공인재 -13')], asset), (1, []))
        compared, failures = daegu.self_check([row(87, 강의실='공공인재-12')], asset)
        self.assertEqual((compared, len(failures)), (0, 1))


if __name__ == '__main__':
    unittest.main()
