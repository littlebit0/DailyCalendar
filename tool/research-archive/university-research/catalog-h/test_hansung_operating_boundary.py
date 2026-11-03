import unittest
import audit_hansung_current_operations as p
class PublicOperationBoundary(unittest.TestCase):
    def test_english_holiday_and_makeup_and_context(self):
        for value in ['No class this week','Holiday','Make-up lesson','recorded video instead of onsite','Online classes','Mid-term exam', '추석 연휴', '한글날', 'Wednesday lecture', 'on-site class', 'field trip', '자율 활동', '영상 수업', '박물관 답사', '수업 없음', '외부 견학', '과제 제출로 출석 대체', 'MAY 15', 'December 17']:
            self.assertIsNotNone(p.SIGNAL.search(value),value)
    def test_contact_and_connection_links_are_not_retained(self):
        value=p.plain('자료 https://example.test/room?password=private teacher@example.test 010-1234-5678')
        self.assertNotIn('private',value);self.assertNotIn('teacher@',value);self.assertNotIn('010-',value)
    def test_fallback_and_wrong_term_never_current(self):
        row={'kwamokcode':'P010182','bunban':'A'}
        self.assertEqual(p.proof({'insertYn':'N'},row)['status'],'currentNotPublished')
        with self.assertRaises(ValueError):p.proof({'insertYn':'Y','data':[{'data_year':'2025','hakgi':'2','kwamok':'P010182','bunban':'A'}]},row)
if __name__=='__main__':unittest.main()
