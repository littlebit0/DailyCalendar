import importlib.util
import io
import json
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('fetch_konkuk', ROOT / 'tool/timetable/fetch_konkuk.py')
konkuk = importlib.util.module_from_spec(spec)
spec.loader.exec_module(konkuk)


class FakeResponse:
    def __init__(self, raw):
        self.raw = raw

    def read(self):
        return self.raw

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


class FakeOpener:
    def __init__(self, *results):
        self.results = list(results)
        self.calls = 0

    def open(self, req, timeout=0):
        self.calls += 1
        result = self.results.pop(0)
        if isinstance(result, Exception):
            raise result
        return FakeResponse(result)


def glocal_row(number, unit='U1', name='강좌'):
    return {k: ('x' if k not in ('lec_no', 'open_sust', 'lec_nm') else v)
            for k, v in (('lec_no', number), ('open_sust', unit), ('lec_nm', name),
                         *((k, None) for k in konkuk.GLOCAL_FIELDS
                           if k not in ('lec_no', 'open_sust', 'lec_nm')))}


class FetchKonkukTests(unittest.TestCase):
    def setUp(self):
        patcher = mock.patch.object(konkuk.time, 'sleep')
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_request_retries_network_errors_then_decodes_rows(self):
        opener = FakeOpener(OSError('x'), OSError('x'),
                            '{"rows": [{"a": 1}]}'.encode('utf-8'))
        self.assertEqual(konkuk.request('http://x', None, None, opener), [{'a': 1}])
        self.assertEqual(opener.calls, 3)
        failing = FakeOpener(OSError('x'), OSError('x'), OSError('x'))
        with self.assertRaises(OSError):
            konkuk.request('http://x', None, None, failing)

    def test_request_decodes_cp949_and_rejects_invalid_rows(self):
        raw = json.dumps({'rows': [{'name': '건국'}]}, ensure_ascii=False).encode('cp949')
        self.assertEqual(konkuk.request('http://x', None, None, FakeOpener(raw)),
                         [{'name': '건국'}])
        with self.assertRaises(ValueError):
            konkuk.request('http://x', None, None, FakeOpener(b'{"rows": {}}'))
        with self.assertRaises(ValueError):
            konkuk.request('http://x', None, None, FakeOpener(b'\xff\xfe\x00'))

    def test_merge_keeps_equal_duplicates_and_aborts_on_conflicts(self):
        store = {}
        konkuk.merge(store, 'A', {'n': 1}, ['5'])
        konkuk.merge(store, 'A', {'n': 1}, ['5'])
        konkuk.merge(store, 'A', {'n': 1}, ['6'])
        self.assertEqual(store['A']['scopes'], [['5'], ['6']])
        with self.assertRaises(ValueError):
            konkuk.merge(store, 'A', {'n': 2}, ['7'])

    def run_glocal(self, answers, seeds):
        asked = []

        def fake_request(url, data, referer, opener):
            asked.append(url)
            return answers(url)

        with TemporaryDirectory() as folder:
            seed = Path(folder) / 'seed.json'
            seed.write_text(json.dumps(seeds), encoding='utf-8')
            output = Path(folder)
            with mock.patch.object(konkuk.urllib.request, 'build_opener') as build, \
                    mock.patch.object(konkuk, 'request', fake_request):
                build.return_value.open.return_value.read.return_value = b''
                konkuk.glocal(output, 2026, 'B01012', seed)
            return json.loads((output / 'glocal.json').read_text(encoding='utf-8')), asked

    def test_glocal_discovers_opening_units_not_in_the_seed(self):
        def answers(url):
            if 'menu=1&lectCd=NEW' in url:
                return [glocal_row('N1', 'NEW')]
            if 'menu=1&lectCd=U1' in url:
                return [glocal_row('A1', 'U1'), glocal_row('A2', 'NEW')]
            return []

        data, asked = self.run_glocal(
            answers,
            {'source': 'seed', 'cultArea': [], 'hakgwa': [{'lec_cd': 'U1', 'lec_nm': '학과'}]})
        self.assertEqual(sorted(data['offerings']), ['A1', 'A2', 'N1'])
        self.assertTrue(any('lectCd=NEW' in url for url in asked))
        self.assertTrue(data['complete'])
        self.assertEqual(data['unitNames'], {'U1': '학과'})

    def test_glocal_rejects_a_row_without_an_offering_number(self):
        def answers(url):
            return [glocal_row('', 'U1')] if 'menu=1&lectCd=U1' in url else []

        with self.assertRaises(ValueError):
            self.run_glocal(answers, {'source': 's', 'cultArea': [],
                                      'hakgwa': [{'lec_cd': 'U1', 'lec_nm': 'x'}]})

    def test_glocal_aborts_when_a_duplicate_offering_disagrees(self):
        def answers(url):
            if 'menu=1&lectCd=U1' in url:
                return [glocal_row('A1', 'U1', '가')]
            if 'menu=5' in url:
                return [glocal_row('A1', 'U1', '나')]
            return []

        with self.assertRaises(ValueError):
            self.run_glocal(answers, {'source': 's', 'cultArea': [],
                                      'hakgwa': [{'lec_cd': 'U1', 'lec_nm': 'x'}]})

    def test_glocal_campus_requires_a_seed(self):
        with TemporaryDirectory() as folder:
            argv = ['fetch_konkuk.py', '--campus', 'glocal', '--output', folder]
            with mock.patch.object(sys, 'argv', argv), \
                    mock.patch('sys.stderr', new_callable=io.StringIO):
                with self.assertRaises(SystemExit) as caught:
                    konkuk.main()
        self.assertEqual(caught.exception.code, 2)


if __name__ == '__main__':
    unittest.main()
