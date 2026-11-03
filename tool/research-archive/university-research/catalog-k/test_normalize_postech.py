import json,unittest
from normalize_postech import ROOT,normalize,meetings
class PublishedPostechFixtureTests(unittest.TestCase):
 def test_complete_current_public_scope_and_metadata(self):
  rows=normalize(json.loads((ROOT/'postech-2026-2-undergraduate.json').read_text()))
  self.assertEqual(len(rows),418);self.assertEqual(len({x['sourceId'] for x in rows}),418)
  self.assertEqual(sum(x['scheduleStatus']=='unscheduled' for x in rows),70)
  self.assertEqual(sum(x['scheduleStatus']=='unrecognized' for x in rows),2)
  self.assertTrue(all(x['departments'] and x['credits'] is not None for x in rows))
 def test_multi_weekdays_actual_clock_and_room(self):
  parsed,status=meetings('월, 수 / 09:30 ~ 10:45','제4공학관 세미나실 [302/304호]')
  self.assertEqual(status,'scheduled');self.assertEqual([x['weekday'] for x in parsed],[1,3])
  self.assertTrue(all(x['startMinute']==570 and x['endMinute']==645 for x in parsed))
 def test_identical_time_and_room_duplicates_only(self):
  parsed,status=meetings('월 / 09:30 ~ 10:45\n월 / 09:30 ~ 10:45','104호\n104호')
  self.assertEqual(len(parsed),1)
  parsed,status=meetings('월 / 09:30 ~ 10:45\n월 / 09:30 ~ 10:45','104호\n105호')
  self.assertEqual(len(parsed),2)
 def test_ambiguous_partial_room_rows_not_invented(self):
  self.assertEqual(meetings('월 / 17:00 ~ 17:50\n월 / 19:00 ~ 22:20 /','LG102'),([], 'unrecognized'))
 def test_missing_schedule_does_not_make_recurrence(self):
  self.assertEqual(meetings('',''),([], 'unscheduled'))
 def test_invalid_published_clock_rejected(self):
  with self.assertRaises(ValueError):meetings('월 / 17:60 ~ 18:50','104호')
  with self.assertRaises(AssertionError):meetings('월 / 19:00 ~ 17:50','104호')
 def test_research_exceptions_cannot_be_repeated_as_regular_classes(self):
  data=json.loads((ROOT/'postech-final-research-candidates.json').read_text())
  by={(x['code'],x['section']):x for x in data['courses']}
  self.assertEqual(by[('CSED199','01')]['candidateMode'],'individualResearchNotSemesterRecurrence')
  self.assertEqual(by[('MATH199','01')]['candidateMode'],'individualResearchNotSemesterRecurrence')
  self.assertEqual(by[('CHEB207','01')]['candidateMode'],'regularPlusConditionalTuesdaySlot')
  self.assertEqual(len(data['courses']),418)
  self.assertTrue(all(not x['activationReady'] for x in data['courses']))
 def test_partial_clock_and_planned_presentation_never_get_invented_end_time(self):
  data=json.loads((ROOT/'postech-dated-and-partial-clock-evidence.json').read_text())
  intro,planned,partial=data
  self.assertEqual(intro['date'],'2026-09-10')
  self.assertEqual((intro['startMinute'],intro['endMinute']),(1020,1070))
  self.assertIsNone(planned['endMinute']);self.assertIsNone(planned['generatedMeeting'])
  self.assertIsNone(partial['date']);self.assertIsNone(partial['endMinute'])
 def test_source_holiday_and_attendance_policy_are_distinguished(self):
  data=json.loads((ROOT/'postech-operating-exceptions-manual-review.json').read_text())
  by={(x['code'],x['section']):x for x in data['reviews']}
  self.assertEqual(len(by),35)
  self.assertEqual(by[('CMST409','01')]['explicitNoClassDates'],[])
  self.assertEqual(by[('CMST410','01')]['explicitNoClassDates'],['2026-10-05','2026-10-28','2026-12-23'])
  self.assertEqual(by[('MATH102','06')]['publishedNoClassWeeksWithoutGeneratedDates'],[6])
  self.assertEqual(by[('MATH102','06')]['explicitNoClassDates'],[])
if __name__=='__main__':unittest.main()
