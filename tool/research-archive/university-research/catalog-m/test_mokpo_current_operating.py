import unittest,xml.etree.ElementTree as ET
from mokpo_refresh_operating_plans import sanitize
from review_mokpo_current_operating import review_course,attendance_date_conflicts
from mokpo_redact_operating_contacts import redact
class CurrentOperatingTests(unittest.TestCase):
 def fixture(self,note='',time='월1,2'):
  row={'GYOGWAMOK_CD':'AA139','BUNBAN':'00','BIGO_TIME':'월1,2'}
  main={'YEAR':'2026','HAKGI':'0002','GYOGWAMOK_CD':'AA139','BUNBAN':'00','BIGO_TIME':time,'operatingNoteExcerpts':[note] if note else []}
  return row,{'educationalDatasets':{'ds_out':[main],'ds_out3':[]}}
 def test_current_exact_identity_and_clock_required(self):
  r,d=self.fixture();self.assertEqual(review_course(r,d)['status'],'currentPlanClockConsistentNoSelectedException')
  d['educationalDatasets']['ds_out'][0]['BUNBAN']='01'
  self.assertIn('Current main identity mismatch: BUNBAN',review_course(r,d)['reasons'])
 def test_print_weekday_conflict_never_ordinary_candidate(self):
  r,d=self.fixture(time='화1,2');self.assertIn('Actual public print time conflicts with whole-catalogue time.',review_course(r,d)['reasons'])
 def test_current_header_not_enough_for_actual_stale_holiday_content(self):
  r,d=self.fixture();d['educationalDatasets']['ds_out3']=[{'YEAR':'2026','HAKGI':'0002','GYOGWAMOK_CD':'AA139','BUNBAN':'00','JUCHA':'제10주','operatingContentExcerpts':['MAY 06 NO CLASS (SUBSTITUTE HOLIDAY)']}]
  self.assertEqual(review_course(r,d)['status'],'operatingContextReviewRequired')
 def test_actual_remote_instruction_not_teaching_topic(self):
  r,d=self.fixture(note='금요일은 온라인 수업으로 진행')
  self.assertEqual(review_course(r,d)['findings'][0]['category'],'deliveryOperatingInstruction')
  r,d=self.fixture(note='원격탐사와 보강간섭, 모의수업 동영상 녹화')
  self.assertEqual(review_course(r,d)['findings'],[])
  r,d=self.fixture(note='본 수업은 지상파 TV, 케이블 TV 그리고 온라인에서 방송 가능한 영상콘텐츠를 제작합니다.')
  self.assertEqual(review_course(r,d)['findings'],[])
 def test_assignment_weekday_does_not_change_attendance(self):
  r,d=self.fixture();d['educationalDatasets']['ds_out3']=[{'YEAR':'2026','HAKGI':'0002','GYOGWAMOK_CD':'AA139','BUNBAN':'00','JUCHA':'제8주','operatingAssignmentExcerpts':['일요일 자정까지 제출']}]
  self.assertEqual(review_course(r,d)['status'],'currentPlanClockConsistentNoSelectedException')
 def test_actual_current_operating_weekday_and_old_year_conflicts(self):
  self.assertTrue(any('weekday contradict' in r for r in attendance_date_conflicts('2026년 9월 24일(수) 교외교육 실시')))
  self.assertTrue(any('year differs' in r for r in attendance_date_conflicts('2025년 9월 24일(수) 교외교육 실시')))
  self.assertTrue(any('English operating month' in r for r in attendance_date_conflicts('MAY 06 NO CLASS (SUBSTITUTE HOLIDAY)')))
  self.assertEqual(attendance_date_conflicts('2026년 10월 26일(월) 교외교육 실시'),[])
  self.assertFalse(any('weekday contradict' in r for r in attendance_date_conflicts('2025년 9월 24일(수) ~ 9월 25일(목) 교외교육 실시')))
 def test_incidental_contact_redaction_preserves_actual_dates_times(self):
  result=redact({'note':'문의 teacher@example.test 010-1234-5678 / 061-450-1234; 2026년 10월 26일 18:00 수업'})
  self.assertNotIn('teacher@',result['note']);self.assertNotIn('010-',result['note'])
  self.assertIn('2026년 10월 26일 18:00',result['note'])
  self.assertNotIn('061-450',result['note'])
 def test_privacy_whitelist_discard_staff_profiles_and_other_dataset(self):
  root=ET.fromstring('<Root><Dataset id="ds_out"><Rows><Row><Col id="YEAR">2026</Col><Col id="GYOSU_CD">private-id</Col><Col id="TEL_NO">private-phone</Col><Col id="YEONGUSIL">private-office</Col><Col id="YUUI_SAHANG">본 수업은 원격수업으로 진행합니다.</Col></Row></Rows></Dataset><Dataset id="student_roster"><Rows><Row><Col id="NAME">private-student</Col></Row></Rows></Dataset></Root>')
  result=sanitize(root);self.assertEqual(list(result),['ds_out'])
  self.assertFalse(any(k in result['ds_out'][0] for k in ['GYOSU_CD','TEL_NO','YEONGUSIL']))
  self.assertEqual(len(result['ds_out'][0]['operatingNoteExcerpts']),1)
if __name__=='__main__':unittest.main()
