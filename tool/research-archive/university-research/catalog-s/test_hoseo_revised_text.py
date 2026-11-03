import unittest
import audit_hoseo_revised_text as importer


class ActualRevisedHoseoText(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text=(importer.ROOT/'hoseo-current-revised-pdf1-dart-extractor.txt').read_text()
        cls.result=importer.audit(cls.text)

    def test_actual_month_scope_and_split_february_dates(self):
        self.assertEqual(len(self.result['monthScope']),15)
        self.assertEqual(self.result['normalEventCount'],53)
        self.assertEqual(self.result['normal2026EventCount'],43)
        feb=[r for r in self.result['rows'] if r['title']=='1학기 수강신청 기간' and r['startDate'].startswith('2026')]
        self.assertEqual([(r['startDate'],r['endDateInclusive']) for r in feb],[('2026-02-06','2026-02-06'),('2026-02-09','2026-02-12')])

    def test_actual_current_three_changes_and_footnote_position(self):
        rows=self.result['rows']
        current=next(r for r in rows if r['title']=='1학기 수강신청 기간' and r['startDate'].startswith('2027'))
        self.assertEqual((current['startDate'],current['endDateInclusive']),('2027-02-11','2027-02-17'))
        transfer=next(r for r in rows if r['title']=='편입생/재입학생 수강신청 기간' and r['startDate'].startswith('2027'))
        self.assertEqual((transfer['startDate'],transfer['endDateInclusive']),('2027-02-23','2027-02-23'))
        interview=next(r for r in self.result['holidayFootnotes'] if r['title']=='수시면접일')
        self.assertEqual(interview['sourceDate'],'2026.10.23.(금)')
        self.assertEqual(interview['page'],2)
        self.assertEqual(self.result['holidayCount'],9)

    def test_missing_current_month_is_rejected(self):
        with self.assertRaises(ValueError):
            importer.audit(self.text.replace('\n10\n','\n'))


if __name__=='__main__': unittest.main()
