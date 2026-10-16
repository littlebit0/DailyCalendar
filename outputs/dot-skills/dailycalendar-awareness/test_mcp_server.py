import json
import os
import time
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch, Mock

import mcp_server as mcp


class MCPTests(unittest.TestCase):
    def test_new_version_does_not_reuse_old_success_receipt(self):
        with tempfile.TemporaryDirectory() as folder:
            destination = Path(folder) / 'connection.json'
            destination.write_text(json.dumps({'nonce': 'fixture', 'pluginVersion': '0.1.0', 'googleConnected': True, 'lastQuery': time.time()}))
            with patch.dict(os.environ, {'DAILY_DOT_STATUS_FILE': str(destination), 'DAILY_DOT_STATUS_NONCE': 'fixture'}):
                mcp.publish_status(pluginReady=True)
            value = json.loads(destination.read_text())
            self.assertEqual(value['pluginVersion'], '0.1.3')
            self.assertTrue(value['pluginReady'])
            self.assertNotIn('googleConnected', value)
            self.assertNotIn('lastQuery', value)

    def test_pages_preserve_every_field_and_no_future_cap(self):
        server = mcp.Server()
        documents = [{'payload': {'id': str(i), 'futureField': 'keep'}} for i in range(23)]
        server.documents = documents
        server.snapshot_id = 'snapshot'
        server.owner = 'owner'
        server.metadata = {'future_end': None, 'acquisition_complete': True}
        gathered = []
        offset = 0
        with patch.object(mcp.reader, 'access', return_value={'sub': 'owner'}):
            while True:
                result = server.call('read_calendar_page', {'snapshot_id': 'snapshot', 'offset': offset})
                gathered.extend(result['documents'])
                self.assertFalse(result['semantic_interpretation_complete'])
                offset = result['next_offset']
                if offset is None:
                    break
        self.assertEqual(gathered, documents)
        self.assertTrue(result['all_pages_delivered'])

    def test_jumping_to_last_page_does_not_claim_complete_delivery(self):
        server = mcp.Server()
        server.documents = list(range(25))
        server.metadata = {}
        result = server.page(20)
        self.assertIsNone(result['next_offset'])
        self.assertFalse(result['all_pages_delivered'])

    def test_changed_owner_discards_snapshot(self):
        server = mcp.Server()
        server.documents = [{'private': True}]
        server.owner, server.snapshot_id = 'before', 'snapshot'
        with patch.object(mcp.reader, 'access', return_value={'sub': 'after'}):
            with self.assertRaises(ValueError):
                server.call('read_calendar_page', {'snapshot_id': 'snapshot', 'offset': 0})
        self.assertIsNone(server.documents)

    def test_expired_snapshot_and_invalid_boolean_rejected(self):
        server = mcp.Server()
        for name, args in [('read_calendar_page', {'snapshot_id': 'old', 'offset': 0}),
                           ('read_calendar', {'include_past_seven_days': 'yes'}),
                           ('connection_status', {'token': 'not accepted'})]:
            with self.assertRaises(ValueError):
                server.call(name, args)

    def test_initialization_and_notifications(self):
        server = mcp.Server()
        result = server.dispatch({'jsonrpc': '2.0', 'id': 1, 'method': 'initialize'})
        self.assertIn('Drive', result['result']['instructions'])
        self.assertIsNone(server.dispatch({'jsonrpc': '2.0', 'method': 'notifications/initialized'}))
        tools = server.dispatch({'jsonrpc': '2.0', 'id': 2, 'method': 'tools/list'})['result']['tools']
        self.assertTrue(all(t['annotations']['readOnlyHint'] for t in tools))

    def test_error_does_not_leak_credentials(self):
        server = mcp.Server()
        with tempfile.TemporaryDirectory() as folder, patch.object(mcp.reader, 'RUNTIME', Path(folder)), \
                patch.object(mcp.reader, 'access', side_effect=mcp.reader.ReaderError('secret-token')):
            response = server.dispatch({'jsonrpc': '2.0', 'id': 3, 'method': 'tools/call',
                                        'params': {'name': 'connection_status'}})
        self.assertTrue(response['result']['isError'])
        self.assertNotIn('secret-token', json.dumps(response))

    def test_ui_connection_runs_in_bounded_child(self):
        server = mcp.Server()
        stop = Mock()
        stop.wait.side_effect = [False, True]
        stop.is_set.return_value = False
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'request.json').write_text(json.dumps({'id': 'request', 'nonce': 'n',
                'action': 'connect', 'createdAt': time.time()}))
            with patch.dict(os.environ, {'DAILY_DOT_STATUS_FILE': str(root / 'connection.json'),
                                         'DAILY_DOT_STATUS_NONCE': 'n'}), \
                    patch.object(mcp.subprocess, 'Popen') as launch, \
                    patch.object(mcp.select, 'select', return_value=([1], [], [])):
                child = launch.return_value
                child.stdout.readline.side_effect = ['{"status":"waiting_for_keychain"}\n', '{"status":"connected"}\n', '']
                child.wait.return_value = 0
                child.poll.return_value = 0
                mcp.watch_requests(server, stop)
                launch.assert_called_once()
                receipt = json.loads((root / 'connection.json').read_text())
                self.assertTrue(receipt['googleConnected'])
                self.assertEqual(receipt['requestState'], 'complete')
                self.assertIn('requestCreatedAt', receipt)

    def test_busy_or_keychain_permission_does_not_revoke_google_state(self):
        for error in [mcp.reader.ReaderBusy('busy'), mcp.reader.KeychainApprovalRequired('approval')]:
            with patch.object(mcp.reader, 'session_lock', side_effect=error), patch.object(mcp, 'publish_status') as publish:
                reply = mcp.Server().dispatch({'jsonrpc': '2.0', 'id': 1, 'method': 'tools/call',
                    'params': {'name': 'connection_status', 'arguments': {}}})
                self.assertTrue(reply['result']['isError'])
                publish.assert_not_called()


    def test_ui_wrong_nonce_never_triggers_google_access(self):
        stop = Mock()
        stop.wait.side_effect = [False, True]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'request.json').write_text(json.dumps({'id': 'request', 'nonce': 'wrong',
                'action': 'connect', 'createdAt': time.time()}))
            with patch.dict(os.environ, {'DAILY_DOT_STATUS_FILE': str(root / 'connection.json'),
                                         'DAILY_DOT_STATUS_NONCE': 'expected'}), \
                    patch.object(mcp.reader, 'keychain') as keychain:
                mcp.watch_requests(mcp.Server(), stop)
                keychain.assert_not_called()
            self.assertFalse((root / 'connection.json').exists())


if __name__ == '__main__':
    unittest.main()
