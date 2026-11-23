import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('import_pcu', ROOT / 'tool/timetable/import_pcu.py')
pcu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pcu)


def spans(text, room='AM108'):
    return [(m['weekday'], m['startMinute'], m['endMinute'], m['classroom'])
            for m in pcu.meetings(pcu.slots_std(text), room)]


class ImportPcuTests(unittest.TestCase):
    def test_numeric_periods_are_sixty_minute_slots_including_the_break(self):
        self.assertEqual(spans('금5'), [(5, 780, 840, 'AM108')])
        self.assertEqual(spans('월1,월2,월3'), [(1, 540, 720, 'AM108')])

    def test_letter_periods_run_to_the_next_period_start(self):
        self.assertEqual(spans('월A'), [(1, 570, 660, 'AM108')])
        self.assertEqual(spans('월Z'), [(1, 490, 570, 'AM108')])
        self.assertEqual(spans('월H'), [(1, 1260, 1350, 'AM108')])

    def test_consecutive_letter_periods_merge_into_one_block(self):
        self.assertEqual(spans('월A,월B'), [(1, 570, 750, 'AM108')])

    def test_blocks_merge_only_for_the_same_day_and_room(self):
        self.assertEqual(len(spans('월A,화B')), 2)
        shared = pcu.meetings([(1, 'A', 'P408'), (1, 'B', 'P409')], '')
        self.assertEqual(len(shared), 2)
        far = spans('월1,월5')
        self.assertEqual(far, [(1, 540, 600, 'AM108'), (1, 780, 840, 'AM108')])

    def test_a_token_without_weekday_takes_the_previous_weekday(self):
        self.assertEqual(spans('수D,E'), [(3, 900, 1080, 'AM108')])
        self.assertEqual(spans('목5,6'), [(4, 780, 900, 'AM108')])
        self.assertIsNone(pcu.slots_std('D,수E'))

    def test_period_14_continues_the_sixty_minute_slot(self):
        self.assertEqual(spans('월13,월14'), [(1, 1260, 1380, 'AM108')])

    def test_online_listing_does_not_block_another_listings_period(self):
        online = {'time': '온라인', 'room': '온라인'}
        timed = {'time': '월Z,화Z', 'room': 'MC314'}
        self.assertEqual(pcu.decide([online, timed])[0], 'scheduled')
        self.assertEqual(pcu.decide([{'time': '월C,목B', 'room': 'Y'}, {'time': '목B', 'room': 'Y'}])[0], 'unrecognized')

    def test_latest_handbook_settles_only_courses_it_times_consistently(self):
        def listing(time, room, prof='김교수'):
            raw = ['2', '전선', 'ARC22212', '디지털이미징설계', '3', '3', '01', prof, time, room, '']
            return {'name': '디지털이미징설계', 'time': time, 'room': room, 'raw': raw, 'page': 254}
        def course(status, section='01'):
            return {'sourceId': f'x/{section}', 'courseCode': 'ARC22212', 'section': section,
                    'courseName': '디지털이미징설계', 'professor': '', 'scheduleStatus': status,
                    'schedules': [], 'sourceSchedule': '', 'sourceClassroom': '', 'remarks': 'r'}
        off = {'ARC22212-01': [listing('월C,목B', 'Y424-2'), listing('월C,목B', 'Y424-2')],
               'ARC22212-02': [listing('월B,목C', 'Y424-2'), listing('월B', 'Y424-2')]}
        held, clash, done = course('unrecognized'), course('unrecognized', '02'), course('scheduled')
        self.assertEqual(pcu.settle_latest([held, clash, done], off), ['x/01'])
        self.assertEqual([(m['weekday'], m['startMinute'], m['endMinute']) for m in held['schedules']],
                         [(1, 810, 900), (4, 660, 750)])
        self.assertEqual((held['professor'], held['sourceClassroom']), ('김교수', 'Y424-2'))
        self.assertIn('2026-11-04', held['remarks'])
        self.assertEqual(clash['scheduleStatus'], 'unrecognized')
        self.assertEqual(done['schedules'], [])

    def test_unknown_numeric_period_is_rejected(self):
        self.assertIsNone(pcu.meetings([(1, '99')], 'AM108'))


class ImportPcuRerunTests(unittest.TestCase):
    def test_source_id_adds_the_course_name_only_for_split_offerings(self):
        self.assertEqual(pcu.source_id('GEN22692-01', None), 'pcu/main/2026-2/GEN22692-01')
        self.assertEqual(pcu.source_id('GEN22692-01', '사회봉사2'), 'pcu/main/2026-2/GEN22692-01/사회봉사2')

    def test_a_rerun_finds_already_added_split_courses_by_their_final_source_id(self):
        added = {'sourceId': 'pcu/main/2026-2/GEN22692-01/사회봉사2'}
        plain = {'sourceId': 'pcu/main/2026-2/GEN22102-01'}
        by_id = {c['sourceId']: c for c in (added, plain)}
        by_key = {'GEN22102-01': plain, 'GEN22692-01': {'sourceId': 'other'}}
        # A split offering is looked up by its own sourceId, never by code-section.
        self.assertIs(pcu.existing_course(by_key, by_id, 'GEN22692-01', '사회봉사2'), added)
        self.assertIsNone(pcu.existing_course(by_key, by_id, 'GEN22692-01', '사회봉사3'))
        # An unsplit offering still matches the earlier extraction by code-section.
        self.assertIs(pcu.existing_course(by_key, by_id, 'GEN22102-01', None), plain)
        self.assertIsNone(pcu.existing_course(by_key, by_id, 'NEW00001-01', None))


if __name__ == '__main__':
    unittest.main()
