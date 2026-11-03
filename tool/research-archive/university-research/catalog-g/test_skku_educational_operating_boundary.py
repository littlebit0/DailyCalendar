import unittest,time,threading
from unittest.mock import patch
import audit_skku_public_operating_plans as collector
from audit_skku_public_operating_plans import education,text_evidence,CATALOG_FIELDS,FIELDS
class EducationalBoundary(unittest.TestCase):
    def test_single_line_pdf_preserves_late_operating_marker(self):
        text='2026-2 BIZ2021 '+'ordinary learning topic '*100+' No class on September24; makeup October5 at13:30. '
        result=text_evidence(text,'BIZ2021','01','Teacher')
        self.assertTrue(any('No class' in x and 'October5' in x for x in result['educationalOperatingContexts']))
        self.assertTrue(result['currentTermPresent'])
    def test_contact_and_private_identifiers_are_not_education(self):
        text='연락처 010-1234-5678\nemail teacher@example.com\nPER_ID=001122\n수강 대상: 학사과정 학생\n선수과목: 회계원리'
        safe,count=education(text)
        self.assertEqual(count,3)
        self.assertNotIn('1234',safe);self.assertNotIn('@',safe)
        self.assertIn('수강 대상',safe);self.assertIn('선수과목',safe)
        self.assertNotIn('PER_ID',CATALOG_FIELDS);self.assertNotIn('EMAIL',FIELDS)
    def test_attachment_association_does_not_invent_current_identity(self):
        result=text_evidence('Course objectives from an unspecified year','BIZ2021','01','Teacher')
        self.assertFalse(result['year2026Present']);self.assertFalse(result['headerCourseCodePresent']);self.assertFalse(result['currentTermPresent'])
    def test_exam_topic_does_not_mean_no_class(self):
        result=text_evidence('Week8 midterm exam; week16 final examination','BIZ2021','01','Teacher')
        self.assertEqual(result['educationalOperatingContexts'],[])
    def test_explicit_past_term_is_preserved_without_book_year_inference(self):
        result=text_evidence('Course Syllabus GBA, Fall 2025. Textbook published 2025.','BUS3042','01','Teacher')
        self.assertEqual(result['explicitAcademicTermMarkers'],['Fall 2025'])
        self.assertTrue(any('Fall 2025' in x for x in result['educationalOperatingContexts']))
    def test_english_month_date_is_kept_without_other_operating_words(self):
        result=text_evidence('Week3 Industry Showcase September14th.','BIZ2031','01','Teacher')
        self.assertTrue(any('September14th' in x for x in result['educationalOperatingContexts']))
    def test_two_threads_share_request_spacing_and_stop_gate(self):
        collector.STOP_REQUESTS.clear();collector.LAST_REQUEST=0;starts=[]
        def start():
            collector.request_start();starts.append(time.monotonic())
        threads=[threading.Thread(target=start) for _ in range(3)]
        for thread in threads:thread.start()
        for thread in threads:thread.join()
        starts.sort()
        self.assertGreaterEqual(starts[1]-starts[0],.79)
        self.assertGreaterEqual(starts[2]-starts[1],.79)
        collector.STOP_REQUESTS.set()
        with self.assertRaises(RuntimeError):collector.request_start()
        collector.STOP_REQUESTS.clear();collector.LAST_REQUEST=0
    def test_html_download_is_not_treated_as_bad_educational_pdf(self):
        class Response:
            status=200
            def read(self):return b'<!DOCTYPE html><html>Access denied</html>'
        class Opener:
            def open(self,*args,**kwargs):return Response()
        public=object.__new__(collector.SpacedPublic);public.op=Opener()
        with patch.object(collector,'request_start'):
            with self.assertRaises(RuntimeError):public.download('https://kingoinfo.skku.edu/actual-public-download')
    def test_access_credential_contexts_are_not_retained_as_education(self):
        text='Wednesday physical class13:30.\nhttps://example.test/class?pwd=fixture-only\nPassword: fixture-only\n수강 대상: 학사과정'
        result=text_evidence(text,'GEC2009','01','Teacher')
        self.assertEqual(result['privacySuppressedLineCount'],2)
        self.assertNotIn('fixture-only',str(result))
        self.assertTrue(any('physical class' in x for x in result['educationalOperatingContexts']))
    def test_encrypted_pdf_is_left_unread(self):
        class ProtectedReader:
            is_encrypted=True
            @property
            def pages(self):raise AssertionError('Protected pages must not be extracted')
        with patch.object(collector,'PdfReader',return_value=ProtectedReader()):
            with self.assertRaises(collector.ProtectedPdfEducationalSource):collector.pdf_evidence(b'fixture-only','GEC2009','01','Teacher')
if __name__=='__main__':unittest.main()
