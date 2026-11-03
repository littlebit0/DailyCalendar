import unittest
from capture_hongik_syllabus import Capture


def sent(capture, messages):
    out = []
    for m in messages:
        capture.handle(m, out.append)
    return out


class CaptureTest(unittest.TestCase):
    def test_back_to_back_responses_get_distinct_ids_and_own_bodies(self):
        c = Capture()
        commands = sent(c, [
            {'method': 'Network.requestWillBeSent', 'params': {'requestId': 'a', 'request': {'url': 'https://x/a.css', 'method': 'GET'}}},
            {'method': 'Network.requestWillBeSent', 'params': {'requestId': 'b', 'request': {'url': 'https://x/b.js', 'method': 'GET'}}},
            {'method': 'Network.responseReceived', 'params': {'requestId': 'a', 'response': {'status': 200, 'mimeType': 'text/css'}}},
            {'method': 'Network.responseReceived', 'params': {'requestId': 'b', 'response': {'status': 200, 'mimeType': 'text/javascript'}}},
        ])
        ids = [cmd['id'] for cmd in commands]
        self.assertEqual(len(set(ids)), 2)
        # Answers arrive in reverse order; each lands on its own request only.
        sent(c, [{'id': ids[1], 'result': {'body': 'js', 'base64Encoded': False}},
                 {'id': ids[0], 'result': {'body': 'css', 'base64Encoded': False}}])
        by_id = {r['id']: r for r in c.requests}
        self.assertEqual(by_id['a']['body'], 'css')
        self.assertEqual(by_id['b']['body'], 'js')

    def test_errors_empty_and_base64_bodies_stay_with_their_request(self):
        c = Capture()
        commands = sent(c, [
            {'method': 'Network.requestWillBeSent', 'params': {'requestId': r, 'request': {'url': f'https://x/{r}', 'method': 'GET'}}}
            for r in 'abc'] + [
            {'method': 'Network.responseReceived', 'params': {'requestId': r, 'response': {'status': 200, 'mimeType': 'x'}}}
            for r in 'abc'])
        ids = [cmd['id'] for cmd in commands]
        sent(c, [{'id': ids[0], 'error': {'code': -32000, 'message': 'No resource'}},
                 {'id': ids[1], 'result': {'body': '', 'base64Encoded': False}},
                 {'id': ids[2], 'result': {'body': 'aGk=', 'base64Encoded': True}}])
        by_id = {r['id']: r for r in c.requests}
        self.assertIn('bodyError', by_id['a'])
        self.assertNotIn('body', by_id['a'])
        self.assertEqual(by_id['b']['body'], '')
        self.assertEqual((by_id['c']['body'], by_id['c']['base64']), ('aGk=', True))


if __name__ == '__main__':
    unittest.main()
