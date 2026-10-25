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

    def test_unknown_numeric_period_is_rejected(self):
        self.assertIsNone(pcu.meetings([(1, '99')], 'AM108'))


if __name__ == '__main__':
    unittest.main()
