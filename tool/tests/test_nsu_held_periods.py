import copy
import json
import unittest

from tool.timetable.apply_nsu_held_periods import PATH, apply, scheduled_pdf_remarks


class NsuHeldPeriodsTest(unittest.TestCase):
    def test_capstone_row_follows_printed_periods(self):
        data = json.loads(PATH.read_text(encoding='utf-8'))
        course = next(c for c in data['courses']
                      if c['sourceId'] == 'nsu-image102907-g3-d2-p6-bandg3tue-upper-s01')
        self.assertEqual(course['scheduleStatus'], 'scheduled')
        self.assertEqual(course['sourceSchedule'], '2요일 6,7,8,9교시')
        first = course['schedules'][0]
        self.assertEqual((first['weekday'], first['startMinute'], first['endMinute']), (2, 840, 1080))

    def test_row_without_cells_stays_held(self):
        data = json.loads(PATH.read_text(encoding='utf-8'))
        empty = {'scheduleStatus': 'unrecognized', 'schedules': [], 'remarks': '',
                 'publicImageEducation': {'weekday': 1, 'periods': [], 'room': '', 'grade': 1,
                                          'imageBand': 'x', 'professor': ''}}
        data['courses'].append(empty)
        self.assertEqual(apply(data, scheduled_pdf_remarks(data)), 0)
        self.assertEqual((empty['scheduleStatus'], empty['schedules']), ('unrecognized', []))

    def test_rerun_on_asset_changes_nothing(self):
        data = json.loads(PATH.read_text(encoding='utf-8'))
        before = copy.deepcopy(data)
        self.assertEqual(apply(data, scheduled_pdf_remarks(data)), 0)
        self.assertEqual(data, before)


if __name__ == '__main__':
    unittest.main()
