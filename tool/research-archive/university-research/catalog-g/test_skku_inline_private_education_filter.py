import unittest
from skku_inline_private_education_filter import filter_education
class InlineEducationBoundary(unittest.TestCase):
 def test_one_line_contact_keeps_adjacent_enrolment_restriction_and_actual_no_class(self):
  safe,masked,lost=filter_education('수강 대상: 원전공생만 수강 가능 email teacher@example.test 연락처010-1234-5678 Week8 No class; 선수과목: 회계원리')
  self.assertEqual(masked,2);self.assertEqual(lost,0)
  self.assertIn('원전공생만 수강 가능',safe);self.assertIn('Week8 No class',safe);self.assertIn('회계원리',safe)
  self.assertNotIn('@',safe);self.assertNotIn('1234',safe);self.assertNotIn('teacher',safe)
 def test_internal_identifiers_and_url_credentials_do_not_survive(self):
  safe,masked,lost=filter_education('PER_ID=001122 선수과목: 미적분\nhttps://example.test/class?pwd=fixture-only\nWednesday13:30 physical class')
  self.assertEqual(masked,2);self.assertEqual(lost,0)
  self.assertNotIn('001122',safe);self.assertNotIn('fixture-only',safe);self.assertIn('미적분',safe)
 def test_ambiguous_credentials_or_broken_email_remain_blocked(self):
  safe,masked,lost=filter_education('Password: fixture only secret\nteacher @ invalid\n수강 대상: 학사')
  self.assertEqual(lost,2);self.assertNotIn('secret',safe);self.assertNotIn('teacher',safe);self.assertIn('학사',safe)
 def test_phone_usage_policy_is_educational_without_personal_contact(self):
  safe,masked,lost=filter_education('No mobile Phone during exam; Email submission required.')
  self.assertEqual(masked,0);self.assertEqual(lost,0);self.assertIn('during exam',safe)
 def test_contact_extension_removed_without_discarding_course_clock(self):
  safe,masked,lost=filter_education('Phone: #1234 수강대상: 학부; 수업 13:30-14:45; 내선 5678')
  self.assertEqual(masked,2);self.assertEqual(lost,0)
  self.assertNotIn('1234',safe);self.assertNotIn('5678',safe);self.assertIn('13:30-14:45',safe);self.assertIn('학부',safe)
 def test_area_code_omitted_phone_is_removed_but_classroom_and_dates_are_kept(self):
  safe,masked,lost=filter_education('Phone: 123-4567; Class room: 31401; Class 09:00-10:15; Exam9/24')
  self.assertEqual(masked,1);self.assertEqual(lost,0);self.assertNotIn('123-4567',safe)
  self.assertIn('31401',safe);self.assertIn('09:00-10:15',safe);self.assertIn('9/24',safe)
 def test_pdf_control_characters_cannot_hide_contact_tokens(self):
  safe,masked,lost=filter_education('Phone: \x00123-4567; p\x00erson@example.test; 수강 대상: 학부')
  self.assertEqual(masked,2);self.assertEqual(lost,0)
  self.assertNotIn('123',safe);self.assertNotIn('@',safe);self.assertIn('학부',safe)
 def test_parenthesized_area_and_unicode_dash_keep_education(self):
  safe,masked,lost=filter_education('전화: 02) 123 – 4567; Tel (031) 1234—5678; 수강대상: 경영; 목13:30-14:45; 강의실31401')
  self.assertEqual(masked,2);self.assertEqual(lost,0)
  self.assertNotIn('4567',safe);self.assertNotIn('5678',safe)
  self.assertIn('수강대상: 경영',safe);self.assertIn('목13:30-14:45',safe);self.assertIn('강의실31401',safe)
 def test_described_folder_password_removed_without_dropping_education(self):
  safe,masked,lost=filter_education('Online folder password to open any class file: fixture-key 수강대상: 학부; Thu13:30-14:45')
  self.assertEqual(masked,1);self.assertEqual(lost,0)
  self.assertNotIn('fixture-key',safe);self.assertIn('수강대상: 학부',safe);self.assertIn('Thu13:30-14:45',safe)
if __name__=='__main__':unittest.main()
