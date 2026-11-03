import copy,json,unittest
from pathlib import Path
from prepare_seoultech_whole import specific_weeks,clock,unambiguous_room
ROOT=Path(__file__).parent
class WholeCandidateTest(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.dataset=json.loads((ROOT/'seoultech-main-2026-2.whole-candidate.json').read_text());cls.courses={c['courseCode']+'-'+c['section']:c for c in cls.dataset['courses']}
 def test_whole_current_identity_preserved(self):
  raw=json.loads((ROOT/'seoultech-current-educational-20261008.json').read_text())
  self.assertEqual(set(self.courses),{r['SUBJ_CD']+'-'+r['LECT_NUMB'] for r in raw});self.assertEqual(len(self.courses),1990)
 def test_half_period_and_unresolved_short_clock_not_fabricated(self):
  for k in ['124218-21001','810001-11001','100486-11001']:
   c=self.courses[k];self.assertEqual(c['schedules'],[]);self.assertEqual(c['scheduleStatus'],'unrecognized');self.assertTrue(c['sourceSchedule'])
 def test_vod_and_cancel_dates_not_added(self):
  self.assertEqual(len(self.courses['130141-41001']['schedules']),14)
  for k,dates in [('100766-31009',{'2026-09-25','2026-10-09'}),('193007-21002',{'2026-09-24','2026-10-22','2026-12-10'})]:
   self.assertFalse({m['date'] for m in self.courses[k]['schedules']} & dates)
 def test_restrictions_and_merge_destination_remain(self):
  c=self.courses['111006-11001'];text='\n'.join(c['departmentRemarks'].values());self.assertIn('타교생 제한',text);self.assertIn('타과 제한',text)
  self.assertTrue(any('191056-41016' in x for x in self.courses['191056-41001']['departmentRemarks'].values()))
 def test_only_unambiguous_published_room_is_assigned(self):
  self.assertEqual(unambiguous_room('다산관-316 다산관-316 '),'다산관-316')
  self.assertEqual(unambiguous_room('Techno Cube(테크노 큐브)-405 '),'Techno Cube(테크노 큐브)-405')
  self.assertEqual(unambiguous_room('다산관-314 창학관-137 '),'')
  self.assertEqual(self.courses['111006-11001']['schedules'][0]['classroom'],'다산관-310')
 def test_unpublished_plans_not_deleted(self):
  keys=json.loads((ROOT/'seoultech-current-plan-audit.json').read_text())['unpublished'];self.assertEqual(len(keys),22);self.assertTrue(set(keys)<=self.courses.keys())
 def test_exact_dated_model_boundary_and_modes(self):
  self.assertEqual(self.dataset['schemaVersion'],2)
  for c in self.courses.values():
   dates={m.get('date') is not None for m in c['schedules']};self.assertLessEqual(len(dates),1)
   for m in c['schedules']:
    self.assertGreater(m['endMinute'],m['startMinute'])
    self.assertNotEqual(m.get('deliveryMode'),'video')
if __name__=='__main__':unittest.main()
