import json
import unittest
import prepare_baekseok as importer


class ActualBaekseokRows(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        root = importer.ROOT
        cls.raw = json.loads((root/'bu-all-published-code-rows.json').read_text())
        cls.closure = json.loads((root/'bu-exact-closure-audit.json').read_text())
        cls.changes = json.loads((root/'bu-current-exact-time-changes.json').read_text())
        cls.result = importer.prepare(cls.raw, cls.closure, cls.changes)
        cls.by = {r['publishedCombinedCode']: r for r in cls.result['courses']}

    def test_real_code_boundary_and_exact_closures(self):
        self.assertEqual(len(self.by), 2571)
        self.assertNotIn('3206508', self.by)
        row = self.by['0367404']
        self.assertEqual((row['courseCode'], row['section']), ('03674', '04'))
        self.assertEqual(len(self.result['audit']['closedPresent']), 52)
        self.assertEqual(len(self.result['audit']['closedNotInInitialSource']), 3)

    def test_all_published_exact_time_changes_preserved_without_clock_guess(self):
        self.assertEqual(self.by['0367404']['sourceSchedule'], '목5,6,7/사')
        self.assertEqual(self.by['0924501']['sourceSchedule'], '월6,7')
        self.assertEqual(self.by['3197601']['sourceSchedule'], '수2,3/사')
        for code in ['0367404', '0924501', '3197601']:
            self.assertEqual(self.by[code]['schedules'], [])

    def test_repeated_exchange_aliases_and_current_credit_are_preserved(self):
        self.assertEqual(len(self.by['3213301']['sourceNames']), 2)
        self.assertEqual(self.by['0986302']['credits'], 2.0)
        self.assertEqual(self.result['audit']['missingCredit'], [])

    def test_no_current_clock_campus_or_final_active_claim(self):
        self.assertFalse(self.result['productionReady'])
        self.assertFalse(self.result['countIsFinalActiveCount'])
        self.assertTrue(all(r['campus'] in {'cheonan', 'unknown'} and r['schedules'] == [] for r in self.by.values()))

    def test_official_dates_preserve_substitute_day_and_omit_video_attendance(self):
        import datetime
        dates = json.loads((importer.ROOT/'bu-current-official-teaching-date-records.json').read_text())
        friday = [r for r in dates['records'] if r['sourceWeekday'] == 5]
        self.assertEqual(len(friday), 15)
        self.assertEqual([(r['date'], r['weekday']) for r in friday if r['kind'] == '지정보강일'],
                         [('2026-12-08', 2), ('2026-12-09', 3)])
        row = self.by['0924501']
        actual = row['currentSemesterActualDateReviewMeetings']
        self.assertEqual(len(actual), 14)
        self.assertNotIn('2026-10-19', {m['date'] for m in actual})
        self.assertNotIn('2026-10-05', {m['date'] for m in actual})
        self.assertTrue(all(datetime.date.fromisoformat(m['date']).isoweekday() == m['weekday'] for m in actual))
        self.assertEqual(importer.current_undergraduate_clock_candidates('월9', '')[0]['endMinute'], 1070)
        self.assertEqual(row['schedules'], [])

    def test_current_teacher_changes_use_matching_real_identity(self):
        self.assertEqual(self.by['3157401']['professor'], '이범오')
        self.assertEqual(self.by['3149301']['professor'], '박영우')
        self.assertEqual(len(self.result['audit']['professorChangesApplied']), 7)
        self.assertEqual(self.by['3187202']['professor'], '허연숙')
        self.assertEqual(self.by['3187203']['professor'], '이미애 홍수민')
        self.assertEqual(len(self.result['audit']['facultyChangesValidated']), 4)
        self.assertIn('전공 미결정자', self.by['3187205']['departmentRemarks']['자유전공학부'])
        self.assertEqual(self.by['0729401']['departments'], ['문화예술학부'])
        self.assertIn('문화예술교육사', self.by['0729401']['departmentRemarks']['문화예술학부'])

    def test_additional_current_codes_keep_actual_fields_without_invented_schedule(self):
        self.assertEqual(len(self.result['audit']['additionalPublishedIdentities']), 10)
        row = self.by['3175801']
        self.assertEqual(row['credits'], 0.5)
        self.assertEqual(row['departmentClassifications'], {'교양대학': '교양'})
        self.assertEqual(row['professor'], '장지연\n박현옥')
        self.assertEqual(row['sourceSchedule'], '')
        self.assertEqual(row['schedules'], [])
        self.assertEqual(self.by['3166303']['professor'], '이미애\n홍수민')

    def test_only_published_building_location_resolves_campus(self):
        row = self.by['0854431']
        self.assertEqual(row['campus'], 'cheonan')
        self.assertIn('충청남도 천안시', row['campusEvidence']['officialAddress'])
        self.assertEqual(importer.actual_campus_for_room('별도, 진리'), ('unknown', None))
        self.assertEqual(self.by['3175801']['campus'], 'unknown')

    def test_changed_source_scope_is_rejected(self):
        with self.assertRaises(ValueError):
            importer.prepare(self.raw[:-1], self.closure, self.changes)

    def test_current_year_actual_ug_clock_is_only_a_review_candidate(self):
        row = self.by['0924501']
        self.assertEqual([(m['weekday'], m['startMinute'], m['endMinute']) for m in row['currentYearClockReviewMeetings']], [(1, 840, 950)])
        self.assertEqual(row['schedules'], [])
        self.assertEqual(importer.current_undergraduate_clock_candidates('월10', '진리311'), [])
        self.assertEqual(importer.current_undergraduate_clock_candidates('사', ''), [])
        self.assertEqual(importer.current_undergraduate_clock_candidates('수2,3/사', '본부315')[0]['startMinute'], 600)


if __name__ == '__main__':
    unittest.main()
