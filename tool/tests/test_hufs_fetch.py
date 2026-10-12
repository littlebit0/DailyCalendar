import importlib.util
import json
from pathlib import Path
import unittest
import urllib.parse

spec = importlib.util.spec_from_file_location('hufs_fetch', Path(__file__).parents[1] / 'timetable/fetch_hufs.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class HufsFetchTest(unittest.TestCase):
    def test_public_service_zero_single_and_multiple_shapes(self):
        for count, data, expected in [(0, None, []), (1, {'title': '강좌'}, [{'title': '강좌'}]), (2, [{}, {}], [{}, {}])]:
            body = urllib.parse.quote(json.dumps({'rtnCode': '1', 'dataCount': str(count), 'data': data}))
            self.assertEqual(module.decode_response(body), expected)

    def test_rejects_failure_and_truncated_scope(self):
        for body in [{'rtnCode': '0', 'dataCount': '0', 'data': None}, {'rtnCode': '1', 'dataCount': '2', 'data': [{}]}]:
            with self.assertRaises(ValueError):
                module.decode_response(json.dumps(body))

if __name__ == '__main__':
    unittest.main()
