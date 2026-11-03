import datetime
import json
import unittest
import normalize_baekseok_review as importer


class DatedBaekseokReview(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = json.loads((importer.ROOT/'bu-current-whole-candidate-unregistered.json').read_text())
        cls.result = importer.normalize(source)
        cls.by = {r['courseCode'] + r['section']: r for r in cls.result['courses']}

    def test_actual_dates_and_video_replacement_cannot_become_weekly(self):
        row = self.by['0924501']
        self.assertEqual(row['scheduleStatus'], 'scheduled')
        self.assertEqual(len(row['schedules']), 14)
        for meeting in row['schedules']:
            date = datetime.date.fromisoformat(meeting['date'])
            self.assertEqual(date.isoweekday(), meeting['weekday'])
            self.assertFalse(datetime.date(2026, 10, 15) <= date <= datetime.date(2026, 10, 21))
            self.assertEqual(meeting['endMinute'] % 30, 0)
        self.assertEqual(row['schedules'][0]['originalEndMinute'], 950)

    def test_friday_substitute_uses_real_tuesday_and_wednesday_dates(self):
        friday = self.by['0760901']
        actual = {(m['date'], m['weekday']) for m in friday['schedules']}
        self.assertIn(('2026-12-08', 2), actual)
        self.assertIn(('2026-12-09', 3), actual)

    def test_actual_comma_weekday_components_keep_both_days(self):
        row = next(r for r in self.by.values() if r['sourceSchedule'] == '화3, 목8')
        self.assertEqual(row['scheduleStatus'], 'scheduled')
        self.assertEqual({m['startMinute'] for m in row['schedules']}, {660, 960})
        self.assertGreater(len(row['schedules']), 20)

    def test_source_only_intensive_and_unknown_period_remain_blocked(self):
        for code in ['3166303', '3175801', '0913802', '3206501', '3019801']:
            self.assertEqual(self.by[code]['scheduleStatus'], 'unrecognized')
            self.assertEqual(self.by[code]['schedules'], [])
        self.assertIn('13~15주차', self.by['3206501']['remarks'])

    def test_full_metadata_preserved_without_complete_support_claim(self):
        self.assertEqual(len(self.by), 2571)
        self.assertFalse(self.result['finalActiveScopeVerified'])
        self.assertFalse(self.result['finalRoomChangesVerified'])
        self.assertFalse(self.result['productionReady'])
        self.assertNotIn('3206508', self.by)
        self.assertEqual(self.by['0854431']['campus'], 'cheonan')
        self.assertEqual(self.by['3175801']['credits'], 0.5)
        self.assertNotIn('sourceOccurrences', self.by['0854431'])


if __name__ == '__main__':
    unittest.main()
