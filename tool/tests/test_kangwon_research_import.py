import copy
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).parents[2]
RESEARCH = ROOT/'work/university-research/catalog-q'
spec = importlib.util.spec_from_file_location('kangwon', RESEARCH/'normalize_kangwon_candidate.py')
kangwon = importlib.util.module_from_spec(spec)
spec.loader.exec_module(kangwon)


class KangwonResearchImportTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rows = json.loads((RESEARCH/'kangwon-current-whole-source-rows.json').read_text())
        cls.courses, cls.unresolved = kangwon.normalize(cls.rows)
        cls.by_id = {(c['campus'],c['courseCode'],c['section']):c for c in cls.courses}

    def test_complete_five_campus_scope_and_explicit_closures(self):
        self.assertEqual(len(self.courses),5761)
        self.assertEqual(len(self.by_id),5761)
        for row in self.rows:
            self.assertEqual((row['campus'],row['code'],row['section']) in self.by_id, not row['closed'])

    def test_nested_classroom_parentheses_and_real_period_clocks(self):
        row=next(r for r in self.rows if not r['closed'] and r['campus']=='chuncheon' and '율곡관(기숙사)식당동 004' in r['sourceSchedule'])
        c=self.by_id[(row['campus'],row['code'],row['section'])]
        self.assertEqual(c['schedules'][0]['classroom'],'율곡관(기숙사)식당동 004')
        self.assertEqual((c['schedules'][0]['startMinute'],c['schedules'][0]['endMinute']),(540,710))
        row=next(r for r in self.rows if not r['closed'] and r['campus']=='gangneung' and r['code']=='61100015')
        c=self.by_id[(row['campus'],row['code'],row['section'])]
        self.assertEqual([(m['weekday'],m['startMinute'],m['endMinute']) for m in c['schedules']],[(2,630,705),(3,900,975)])

    def test_unverified_15_and_evening_75minute_periods_not_extrapolated(self):
        for key in [('gangneung','22405000','01'),('wonju','71500008','01'),('dogye','53100095','1')]:
            self.assertEqual(self.by_id[key]['scheduleStatus'],'unrecognized')
            self.assertEqual(self.by_id[key]['schedules'],[])

    def test_remote_exam_slots_do_not_become_weekly_meetings(self):
        remote=[r for r in self.rows if not r['closed'] and r['remote']]
        self.assertEqual(len(remote),395)
        for row in remote:
            c=self.by_id[(row['campus'],row['code'],row['section'])]
            self.assertEqual(c['schedules'],[])
            self.assertEqual(c['sourceSchedule'],row['sourceSchedule'])

    def test_service_actual_two_hour_activity_and_short_period(self):
        c=self.by_id[('gangneung','14207025','A0')]
        self.assertEqual(c['period'],{'startDate':'2026-09-14','endDate':'2026-12-04'})
        self.assertEqual([(m['weekday'],m['startMinute'],m['endMinute']) for m in c['schedules']],[(2,660,780)])
        self.assertEqual(c['schedules'][0]['classroom'], '')
        self.assertEqual(c['sourceClassroom'], 'C3-501')
        self.assertIn('봉사기관: 강릉시자원봉사센터', '\n'.join(c['departmentRemarks'].values()))
        c=self.by_id[('wonju','14207025','a5')]
        self.assertEqual([(m['weekday'],m['startMinute'],m['endMinute']) for m in c['schedules']],[(1,1020,1140)])
        for section in ['01','02']:
            c=next(c for c in self.courses if c['courseCode']=='14207025' and c['section']==section)
            self.assertEqual(c['schedules'],[])
        service=[c for c in self.courses if c['courseCode']=='14207025' and c['schedules']]
        self.assertEqual(len(service),135)

    def test_incomplete_or_duplicate_whole_scope_rejected(self):
        with self.assertRaises(ValueError):kangwon.normalize(self.rows[:-1])
        bad=copy.deepcopy(self.rows);bad[-1]=bad[0]
        with self.assertRaises(ValueError):kangwon.normalize(bad)
        with self.assertRaises(ValueError):kangwon.parse_groups('수15',False,'')
        with self.assertRaises(ValueError):kangwon.parse_groups('수A7',False,'')


if __name__=='__main__':unittest.main()
