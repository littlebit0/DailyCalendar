import unittest
from prepare_mokpo_time_review import prepare,parse_clock
class CurrentTimeReviewTests(unittest.TestCase):
    def test_real_split_days_and_halfhour_boundaries(self):
        rows=prepare()['courses'];r=next(r for r in rows if r['courseCode']=='AA139' and r['section']=='00')
        self.assertEqual(r['sourceTime'],'월10,11,12 수13,14,15')
        self.assertEqual([(s['weekday'],s['startMinute'],s['endMinute']) for s in r['clockReview']],[(1,810,900),(3,900,990)])
    def test_gaps_stay_separate_and_invalid_period_rejected(self):
        self.assertEqual(len(parse_clock('월1,2,4,5')),2)
        for raw in ['월27','월1,1','월1 오전수3','월0']:
            with self.assertRaises(ValueError):parse_clock(raw)
    def test_clinical_placeholders_never_become_dated_meetings(self):
        result=prepare();r=next(r for r in result['courses'] if r['courseCode']=='HF241' and r['section']=='01')
        self.assertEqual(r['reviewStatus'],'unrecognized');self.assertEqual(r['actualDatedMeetings'],[])
        self.assertTrue(r['individualBlockedReasons']);self.assertFalse(result['productionReady'])
    def test_complete_scope_and_missing_time_retention(self):
        result=prepare();self.assertEqual(len(result['courses']),1307)
        self.assertEqual(result['counts'],{'clockReviewed':1176,'unrecognized':98,'explicitOcuUntimed':27,'explicitOnlineUntimed':6})
        self.assertEqual(sum(not r['sourceTime'] for r in result['courses']),84)
        self.assertFalse(any(r['courseCode']=='ZAA006' or r['departmentCode']=='DY050' for r in result['courses']))
    def test_actual_grade2_grid_reconciled_but_clinical_and_dates_stay_pending(self):
        result=prepare();rows=result['courses']
        r=next(r for r in rows if r['courseCode']=='NSS014' and r['section']=='02')
        self.assertEqual(r['reviewStatus'],'clockReviewed')
        self.assertEqual(r['clockReview'][0]['startMinute'],540)
        self.assertEqual(r['clockReview'][0]['endMinute'],720)
        self.assertEqual(r['actualDatedMeetings'],[])
        window=result['ordinaryRecurrenceWindow']
        self.assertEqual(window['endInclusive'],'2026-12-07')
        self.assertEqual(window['arbitraryNationalHolidayRemovals'],[])
    def test_direct_online_evidence_does_not_invent_attendance_times(self):
        rows=prepare()['courses']
        r=next(r for r in rows if r['courseCode']=='ZBE132')
        self.assertEqual(r['reviewStatus'],'explicitOnlineUntimed')
        self.assertEqual(r['clockReview'],[])
        ambiguous=next(r for r in rows if r['courseCode']=='COP041')
        self.assertEqual(ambiguous['reviewStatus'],'unrecognized')
if __name__=='__main__':unittest.main()
