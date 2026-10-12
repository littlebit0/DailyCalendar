import importlib.util,json,copy
from pathlib import Path
import unittest
spec=importlib.util.spec_from_file_location('yongin',Path(__file__).parents[1]/'timetable'/'import_yongin.py')
yongin=importlib.util.module_from_spec(spec);spec.loader.exec_module(yongin)


class YonginImportTest(unittest.TestCase):
    def setUp(self):
        self.f=json.loads((Path(__file__).parent/'fixtures'/'yongin-real-rows.json').read_text())
        self.c,self.audit=yongin.parse_records(self.f['payload'],self.f['closures'],2026,'2',8)

    def course(self,code,section):return next(c for c in self.c if c['courseCode']==code and c['section']==section)

    def test_split_row_meetings_and_professors_preserved(self):
        c=self.course('120003','11')
        self.assertEqual([(s['weekday'],s['startMinute'],s['endMinute']) for s in c['schedules']],[(1,785,870),(2,785,870)])
        self.assertIn('김영학',c['professor']);self.assertIn('김형룡',c['professor'])

    def test_merged_intensive_course_not_weekly(self):
        c=self.course('250073','68')
        self.assertEqual(c['courseName'],'라운드실전실습심화')
        self.assertEqual(c['scheduleStatus'],'unrecognized');self.assertEqual(c['schedules'],[])
        self.assertIn('16:35-19:15',c['sourceSchedule']);self.assertIn('집중수업',c['departmentRemarks']['골프학부-골프'])

    def test_mixed_remote_course_needs_unpublished_real_dates(self):
        c=self.course('M00001','01')
        self.assertEqual(c['scheduleStatus'],'unrecognized');self.assertEqual(c['schedules'],[])
        self.assertIn('9~15주차',next(iter(c['departmentRemarks'].values())))
        note=next(iter(c['departmentRemarks'].values()))
        self.assertIn('2월 중순 이후',note)
        self.assertNotIn('학수번호 교과목명 학점',note)
        self.assertNotIn('1 교선',note)

    def test_course_restriction_preserved(self):
        c=self.course('950031','01');self.assertIn('태권도 전공생 제외',next(iter(c['departmentRemarks'].values())))
        self.assertEqual(c['scheduleStatus'],'unscheduled')

    def test_consortium_no_invented_weekly_times(self):
        c=self.course('W00461','01');self.assertEqual(c['scheduleStatus'],'unscheduled');self.assertEqual(c['schedules'],[])
        self.assertIn('시험 일시는 별도',next(iter(c['departmentRemarks'].values())))
        self.assertEqual(sum(c['courseCode'].startswith(('W','K')) for c in self.c),22)

    def test_actual_pdf_room_text_survives_missing_grid_segments(self):
        import pdfplumber
        spec=importlib.util.spec_from_file_location('extract',Path(__file__).parents[1]/'timetable'/'extract_yongin.py')
        extract=importlib.util.module_from_spec(spec);spec.loader.exec_module(extract)
        with pdfplumber.open(Path(__file__).parent/'fixtures'/'yongin-updated-room-page.pdf') as document:
            page=document.pages[0]
            rows=extract.extract_table_rows(page,page.find_tables()[0])
            row=next(r for r in rows if '550169-73' in r)
            self.assertEqual(row[-1],'용오름-7217(WEB실습실)')

    def test_exact_closure_and_incomplete_scope(self):
        self.assertFalse(any(c['courseCode']=='250051' for c in self.c));self.assertIn(('250051','28'),self.audit['closedKeysExcluded'])
        bad=copy.deepcopy(self.f['payload']);bad['remote'].pop()
        with self.assertRaises(ValueError):yongin.parse_records(bad,self.f['closures'],2026,'2',8)
        with self.assertRaises(ValueError):yongin.parse_clock('월09:80-10:00','')


if __name__=='__main__':unittest.main()
