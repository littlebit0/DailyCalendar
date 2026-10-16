import importlib.util
import json
import os
from pathlib import Path
import tempfile
import time
import unittest
from unittest.mock import patch
import urllib.error

SPEC = importlib.util.spec_from_file_location('reader', Path(__file__).resolve().parent / 'drive_reader.py')
reader = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(reader)


def meta(file_id='a', version='1'):
    return {'id': file_id, 'name': f'daily-sync-v2-event-{file_id}.json',
            'version': version, 'modifiedTime': '2026-10-16T00:00:00Z'}


class ReaderTests(unittest.TestCase):
    def test_google_connect_reuses_existing_consent_in_explicit_flow(self):
        with patch.object(reader, 'config', return_value={}), \
                patch.object(reader, 'keychain', return_value={'sub': 'owner'}) as keychain, \
                patch.object(reader, 'access', return_value={'email': 'fixture@example.test'}) as access, \
                patch.object(reader, 'HTTPServer') as browser, patch('builtins.print'):
            reader.connect(30)
            keychain.assert_called_once_with('read', interactive=True)
            access.assert_called_once_with(interactive=True)
            browser.assert_not_called()

    def test_parallel_snapshot_preserves_order_and_reports_progress(self):
        import threading
        active, maximum = 0, 0
        lock = threading.Lock()
        files = [meta(str(i)) for i in range(15)]
        progress = []
        def download(url, token=None):
            nonlocal active, maximum
            with lock:
                active += 1
                maximum = max(maximum, active)
            time.sleep(0.01)
            with lock:
                active -= 1
            return {'id': url.split('/')[-1].split('?')[0]}
        with patch.object(reader, 'list_files', return_value=files), patch.object(reader, 'request_json', side_effect=download):
            result = reader.snapshot('fixture', progress=lambda *args: progress.append(args))
        self.assertGreater(maximum, 1)
        self.assertLessEqual(maximum, 6)
        self.assertEqual([d['payload']['id'] for d in result], [str(i) for i in range(15)])
        self.assertEqual(progress[-1], ('verified', 15, 15))

    def test_callback_rejects_cross_request_and_duplicate_states(self):
        self.assertIsNone(reader.callback_result('state=wrong&code=secret', 'expected'))
        self.assertIsNone(reader.callback_result('state=expected&state=other&code=secret', 'expected'))
        self.assertEqual(reader.callback_result('state=expected&code=accepted', 'expected'), 'accepted')
        with self.assertRaises(reader.ReaderError):
            reader.callback_result('state=expected&error=access_denied', 'expected')

    def test_pagination_including_empty_page(self):
        with patch.object(reader, 'request_json', side_effect=[
            {'files': [], 'nextPageToken': 'next'}, {'files': [meta()]}]) as call:
            self.assertEqual(reader.list_files('token'), [meta()])
            self.assertIn('pageToken=next', call.call_args.args[0])
            self.assertIn('spaces=appDataFolder', call.call_args.args[0])

    def test_repeated_page_and_incomplete_search_fail(self):
        for pages in [
            [{'files': [], 'nextPageToken': 'x'}] * 2,
            [{'files': [], 'incompleteSearch': True}],
            [{}],
            [{'files': [{'id': '../other', 'name': 'x'}]}],
        ]:
            with self.subTest(pages=pages), patch.object(reader, 'request_json', side_effect=pages):
                with self.assertRaises(reader.ReaderError):
                    reader.list_files('token')

    def test_duplicate_conflicting_metadata_fails(self):
        with patch.object(reader, 'request_json', return_value={'files': [meta(), meta(version='2')]}):
            with self.assertRaises(reader.ReaderError):
                reader.list_files('token')

    def test_snapshot_retries_changed_data(self):
        first, latest = [meta()], [meta(version='2')]
        with patch.object(reader, 'list_files', side_effect=[first, latest, latest, latest]), \
                patch.object(reader, 'request_json', side_effect=[{'event': {'title': 'old'}}, {'event': {'title': 'new'}}]):
            result = reader.snapshot('token')
            self.assertEqual(result[0]['payload']['event']['title'], 'new')

    def test_snapshot_unstable_or_failed_is_not_complete(self):
        with patch.object(reader, 'list_files', side_effect=[[meta()], [], [meta()], []]), \
                patch.object(reader, 'request_json', return_value={'event': {}}):
            with self.assertRaises(reader.ReaderError):
                reader.snapshot('token')
        with patch.object(reader, 'list_files', return_value=[meta()]), \
                patch.object(reader, 'request_json', side_effect=reader.ReaderError('failure')):
            with self.assertRaises(reader.ReaderError):
                reader.snapshot('token')

    def test_no_arbitrary_hosts_or_drive_writes(self):
        for url, form in [('https://example.com/', None), (reader.FILES_URL, {'name': 'write'})]:
            with self.assertRaises(reader.ReaderError):
                reader.request_json(url, token='sensitive', form=form)

    def test_google_errors_do_not_disclose_body_or_token(self):
        error = urllib.error.HTTPError(reader.TOKEN_URL, 400, 'secret-response', {}, None)
        with patch('urllib.request.OpenerDirector.open', side_effect=error):
            with self.assertRaises(reader.ReaderError) as caught:
                reader.request_json(reader.TOKEN_URL, form={'secret': 'sensitive'})
        self.assertNotIn('secret', str(caught.exception))
        self.assertNotIn('sensitive', str(caught.exception))

    def test_refresh_identity_mismatch_keeps_existing_session(self):
        old = {'client_id': 'client', 'sub': 'old', 'expires_at': 0,
               'access_token': 'old-access', 'refresh_token': 'old-refresh'}
        fresh = {'token_type': 'Bearer', 'access_token': 'new-access', 'expires_in': 3600}
        with patch.object(reader, 'config', return_value={'client_id': 'client'}), \
                patch.object(reader, 'keychain', return_value=old) as store, \
                patch.object(reader, 'request_json', return_value=fresh), \
                patch.object(reader, 'identity', return_value={'sub': 'other', 'email': 'other@example.test'}):
            with self.assertRaises(reader.ReaderError):
                reader.access()
            store.assert_called_once_with('read', interactive=False)

    def test_refresh_keeps_refresh_token_and_verifies_identity(self):
        old = {'client_id': 'client', 'sub': 'owner', 'expires_at': 0,
               'access_token': 'old-access', 'refresh_token': 'old-refresh'}
        fresh = {'token_type': 'Bearer', 'access_token': 'new-access', 'expires_in': 3600}
        with patch.object(reader, 'config', return_value={'client_id': 'client'}), \
                patch.object(reader, 'keychain', return_value=old) as store, \
                patch.object(reader, 'request_json', return_value=fresh), \
                patch.object(reader, 'identity', return_value={'sub': 'owner', 'email': 'owner@example.test'}):
            saved = reader.access()
            self.assertEqual(saved['refresh_token'], 'old-refresh')
            self.assertGreater(saved['expires_at'], time.time())
            self.assertEqual(store.call_args.args[0], 'write')

    def test_inadequate_scopes_fail(self):
        with self.assertRaises(reader.ReaderError):
            reader.validated_token({'access_token': 'x', 'refresh_token': 'y', 'token_type': 'Bearer',
                                    'scope': 'openid email', 'expires_in': 3600})

    def test_private_snapshot_permissions_and_symlink_protection(self):
        with tempfile.TemporaryDirectory() as temp:
            dest = Path(temp) / 'private' / 'snapshot.json'
            reader.private_write(dest, {'documents': []})
            self.assertEqual(os.stat(dest).st_mode & 0o777, 0o600)
            self.assertEqual(os.stat(dest.parent).st_mode & 0o777, 0o700)
            self.assertEqual(json.loads(dest.read_text()), {'documents': []})
            dest.unlink()
            target = Path(temp) / 'unrelated'
            target.write_text('keep')
            dest.symlink_to(target)
            with self.assertRaises(reader.ReaderError):
                reader.private_write(dest, {})
            self.assertEqual(target.read_text(), 'keep')


if __name__ == '__main__':
    unittest.main()
