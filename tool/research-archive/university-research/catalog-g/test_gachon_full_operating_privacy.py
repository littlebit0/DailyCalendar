import unittest
import urllib.error
from unittest.mock import patch
from types import SimpleNamespace
import audit_gachon_full_operating_reports as audit
from normalize_gachon_enrollment import review_enrollment
from validate_gachon_individual_weekly_period import current_period_weekly_rows_consistent

class OperatingEvidenceBoundaryTest(unittest.TestCase):
    def parse(self,text):
        reader=SimpleNamespace(pages=[SimpleNamespace(extract_text=lambda:text)])
        with patch.object(audit,'PdfReader',return_value=reader):
            return audit.parse_report(b'%PDF fake',{'HAKSU_NO':'02858001','PROFNM':'확인교수'})

    def test_contacts_are_not_written_and_semantics_do_not_make_events(self):
        result=self.parse('학수번호 02858001\n2026 - 2 학기 확인교수\n강의 진행방법\n첫째 수업은 대면으로 진행하지 않는다.\n동영상 학습\n교수 연락 test@example.com\n전화 010-1234-5678\n주차 기간\n1 09/01 ~ 09/07\n실시간 화상 OT\n2 09/08 ~ 09/14\n대면 수업\n')
        body=str(result)
        self.assertNotIn('test@example.com',body)
        self.assertNotIn('010-1234-5678',body)
        self.assertNotIn('MEMBER',body)
        self.assertFalse(result['allWeeklyRowsAreClasses'])
        self.assertNotIn('schedules',result)
        self.assertEqual([1,2],[row['week'] for row in result['weeklyRows']])
        self.assertEqual('09/01',result['weeklyRows'][0]['startMonthDay'])

    def test_additional_week_date_and_clock_are_not_lost(self):
        result=self.parse('학수번호 02858001\n2026 - 2 학기 확인교수\n주차 기간\n1 09/01 ~ 09/07\n특별 수업 9월 3일 14:00 ~ 15:00\n2 09/08 ~ 09/14\n중간고사\n')
        self.assertTrue(result['weeklyRows'][0]['explicitClockMention'])
        self.assertTrue(result['weeklyRows'][0]['explicitAdditionalDateMention'])
        self.assertIn('14:00',str(result['weeklyRows'][0]['operatingContexts']))
        self.assertIn('중간고사',result['weeklyRows'][1]['signals'])

    def test_enrollment_condition_is_separate_from_unrestricted_guess(self):
        result=self.parse('학수번호 02858001\n2026 - 2 학기 확인교수\n수강대상: 국제대학 학생 전용\n재수강 불가\n강의 진행방법\n토론 수업\n주차 기간\n1 09/01 ~ 09/07\n강의\n')
        evidence=result['enrollmentEvidence']
        self.assertEqual('heading-found',evidence['separateFieldState'])
        self.assertIn('국제대학 학생 전용',str(evidence['publicRestrictionContexts']))
        self.assertFalse(evidence['absenceMeansUnrestricted'])
        empty=self.parse('학수번호 02858001\n2026 - 2 학기 확인교수\n수강대상\n강의 진행방법\n강의\n')['enrollmentEvidence']
        self.assertEqual('empty-same-line-not-proof-of-unrestricted',empty['headings'][0]['sameLineState'])
        self.assertFalse(empty['absenceMeansUnrestricted'])

    def test_adjacent_table_heading_is_not_prerequisite(self):
        result=self.parse('학수번호 02858001\n2026 - 2 학기 확인교수\n선수과목 공학인증 이수구분\n가천대학교\n')
        normalized=review_enrollment(result)
        self.assertEqual('',normalized['fields'][0]['sameLineValue'])
        self.assertEqual([],normalized['contexts'])
        self.assertFalse(normalized['absenceMeansUnrestricted'])

    def test_wrong_current_identity_does_not_retain_operating_excerpts(self):
        result=self.parse('학수번호 02858002\n2026 - 2 학기 확인교수\n동영상 사전학습\n주차 기간\n1 09/01 ~ 09/07\n대면 수업')
        self.assertEqual('identity-unverified',result['status'])
        self.assertEqual([],result['weeklyRows'])
        self.assertEqual([],result['operatingContexts'])

    def test_prior_term_is_not_current_course_proof(self):
        result=self.parse('학수번호 02858001\n2025 - 2 학기 확인교수\n실시간 화상 수업')
        self.assertFalse(result['report']['currentTermMatches'])
        self.assertEqual([],result['operatingContexts'])

    def test_english_operating_exceptions_are_not_silent_ordinary_classes(self):
        result=self.parse('학수번호 02858001\n2026 - 2 학기 확인교수\n주차 기간\n1 09/01 ~ 09/07\nNo class: public holiday, make-up Oct 17 14:00\n2 09/08 ~ 09/14\nOnline video: asynchronous remote study\n3 09/15 ~ 09/21\nIntensive class, final examination\n')
        self.assertEqual(6,result['educationalParserVersion'])
        self.assertTrue({'휴강','휴일','보강'}.issubset(result['weeklyRows'][0]['signals']))
        self.assertTrue(result['weeklyRows'][0]['explicitAdditionalDateMention'])
        self.assertTrue({'온라인','동영상','비대면'}.issubset(result['weeklyRows'][1]['signals']))
        self.assertIn('Online video',str(result['weeklyRows'][1]['operatingContexts']))
        self.assertTrue({'집중','시험'}.issubset(result['weeklyRows'][2]['signals']))

    def test_dedicated_notebook_is_not_an_enrollment_restriction(self):
        result=self.parse('학수번호 02858001\n2026 - 2 학기 확인교수\n강의 진행방법\n컨셉워크숍 전용 노트를 준비한다.\n강의\n주차 기간\n1 09/01 ~ 09/07\n토론\n')
        self.assertEqual([],review_enrollment(result)['contexts'])

    def test_short_individual_period_never_expands_to_the_ordinary_semester(self):
        import datetime
        rows=[]
        for index in range(4):
            begin=datetime.date(2026,11,24)+datetime.timedelta(days=7*index)
            rows.append({'week':index+1,'startMonthDay':begin.strftime('%m/%d'),'endMonthDay':(begin+datetime.timedelta(days=6)).strftime('%m/%d'),'activityPresent':True})
        report={'weeklyRows':rows}
        course={'period':{'startDate':'2026-11-24','endDate':'2026-12-21'}}
        self.assertTrue(current_period_weekly_rows_consistent(report,course))
        self.assertFalse(current_period_weekly_rows_consistent(report,{'period':{'startDate':'2026-09-01','endDate':'2026-12-14'}}))
        self.assertFalse(current_period_weekly_rows_consistent(report,{'period':None}))
        self.assertFalse(current_period_weekly_rows_consistent({'weeklyRows':rows[:-1]},course))

    def test_all_months_other_term_and_field_trip_are_retained(self):
        result=self.parse('학수번호 02858001\n2026 - 2 학기 확인교수\n강의 진행방법\nSpring semester 2026\n주차 기간\n1 09/01 ~ 09/07\nMay 14 site visit, Jun 2 field trip\n2 09/08 ~ 09/14\n수업 없음, 교외 견학 대체출석\n')
        self.assertTrue(result['potentialDifferentTermStatement'])
        self.assertTrue(result['weeklyRows'][0]['explicitAdditionalDateMention'])
        self.assertIn('교외활동',result['weeklyRows'][0]['signals'])
        self.assertIn('May 14',str(result['weeklyRows'][0]['operatingContexts']))
        self.assertTrue({'수업없음','교외활동'}.issubset(result['weeklyRows'][1]['signals']))

    def test_protection_response_stops_the_other_worker_without_retry(self):
        audit.HALT.clear()
        error=urllib.error.HTTPError('https://public.example',429,'rate limited',{},None)
        try:
            with patch.object(audit.urllib.request,'urlopen',side_effect=error) as transport:
                with self.assertRaises(urllib.error.HTTPError):audit.request('https://public.example',None,{})
                self.assertTrue(audit.HALT.is_set())
                with self.assertRaises(RuntimeError):audit.request('https://public.example',None,{})
                self.assertEqual(1,transport.call_count)
        finally:audit.HALT.clear()

    def test_actual_weekend_short_start_is_not_moved_to_week_template_start(self):
        import datetime
        rows=[]
        for index in range(5):
            begin=datetime.date(2026,11,10)+datetime.timedelta(days=7*index)
            rows.append({'week':11+index,'startMonthDay':begin.strftime('%m/%d'),'endMonthDay':(begin+datetime.timedelta(days=6)).strftime('%m/%d'),'activityPresent':True})
        course={'period':{'startDate':'2026-11-14','endDate':'2026-12-14','kind':'Last date of final published teaching week; not a claim of actual final weekday meeting'}}
        self.assertTrue(current_period_weekly_rows_consistent({'weeklyRows':rows},course))
        self.assertEqual('2026-11-14',course['period']['startDate'])
        self.assertFalse(current_period_weekly_rows_consistent({'weeklyRows':rows[1:]},course))

if __name__=='__main__':unittest.main()
