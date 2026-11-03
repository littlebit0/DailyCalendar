import datetime as dt
import unittest
import prepare_kunsan_review as importer


class ActualKunsanSource(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.result=importer.prepare()
        cls.by={c['courseCode']+'-'+c['section']:c for c in cls.result['courses']}

    def test_whole_scope_and_actual_remote_jst_boundaries(self):
        self.assertEqual(len(self.by),1718)
        self.assertEqual(self.result['counts'],{'scheduled':797,'unrecognized':823,'untimed':98})
        self.assertFalse(self.result['finalActiveScopeVerified'])
        self.assertFalse(self.result['productionReady'])
        self.assertEqual(self.by['116681-01']['scheduleStatus'],'unrecognized')
        self.assertIn('JST',self.by['116681-01']['remarks'])
        self.assertEqual(self.by['114042-01']['scheduleStatus'],'untimed')

    def test_current_numeric_clock_preserves_0910_and_rounds_only_display(self):
        row=importer.parse_numeric_clock('수1 [인문관-1105]')[0]
        self.assertEqual((row['startMinute'],row['originalStartMinute'],row['endMinute']),(540,550,600))
        late=importer.parse_numeric_clock('수10 [인문관-1105]')[0]
        self.assertEqual((late['startMinute'],late['originalStartMinute'],late['endMinute']),(1080,1090,1140))
        with self.assertRaises(ValueError):importer.parse_numeric_clock('수11 [인문관-1105]')
        with self.assertRaises(ValueError):importer.parse_numeric_clock('화① [인문관-1105]')

    def test_actual_multiple_rooms_do_not_share_or_swap_day(self):
        row=next(c for c in self.by.values() if c['courseCode']=='115910')
        self.assertEqual(row['scheduleStatus'],'scheduled')
        early=next(m for m in row['schedules'] if m['date']=='2026-09-01')
        late=next(m for m in row['schedules'] if m['date']=='2026-09-03')
        self.assertEqual((early['classroom'],late['classroom']),('디지털정보관-327','디지털정보관-328'))

    def test_four_source_makeup_days_replace_original_weekdays(self):
        values=importer.ordinary_dates(importer.parse_numeric_clock('금1 [인문관-1105]'))
        dates={m['date']:m for m in values}
        self.assertNotIn('2026-09-25',dates)
        self.assertNotIn('2026-10-09',dates)
        self.assertEqual(dates['2026-12-08']['weekday'],2)
        self.assertEqual(dates['2026-12-09']['weekday'],3)
        self.assertNotIn('2026-12-10',dates)
        for m in values:self.assertEqual(dt.date.fromisoformat(m['date']).isoweekday(),m['weekday'])

    def test_source_intensive_and_missing_campus_not_invented(self):
        row=self.by['116845-01']
        self.assertEqual(row['schedules'],[])
        self.assertIn('집중',row['remarks'])
        self.assertEqual(self.by['112919-01']['campus'],'unknown')
        self.assertEqual(self.by['110172-01']['campus'],'saemangeum')
        self.assertEqual(len(self.by['100394-02']['sourceOccurrences']),2)


if __name__=='__main__':unittest.main()
