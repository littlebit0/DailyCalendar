import copy
import importlib.util
import json
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('tuk',Path(__file__).parents[1]/'timetable'/'import_tuk.py')
tuk = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tuk)
FIXTURE = Path(__file__).parent/'fixtures'/'tuk-real-rows.json'


class TukImportTest(unittest.TestCase):
    def setUp(self):
        self.fixture = json.loads(FIXTURE.read_text())
        self.courses, self.audit = tuk.parse_documents(self.fixture['documents'],self.fixture['closures'],2026,'2')

    def course(self,code,section):
        return next(c for c in self.courses if (c['courseCode'],c['section'])==(code,section))

    def test_real_clock_and_per_meeting_rooms(self):
        course = self.course('AAK10079','01')
        self.assertEqual([(s['weekday'],s['startMinute'],s['endMinute'],s['classroom']) for s in course['schedules']],[(1,930,1040,'산융706호'),(3,930,980,'산융204호')])
        shared = self.course('AAK10076','01')
        self.assertEqual([s['classroom'] for s in shared['schedules']],['E동511호','E동511호'])

    def test_cross_listed_design_credits_preserved(self):
        course = self.course('AAE31014','01')
        self.assertEqual(course['credits'],3)
        self.assertGreater(len(course['departments']),1)
        self.assertTrue(any('3(2)' in r for r in course['departmentRemarks'].values()))
        self.assertTrue(any('3(0)' in r for r in course['departmentRemarks'].values()))
        self.assertEqual(sum(c['courseCode']=='AAE31014' and c['section']=='01' for c in self.courses),1)

    def test_extended_code_and_unscheduled_course_retained(self):
        practice = self.course('AFE200003','01')
        self.assertEqual(practice['scheduleStatus'],'unrecognized')
        self.assertEqual(practice['schedules'],[])
        self.assertIn('09:30~20:50',practice['sourceSchedule'])
        online = self.course('AAK4S010','01')
        self.assertEqual(online['scheduleStatus'],'unscheduled')
        self.assertEqual(online['schedules'],[])

    def test_eh_weekly_teaching_is_preserved(self):
        eh = self.course('AAJ32049','01')
        self.assertEqual(eh['scheduleStatus'],'scheduled')
        self.assertTrue(eh['schedules'])
        self.assertTrue(any('소속학과 수강 원칙' in r for r in eh['departmentRemarks'].values()))

    def test_official_closed_section_excluded(self):
        self.assertFalse(any(c['courseCode']=='ACS48012' and c['section']=='01' for c in self.courses))
        self.assertIn(('ACS48012','01'),self.audit['excludedClosedKeys'])

    def test_bad_clock_mapping_and_incomplete_pages_rejected(self):
        for value in ['월[1]09:90~10:20(C동1호)','월[1]10:20~09:30(C동1호)','월[1]09:30~10:20(C동1호,C동2호)']:
            with self.assertRaises(ValueError):tuk.meetings(value)
        broken = copy.deepcopy(self.fixture['documents'])
        broken[0]['tables'][0]['page'] = 2
        with self.assertRaises(ValueError):tuk.parse_documents(broken,self.fixture['closures'],2026,'2')


if __name__=='__main__':
    unittest.main()
