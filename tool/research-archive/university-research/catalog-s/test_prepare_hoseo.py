import json
from pathlib import Path
import unittest
import prepare_hoseo as importer
ROOT=Path(__file__).parent

class ActualHoseoRows(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw=json.loads((ROOT/'hoseo-current-actual-rows.json').read_text())
        cls.result=importer.prepare(cls.raw,json.loads((ROOT/'hoseo-pdf-course-credit-complete-extraction.json').read_text()),json.loads((ROOT/'hoseo-current-pdf-explicit-campus-rows.json').read_text()),json.loads((ROOT/'hoseo-current-curriculum-credit-join.json').read_text()))
        cls.by={(c['courseCode'],c['section']):c for c in cls.result['courses']}

    def test_current_zero_period_uses_actual_current_clock(self):
        row=self.by['0AEJ1313','01']
        self.assertEqual(row['sourceSchedule'],'수0~2')
        self.assertEqual([(s['weekday'],s['startMinute'],s['endMinute']) for s in row['schedules']],[(3,540,710)])
        self.assertEqual(row['campus'],'asan')

    def test_team_teaching_not_duplicate_course_or_lost_teacher(self):
        row=self.by['0ADI4630','02']
        self.assertEqual(row['professor'],'정재훈 / 최인락')
        self.assertEqual(len(row['sourceOccurrences']),2)
        self.assertEqual(len(row['schedules']),2)

    def test_actual_unpublished_credit_and_attendance_preserved(self):
        row=self.by['0AIT0006','01']
        self.assertIsNone(row['credits'])
        self.assertEqual(row['departmentCredits'],{})
        self.assertEqual(row['campus'],'unknown')
        self.assertEqual(row['sourceSchedule'],'')
        self.assertEqual(row['scheduleStatus'],'unrecognized')
        self.assertEqual(row['schedules'],[])

    def test_remote_source_period_not_invented_as_weekly_attendance(self):
        row=self.by['0ARK6044','92']
        self.assertEqual(row['sourceSchedule'],'수9~10')
        self.assertEqual(row['scheduleStatus'],'unrecognized')
        self.assertEqual(row['schedules'],[])

    def test_all_real_identities_preserved_without_completion_claim(self):
        self.assertEqual(len(self.result['courses']),2499)
        self.assertEqual(len(self.by),2499)
        self.assertFalse(self.result['productionReady'])
        self.assertFalse(self.result['completionClaim'])
        self.assertEqual(len(self.result['audit']['unresolvedCampus']),136)
        self.assertEqual(len(self.result['audit']['missingCredit']),67)

    def test_current_curriculum_exact_code_join_does_not_schedule_counseling(self):
        row=self.by['0APR1139','01']
        self.assertEqual(row['credits'],1.0)
        self.assertIn('current official curriculum',row['creditEvidence'])
        self.assertEqual(row['schedules'],[])

    def test_curriculum_name_mismatch_is_rejected(self):
        with self.assertRaises(ValueError):
            importer.prepare(self.raw,[],[],[{'code':'0APR1139','courseName':'다른과목','credit':1}])

    def test_actual_open_border_code_and_zero_credit_recovered(self):
        row=self.by['0ASA6000','01']
        self.assertEqual(row['credits'],0.0)
        self.assertEqual(row['scheduleStatus'],'unrecognized')
        self.assertEqual(row['schedules'],[])

    def test_actual_merged_pdf_campus_restores_online_allocation(self):
        row=self.by['0AST0019','92']
        self.assertEqual(row['campus'],'asan')
        self.assertEqual(row['schedules'],[])

    def test_partial_source_is_rejected(self):
        with self.assertRaises(ValueError):importer.prepare(self.raw[:-1],[])

if __name__=='__main__':unittest.main()
