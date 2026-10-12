import copy
import json
from pathlib import Path
import unittest

from tool.timetable.import_hknu import clocks, parse_records


class HknuActualPublicationTest(unittest.TestCase):
    def setUp(self):
        self.payload=json.loads((Path(__file__).parent/'fixtures/hknu-real-rows.json').read_text())
        self.counts={c:len(r) for c,r in self.payload['campuses'].items()}

    def test_actual_department_identity_prevents_counseling_merge(self):
        courses,audit=parse_records(self.payload,self.counts)
        counseling=[c for c in courses if c['courseName']=='인성교육및상담24']
        self.assertEqual(len(counseling),3)
        self.assertEqual(len({c['sourceId'] for c in counseling}),3)
        self.assertTrue(all(c['schedules']==[] and c['scheduleStatus']=='unscheduled' for c in counseling))
        self.assertEqual(len(audit['counseling']),3)

    def test_actual_day_range_and_original_leading_zero_code(self):
        courses,_=parse_records(self.payload,self.counts)
        first=courses[0]
        self.assertEqual(first['courseCode'],'1000430035')
        self.assertEqual(first['schedules'][0]['startMinute'],540)
        self.assertEqual(first['schedules'][0]['endMinute'],720)
        self.assertTrue(any(c['courseCode'].startswith('0000') for c in courses))

    def test_night_verified_exact_range_and_unverified_fraction(self):
        actual,_=clocks('(월) 13~15.5','')
        self.assertEqual((actual[0]['startMinute'],actual[0]['endMinute']),(1220,1360))
        self.assertEqual(clocks('(수) 10~12.5','')[0],[])
        # A partially understood multi-day course is never partially imported.
        self.assertEqual(clocks('(월) 1~3.5 / (수) 10~12.5','')[0],[])

    def test_field_practice_does_not_repeat_entire_semester(self):
        courses,_=parse_records(self.payload,self.counts)
        field=[c for c in courses if '현장실습' in c['courseName']]
        self.assertEqual(len(field),2)
        self.assertTrue(all(c['schedules']==[] and c['sourceSchedule'] and c['scheduleStatus']=='unrecognized' for c in field))

    def test_wrong_term_and_incomplete_scope_rejected(self):
        bad=copy.deepcopy(self.payload);bad['semester']='1'
        with self.assertRaises(ValueError):parse_records(bad,self.counts)
        bad=copy.deepcopy(self.payload);bad['campuses'].pop('pyeongtaek')
        with self.assertRaises(ValueError):parse_records(bad,self.counts)

    def test_actual_identity_cannot_be_silently_duplicated(self):
        bad=copy.deepcopy(self.payload)
        bad['campuses']['anseong'][1]=copy.deepcopy(bad['campuses']['anseong'][0])
        with self.assertRaises(ValueError):parse_records(bad,self.counts)


if __name__=='__main__':
    unittest.main()
