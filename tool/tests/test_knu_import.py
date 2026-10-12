import copy
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).parents[2]
SOURCE = ROOT/'work/university-research/catalog-p'
spec = importlib.util.spec_from_file_location('knu', ROOT/'tool/timetable/import_knu.py')
knu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(knu)


class KnuImportTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rows = json.loads((SOURCE/'knu-safe-meeting-candidates.json').read_text())
        cls.aliases = json.loads((SOURCE/'knu-expanded-owner-alias-audit.json').read_text())
        cls.courses, cls.audit = knu.normalize(cls.rows, cls.aliases)
        cls.by_id = {c['courseCode']+'-'+c['section']: c for c in cls.courses}

    def test_whole_scope_and_campus_without_department_inference(self):
        self.assertEqual(self.audit['courseCount'], 3847)
        self.assertEqual(self.audit['campusCounts'], {'daegu':3117,'sangju':497,'dongin':26,'downtown':2,'unassigned':205})
        self.assertEqual(self.by_id['SMMB0220-001']['campus'], 'daegu')
        self.assertEqual(self.by_id['AAAA0901-001']['campus'], 'unassigned')
        self.assertNotIn('TCHR0601-001', self.by_id)
        self.assertNotIn('TCHR0606-001', self.by_id)
        self.assertNotIn('TCHR0528-007', self.by_id)

    def test_owner_and_department_specific_aliases_survive(self):
        c = self.by_id['COMP0454-001']
        self.assertEqual(c['departmentClassifications']['컴퓨터학부 인공지능컴퓨팅전공'], '전공필수')
        self.assertEqual(c['departmentClassifications']['IT 첨단자율학부'], '일반선택')
        self.assertEqual(len(c['sourceAliases']), 4)
        for c in self.courses:
            self.assertEqual(set(c['departments']), set(c['departmentClassifications']))
            self.assertEqual(set(c['departments']), set(c['departmentRemarks']))
            self.assertEqual(set(c['departments']), set(c['departmentCredits']))

    def test_exact_current_dated_proofs_exclude_exam_placeholders(self):
        c = self.by_id['AAAA0912-001']
        self.assertEqual(sorted(m['date'] for m in c['schedules']), ['2026-09-10','2026-09-23','2026-10-08','2026-10-22','2026-11-12','2026-12-03'])
        self.assertEqual(next(m for m in c['schedules'] if m['date']=='2026-09-23')['weekday'], 3)
        self.assertTrue(all(m['startMinute']==1020 and m['endMinute']==1095 for m in c['schedules']))
        self.assertEqual(len(self.by_id['AAAA0901-001']['schedules']), 7)
        self.assertEqual(self.by_id['AAAA0908-001']['schedules'], [])

    def test_unverified_remote_service_intensive_dates_stay_blocked(self):
        for identity in ['CLTR0058-001','CLTR0058-002','AGIN0251-001','CLTR0659-001','PEED0516-001']:
            self.assertEqual(self.by_id[identity]['scheduleStatus'], 'unrecognized')
            self.assertEqual(self.by_id[identity]['schedules'], [])
        self.assertEqual(sum(c['scheduleStatus']=='unrecognized' for c in self.courses), 247)
        self.assertEqual(self.by_id['WELF0485-001']['scheduleStatus'], 'scheduled')

    def test_source_actual_clocks_and_multiroom_not_assigned_by_order(self):
        c = self.by_id['AUTO0351-001']
        self.assertEqual([(m['weekday'],m['startMinute'],m['endMinute']) for m in c['schedules']], [(3,900,990),(1,900,990)])
        self.assertEqual(c['sourceSchedule'], '수 15:00 ~ 16:30,월 15:00 ~ 16:30')
        for c in self.courses:
            self.assertTrue(all(0<=m['startMinute']<m['endMinute']<=1440 for m in c['schedules']))
            self.assertTrue(all(1<=m['weekday']<=7 for m in c['schedules']))

    def test_runtime_copy_keeps_restrictions_without_research_payloads(self):
        source = self.by_id['CLTR0539-001']
        course = knu.runtime_course(source)
        self.assertNotIn('sourceAliases', course)
        self.assertNotIn('sourceOverview', course)
        self.assertNotIn('sourceWeekly', course)
        notes = '\n'.join(course['departmentRemarks'].values())
        self.assertIn('원격강좌', notes)
        self.assertIn('시간표 추가 불가', notes)
        self.assertNotIn('<br>', notes)
        self.assertEqual(course['schedules'], [])

    def test_incomplete_scope_wrong_term_and_invalid_clock_rejected(self):
        with self.assertRaises(ValueError):
            knu.normalize(self.rows[:-1], self.aliases)
        bad = copy.deepcopy(self.rows)
        bad[0]['currentSourceRaw']['estblYear'] = '2025'
        with self.assertRaises(ValueError):
            knu.normalize(bad, self.aliases)
        bad = copy.deepcopy(self.rows)
        bad[0]['meetingCandidates'][0]['start'] = '15:75'
        with self.assertRaises(ValueError):
            knu.normalize(bad, self.aliases)


if __name__ == '__main__':
    unittest.main()
