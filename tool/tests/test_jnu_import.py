import importlib.util
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('jnu', ROOT / 'tool/timetable/import_jnu.py')
jnu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(jnu)

class ChonnamTimetableImportTests(unittest.TestCase):
    def test_fifty_and_seventy_five_minute_modules(self):
        parsed, status = jnu.meetings('월3월4수3', '진리관205\n진리관205\n진리관205')
        self.assertEqual(status, 'scheduled')
        self.assertEqual(parsed, [
            {'weekday':1,'startMinute':660,'endMinute':770,'classroom':'진리관205'},
            {'weekday':3,'startMinute':660,'endMinute':710,'classroom':'진리관205'},
        ])
        parsed, status = jnu.meetings('화2목2', '공6-105\n공6-105')
        self.assertEqual([(m['startMinute'],m['endMinute']) for m in parsed], [(630,705),(630,705)])

    def test_source_lexical_period_order_is_sorted_before_coalescing(self):
        parsed, status = jnu.meetings('월10월7월8월9', '공6-420\n공6-420\n공6-420\n공6-420')
        self.assertEqual(status,'scheduled')
        self.assertEqual(parsed,[{'weekday':1,'startMinute':900,'endMinute':1130,'classroom':'공6-420'}])

    def test_unknown_or_conflicting_periods_never_invent_times(self):
        for value,room in [('화9','강의실'),('월13','강의실'),('일1','강의실'),('미정',''),('월3월4','A\nB\nC')]:
            with self.subTest(value=value): self.assertEqual(jnu.meetings(value,room),([], 'unrecognized'))
        self.assertEqual(jnu.meetings('', ''),([], 'unscheduled'))

    def test_unambiguous_late_modules_remain_available(self):
        parsed,status=jnu.meetings('월14월15화10','공6-420')
        self.assertEqual(status,'scheduled')
        self.assertEqual([(m['weekday'],m['startMinute'],m['endMinute']) for m in parsed],[(1,1320,1430),(2,1350,1425)])

    def test_saturday_uses_verified_2026_handbook_module(self):
        parsed,status=jnu.meetings('토0토1토2토3','농5-201')
        self.assertEqual(status,'scheduled')
        self.assertEqual(parsed,[{'weekday':6,'startMinute':480,'endMinute':710,'classroom':'농5-201'}])

    def test_rooms_and_disconnected_periods_stay_separate(self):
        parsed,_=jnu.meetings('월1월2월4','A\nB\nB')
        self.assertEqual(len(parsed),3)
        self.assertEqual([m['classroom'] for m in parsed],['A','B','B'])

    def test_repeated_multiline_official_room_is_preserved(self):
        parsed,status=jnu.meetings('월1월2월3','연암\n고익배홀(100)\n연암\n고익배홀(100)\n연암\n고익배홀(100)')
        self.assertEqual(status,'scheduled')
        self.assertEqual(parsed,[{'weekday':1,'startMinute':540,'endMinute':710,'classroom':'연암\n고익배홀(100)'}])

    def test_official_title_annotations_move_to_remarks_without_losing_them(self):
        row=jnu.table_rows((ROOT/'test/fixtures/academic/jnu-course-table.html').read_text())[0]
        row[1]='회로이론2\n혼합수업(대면+콘텐츠활용)\n영어 30%'
        value=jnu.course(row,'전기공학과',2026,'2')
        self.assertEqual(value['courseName'],'회로이론2')
        self.assertIn('혼합수업(대면+콘텐츠활용)\n영어 30%',value['departmentRemarks']['전기공학과'])

    def test_official_empty_result_row_is_not_an_unknown_schema(self):
        self.assertEqual(jnu.table_rows('<table id="ContentPlaceHolder_ContentPlaceHolderSub_gvData"><tr><td colspan="14">시간표 검색결과가 없습니다</td></tr></table>'),[])

    def test_real_public_electrical_engineering_table_preserves_rows(self):
        rows=jnu.table_rows((ROOT/'test/fixtures/academic/jnu-course-table.html').read_text())
        self.assertEqual(len(rows),36)
        classes=[jnu.course(row,'공과대학 / 전기공학과',2026,'2') for row in rows]
        circuit=next(c for c in classes if c['courseCode']=='EEE2002')
        self.assertEqual(circuit['courseName'],'회로이론2')
        self.assertEqual(circuit['departmentClassifications'],{'공과대학 / 전기공학과':'전필'})
        self.assertIn('교차(전체)',circuit['departmentRemarks']['공과대학 / 전기공학과'])
        self.assertEqual(circuit['sourceId'],'jnu-gwangju-2026-2-EEE2002-1')
        self.assertTrue(all('startMinute' in meeting for c in classes for meeting in c['schedules']))

    def test_changed_table_or_pagination_fails_instead_of_partial_import(self):
        for markup in ['<html>로그인</html>', '<table id="ContentPlaceHolder_ContentPlaceHolderSub_gvData"><tr><td>missing</td></tr></table>', '<table id="ContentPlaceHolder_ContentPlaceHolderSub_gvData"><a href="Page$2"></a></table>']:
            with self.subTest(markup=markup), self.assertRaises(ValueError):jnu.table_rows(markup)

if __name__=='__main__': unittest.main()
