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

    def test_split_table_rows_are_joined_into_one_course_row(self):
        hdr = ['학년', '', '이수구분', '교과목코드', '교과목명', '학점', '시수', '분반', '담당교수', '강의시간', '강의실', '비고']
        def row(cells, y=10):
            return {'page': 281, 'table_y': y, 'hdr': hdr, 'cells': cells, 'heads': [], 'heading': 'X'}
        rows = pcu.normalize_rows([
            row(['3', '', '', '', '상상력과문화', '3', '3', '', '문정현', '화C,목C', 'W409', '']),
            row(['', '3', '교필선', 'GEN22354', '', '', '', '01', '', '', '', '']),
            row(['', '', '', '', '', '', '', '', '', '', '', '']),
            row(['3', '', '전선', 'ARC22209', '건축설계2', '6', '12', '01', '', '화7,금', '7B301', '']),
            row(['', '', '', '', '', '', '', '', '박인규', '', '', '']),
            row(['3', '', '전선', 'ARC22209', '건축설계2', '6', '12', '01', '박인규', '화7,금7', 'B301', '']),
        ])
        self.assertEqual([r['cells'][:10] for r in rows], [
            ['3', '교필선', 'GEN22354', '상상력과문화', '3', '3', '01', '문정현', '화C,목C', 'W409'],
            ['3', '전선', 'ARC22209', '건축설계2', '6', '12', '01', '박인규', '화7,금7', 'B301'],
            # a second printed row with its own code is never folded into the first
            ['3', '전선', 'ARC22209', '건축설계2', '6', '12', '01', '박인규', '화7,금7', 'B301']])

    def test_repeated_merged_cell_text_is_taken_once(self):
        f = pcu._fields(['교과목코드', '', '강의시간', ''], ['DPA22406', 'DPA22406', '화5,화6,화7,화', '8'])
        self.assertEqual((f['교과목코드'], f['강의시간']), ('DPA22406', '화5,화6,화7,화8'))

    def test_rooms_split_on_a_new_room_line_only(self):
        self.assertEqual(pcu.rooms('A314\nA311'), 'A314 / A311')
        self.assertEqual(pcu.rooms('SP401,W21\n0'), 'SP401 / W210')

    def test_latest_edition_replaces_differing_values_and_keeps_the_earlier_ones(self):
        def listing(time, room, prof):
            raw = ['2', '전선', 'ARC22212', '디지털이미징설계', '3', '3', '01', prof, time, room, '']
            return {'name': '디지털이미징설계', 'time': time, 'room': room, 'raw': raw, 'page': 254}
        def course(status, sched, prof, room):
            return {'sourceId': 'x', 'scheduleStatus': status, 'schedules': sched, 'professor': prof,
                    'sourceSchedule': 'old', 'sourceClassroom': room, 'remarks': 'r'}
        mon_c = [{'weekday': 1, 'startMinute': 810, 'endMinute': 900, 'classroom': 'Y424-2'}]
        same = course('scheduled', mon_c, '김교수', 'Y424-2')
        self.assertFalse(pcu.refresh(same, pcu.offering([listing('월C', 'Y424-2', '김교수')], '2026-11-04')))
        self.assertEqual(same['remarks'], 'r')
        held = course('unrecognized', [], '김교수', 'Y424-2')
        o = pcu.offering([listing('월C,목B', 'Y424-2', '이교수'), listing('월C,목B', 'Y424-2', '')], '2026-11-04')
        self.assertTrue(pcu.refresh(held, o))
        self.assertEqual([(m['weekday'], m['startMinute']) for m in held['schedules']], [(1, 810), (4, 660)])
        self.assertEqual((held['scheduleStatus'], held['professor']), ('scheduled', '이교수'))
        self.assertIn("이전 8월 편람 값: 상태 unrecognized, 담당 김교수, 시간 원문 'old'", held['remarks'])
        # 'C104(new)' is the same room as 'C104'; a blank professor keeps the earlier one
        kept = course('scheduled', mon_c, '김교수', 'C104')
        self.assertFalse(pcu.refresh(kept, pcu.offering([listing('월C', 'C104(new)', '')], '2026-11-04')))

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
