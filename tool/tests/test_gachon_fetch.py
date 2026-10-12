import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('fetch_gachon', Path(__file__).parents[1] / 'timetable/fetch_gachon.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class GachonResponseTest(unittest.TestCase):
    def test_incomplete_and_duplicate_public_rows_are_rejected(self):
        row = {'HAKSU_NO': '07721001'}
        with self.assertRaises(ValueError):
            module.decode_response({'MainData': [row], 'dmRowCnt': {'rowCnt': '2'}})
        with self.assertRaises(ValueError):
            module.decode_response({'MainData': [row, row], 'dmRowCnt': {'rowCnt': '2'}})
        self.assertEqual(module.decode_response({'MainData': [], 'dmRowCnt': {'rowCnt': '0'}}), [])

    def test_only_public_course_fields_are_retained(self):
        row = {'HAKSU_NO': '07721001', 'SUBJECT_NM_KOR': '화학및실험1', 'MEMBER_NO': 'discarded', 'TRAILER': '없음'}
        result = module.decode_response({'MainData': [row], 'dmRowCnt': {'rowCnt': '1'}})
        self.assertEqual(result[0]['SUBJECT_NM_KOR'], '화학및실험1')
        self.assertNotIn('MEMBER_NO', result[0])
        # TRAILER means video availability, not enrollment restrictions.
        self.assertNotIn('TRAILER', result[0])


if __name__ == '__main__':
    unittest.main()
