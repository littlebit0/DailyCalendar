import json
import unittest
from pathlib import Path
from prepare_jeju_educational_review import ROOT, prepare


class JejuEducationalReviewTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.result, cls.audit = prepare()
        cls.courses = {c['enrollmentNumber']: c for c in cls.result['courses']}

    def test_whole_education_equality_and_no_fake_identifiers(self):
        source = json.loads((ROOT / 'jeju-2026-2-all-20260729.xls.json').read_text())[0]['rows'][6:]
        self.assertEqual(len(source), 3095)
        self.assertEqual(len(self.courses), 3095)
        for row in source:
            course = self.courses[str(row[6])]
            for field, index in [('department', 1), ('grade', 2), ('classification', 3), ('area', 4), ('title', 7), ('liberalAdminDepartment', 8), ('rawOperatingMethod', 9), ('credits', 10), ('hours', 11), ('professor', 12), ('rawTimeAndRoom', 13)]:
                self.assertEqual(course[field], row[index], (course['enrollmentNumber'], field))
            self.assertIsNone(course['section'])
            self.assertIsNone(course['campus'])
            self.assertEqual(course['meetings'], [])
            self.assertFalse(course['currentActiveStatusVerified'])
            self.assertNotIn('applicationCount', course)
            self.assertNotIn('capacity', course)
        self.assertIsNone(self.courses['KN0001']['subjectCode'])
        self.assertFalse(self.result['productionReady'])

    def test_restriction_summary_is_not_course_and_dates_are_not_attendance(self):
        self.assertEqual(self.audit['explicitRestrictionEnrollmentNumbers'], 531)
        self.assertEqual(self.audit['exactEnrollmentTitleCodeVerified'], 531)
        self.assertEqual(self.audit['excludedSummaryRows'], 1)
        self.assertEqual(self.audit['unmatchedRestrictionNumbers'], [])
        self.assertEqual(self.audit['codeJoinConflicts'], [])
        course = self.courses['009019']
        self.assertEqual(course['subjectCode'], 'GN110414')
        self.assertEqual(len(course['enrollmentRestrictions']), 2)
        self.assertEqual(course['enrollmentRestrictions'][0]['enrollmentRestrictionStartDate'], '2026-07-28')
        self.assertEqual(course['meetings'], [])

    def test_remote_exam_reservation_not_weekly_class(self):
        self.assertEqual(self.courses['KN0001']['operatingReview'], 'remote-actual-attendance-or-assessment-review')
        self.assertIn('토5', self.courses['KN0001']['rawTimeAndRoom'])
        for course in self.courses.values():
            if course['operatingReview'] in ['remote-actual-attendance-or-assessment-review', 'blended-attendance-period-review']:
                self.assertEqual(course['meetings'], [])
        self.assertEqual(sum(self.audit['operatingReviewCounts'].values()), 3095)
        self.assertEqual(self.audit['operatingReviewCounts']['published-timetable-error'], 14)
        self.assertEqual(self.audit['operatingReviewCounts']['published-time-unavailable'], 935)


if __name__ == '__main__':
    unittest.main()
