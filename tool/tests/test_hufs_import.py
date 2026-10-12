import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location(
    'hufs_import', Path(__file__).parents[1] / 'timetable/import_hufs.py',
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
CLOCK = {str(i): [480 + i * 60, 530 + i * 60] for i in range(13)}


class HufsMeetingsTest(unittest.TestCase):
    def test_shared_room_applies_to_both_weekdays(self):
        result = module.meetings('화 1 2 금 1 (C307)', CLOCK)
        self.assertEqual(result, [
            {'weekday': 2, 'startMinute': 540, 'endMinute': 650, 'classroom': 'C307'},
            {'weekday': 5, 'startMinute': 540, 'endMinute': 590, 'classroom': 'C307'},
        ])

    def test_nonconsecutive_periods_and_different_rooms_stay_separate(self):
        result = module.meetings('월 1 3 (1201) 수 5 6 (C405)', CLOCK)
        self.assertEqual([(m['weekday'], m['startMinute'], m['endMinute'], m['classroom']) for m in result], [
            (1, 540, 590, '1201'), (1, 660, 710, '1201'), (3, 780, 890, 'C405'),
        ])

    def test_unpublished_period_cannot_be_guessed_or_clamped(self):
        with self.assertRaisesRegex(ValueError, 'Unverified HUFS period: 13'):
            module.meetings('월 11 12 13 (C412)', CLOCK)
        with self.assertRaises(ValueError):
            module.meetings('월 2 1 (1201)', CLOCK)
        with self.assertRaises(ValueError):
            module.meetings('월 1 (1201) invalid', CLOCK)
        self.assertEqual(module.meetings('', CLOCK), [])

    def test_cross_listing_preserves_each_department_restriction(self):
        row = {
            'ledgYear': '2026', 'ledgSessn': '3', 'orgSect': 'A', 'campus': 'H1',
            'lssnCd': 'A22031a01', 'subjtNaKr': '공개 수업', 'unitNum': '3',
            'dayTimeDisplay': '화 1 2 (1202)', 'comptFldNm': '전공',
            'encessFlag': 'N', 'etc': '소속 제한', 'etc2': '',
            'cyberFlag': 'N', 'wongangFlag': 'N', 'empNm': '', 'lang': '',
        }
        records = [
            {'queryCampus': 'H1', 'queryCategory': '1', 'queryDepartment': '학과 A', 'row': row},
            {'queryCampus': 'H1', 'queryCategory': '4', 'queryDepartment': '과정 B', 'row': {**row, 'etc': '과정 제한'}},
        ]
        result = module.parse_rows(records, {'H1': CLOCK})
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]['courseCode'], 'A22031a')
        self.assertEqual(result[0]['section'], '01')
        self.assertEqual(result[0]['departmentRemarks'], {'학과 A': '소속 제한', '마이크로전공 · 과정 B': '과정 제한'})
        with self.assertRaises(ValueError):
            module.parse_rows([records[0], {**records[1], 'row': {**row, 'unitNum': '2'}}], {'H1': CLOCK})


if __name__ == '__main__':
    unittest.main()
