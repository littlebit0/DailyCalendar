import unittest
from pathlib import Path
from khu_educational_plan import educational_page

class EducationalExtraction(unittest.TestCase):
 def test_all_actual_teaching_method_tables_retained(self):
  source=Path(__file__).resolve().parent.parent/'catalogs/khu-PSC3064-plan.html'
  headers,sections=educational_page(source.read_text())
  self.assertTrue(any('2026학년도 2학기' in h for h in headers))
  method=next(s['rows'] for s in sections if s['section']=='수업유형 및 방법')
  self.assertGreater(len(method),3)
  text=str(sections)
  self.assertNotIn('오비스홀 558호',text)
  self.assertNotIn('면담시간',text)
  self.assertIn('시민참여',text)
 def test_literal_book_titles_and_source_notes_survive(self):
  body='<h1>2026학년도 2학기 강의계획서</h1><h2>선수과목</h2><table><tr><td>교재 <NGO연구> (1) 또는 선형대수</td></tr></table><table><tr><td>한글날 수업 없음, https://example.org/private?token=abc 연락 010-1234-5678 mail@example.org</td></tr></table>'
  _,sections=educational_page(body);text=str(sections)
  self.assertIn('<NGO연구>',text)
  self.assertIn('(1) 또는 선형대수',text)
  self.assertIn('한글날 수업 없음',text)
  self.assertNotIn('token=abc',text)
  self.assertNotIn('010-1234-5678',text)
  self.assertNotIn('mail@example.org',text)

if __name__=='__main__':unittest.main()
