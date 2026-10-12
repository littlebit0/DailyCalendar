import importlib.util
from pathlib import Path
import unittest

spec=importlib.util.spec_from_file_location('pnu_import',Path(__file__).resolve().parents[1]/'timetable/import_pnu.py')
pnu=importlib.util.module_from_spec(spec)
spec.loader.exec_module(pnu)

class PnuImportTest(unittest.TestCase):
    def test_actual_duration_mixed_asynchronous_and_classroom_commas(self):
        meetings,campus=pnu.meetings('월 09:00(75) 306-210, 수 10:30(50) 306-210, 토 사이버수업')
        self.assertEqual(campus,'busan')
        self.assertEqual([(m['weekday'],m['startMinute'],m['endMinute']) for m in meetings],[(1,540,615),(3,630,680)])
        self.assertEqual(pnu.meetings('금 09:00-12:00 양산Y15-206')[1],'yangsan')
        self.assertEqual(pnu.meetings('화 13:00(100) 밀양M02-201')[1],'miryang')

    def test_external_label_precedes_embedded_campus_text(self):
        text='목 17:30(50)(외부)https://app.pulle양산Yca밀양Mpus.co밀양M/login/pusan'
        meetings,campus=pnu.meetings(text)
        self.assertEqual(campus,'shared')
        self.assertIn('양산Y',meetings[0]['classroom'])
        self.assertEqual(pnu.meetings(text,asynchronous=True),([], 'shared'))
        self.assertEqual(pnu.meetings('토 사이버수업'),([], 'shared'))

    def test_campus_spanning_class_preserves_both_meetings(self):
        meetings,campus=pnu.meetings('월 09:00(75) 306-210, 수 09:00(75) 양산Y15-206')
        self.assertEqual(campus,'multiple')
        self.assertEqual(len(meetings),2)
        combined,campus=pnu.meetings('금 13:30-16:30 602-201, 금 13:30-16:30 밀양M03-3262')
        self.assertEqual(campus,'multiple')
        self.assertEqual(len(combined),1)
        self.assertEqual(combined[0]['classroom'],'602-201 / 밀양M03-3262')

    def test_invalid_dates_unknown_room_and_incomplete_restrictions_fail(self):
        for text in ['월 25:00(50) 306-210','월 09:90(50) 306-210','월 09:00-08:00 306-210','월 09:00(50) 추측강의실']:
            with self.assertRaises(ValueError):pnu.meetings(text)
        row={'SYEAR':'2026','TERM_GCD':'0020','COURSE_COLL_GRAD_GCD':'0001','SUBJ_NO':'KL1500547','CLASS_NO':'010','SUBJ_NM':'고전문학입문','MNG_DEPT_NM':'국어국문학과','CRDT':3}
        with self.assertRaisesRegex(ValueError,'restriction'):pnu.parse_rows([row])

    def test_current_restriction_and_professor_are_preserved(self):
        row={'SYEAR':'2026','TERM_GCD':'0020','COURSE_COLL_GRAD_GCD':'0001','SUBJ_NO':'KL1500547','CLASS_NO':'010','SUBJ_NM':'고전문학입문','MNG_DEPT_NM':'국어국문학과 (051-510-0000)','CRDT':3,'restriction':'국어국문학과 수강 불가','PROF_NM':'정은영','SUBJ_GCD_NM':'전공기초','TIMETABLE_SUMMARY_INFO':'월 09:00(75) 306-210','ALL_CYBER':None}
        course=pnu.parse_rows([row])[0]
        self.assertEqual(course['section'],'010')
        self.assertEqual(course['professor'],'정은영')
        self.assertEqual(course['departmentRemarks']['국어국문학과'],'국어국문학과 수강 불가')
        with self.assertRaisesRegex(ValueError,'Duplicate'):pnu.parse_rows([row,row])
        row['COURSE_COLL_GRAD_GCD']='0002'
        with self.assertRaisesRegex(ValueError,'undergraduate'):pnu.parse_rows([row])

if __name__=='__main__':unittest.main()
