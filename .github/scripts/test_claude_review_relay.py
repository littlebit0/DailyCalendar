import copy
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('relay', Path(__file__).with_name('claude_review_relay.py'))
relay = importlib.util.module_from_spec(spec);spec.loader.exec_module(relay)


class RelayTests(unittest.TestCase):
    def setUp(self):
        self.review = {'id': 41, 'state': 'COMMENTED', 'submitted_at': '2026-10-23T12:00:00Z',
            'user': {'login': relay.HUMAN, 'type': 'User'}, 'body': relay.MARKER,
            'commit_id': 'a' * 40, 'html_url': 'https://github.com/owner/repo/pull/9#pullrequestreview-41'}
        self.comment = {'pull_request_review_id': 41, 'user': {'login': relay.HUMAN}, 'body': '[P1] 실제 결함'}
        self.since = '2026-10-23T00:00:00Z'
        self.pr = {'number': 9, 'state': 'open', 'head': {'sha': 'a' * 40, 'repo': {'full_name': 'owner/repo'}}}
        self.temp = tempfile.TemporaryDirectory()
        self.old_cwd = os.getcwd();os.chdir(self.temp.name)
        self.env = patch.dict(os.environ, {'GITHUB_REPOSITORY': 'owner/repo', 'GITHUB_RUN_ID': '7',
            'GITHUB_RUN_ATTEMPT': '1', 'GITHUB_OUTPUT': str(Path(self.temp.name) / 'out'),
            'REVIEW_RELAY_SINCE': self.since, 'RETRY_REVIEW_ID': '', 'ACKNOWLEDGE_UNCERTAIN': ''})
        self.env.start()
        self.context = {'repository': 'owner/repo', 'pr_number': 9, 'review_id': 41,
                        'commit': 'a' * 40, 'notification': 'PR #9에 리뷰 댓글을 작성했습니다.'}
        self.ack = {**self.context, 'review_read': True, 'status': 'completed'}
        os.environ['CLAUDE_STRUCTURED_OUTPUT'] = json.dumps(self.ack)

    def tearDown(self):
        self.env.stop();os.chdir(self.old_cwd);self.temp.cleanup()

    def test_human_requires_explicit_marker_and_actual_finding(self):
        self.assertTrue(relay.eligible(self.review, [self.comment], self.since))
        self.assertFalse(relay.eligible(self.review, [], self.since))
        self.review['body'] = '일반 댓글 [P1]'
        self.assertFalse(relay.eligible(self.review, [self.comment], self.since))

    def test_bot_badge_supported_and_other_actors_rejected(self):
        self.review['user'] = {'login': relay.BOT, 'type': 'Bot'}
        self.review['body'] = '![P2 Badge](https://example.org/badge) 결함'
        self.assertTrue(relay.eligible(self.review, [], self.since))
        for actor in ['claude[bot]', 'github-actions[bot]', 'unknown', 'littlebit0-copy']:
            self.review['user']['login'] = actor
            self.assertFalse(relay.eligible(self.review, [], self.since))

    def test_pending_dismissed_approved_old_and_unpublished_not_delivered(self):
        for state in ['PENDING', 'DISMISSED', 'APPROVED']:
            review = {**self.review, 'state': state}
            self.assertFalse(relay.eligible(review, [self.comment], self.since))
        self.assertFalse(relay.eligible({**self.review, 'submitted_at': None}, [self.comment], self.since))
        self.assertFalse(relay.eligible(self.review, [self.comment], '2026-10-24T00:00:00Z'))

    def test_inline_other_review_or_author_does_not_count(self):
        self.assertFalse(relay.eligible(self.review, [{**self.comment, 'pull_request_review_id': 42}], self.since))
        self.assertFalse(relay.eligible(self.review, [{**self.comment, 'user': {'login': 'other'}}], self.since))

    def test_duplicate_success_never_retried(self):
        with patch.dict(os.environ, {'RETRY_REVIEW_ID': '41', 'ACKNOWLEDGE_UNCERTAIN': 'true'}):
            self.assertFalse(relay.retry_allowed({'conclusion': 'success', 'output': {'summary': json.dumps({'schema': 2, 'received': True, 'state': 'completed'})}}, 41))

    def test_unknown_requires_specific_acknowledgment(self):
        for check in [{'status': 'in_progress'}, {'conclusion': 'failure'}, {'conclusion': 'cancelled'}]:
            self.assertFalse(relay.retry_allowed(check, 41))
            with patch.dict(os.environ, {'RETRY_REVIEW_ID': '41', 'ACKNOWLEDGE_UNCERTAIN': 'true'}):
                self.assertTrue(relay.retry_allowed(check, 41))
                self.assertFalse(relay.retry_allowed(check, 42))

    def test_check_app_and_latest_attempt(self):
        checks = [{'id': 1, 'name': relay.CHECK_PREFIX + '41', 'app': {'slug': 'github-actions'}},
                  {'id': 2, 'name': relay.CHECK_PREFIX + '41', 'app': {'slug': 'other'}}]
        self.assertEqual(relay.latest_check(checks, 41)['id'], 1)
        checks.append({**checks[0], 'id': 3})
        self.assertEqual(relay.latest_check(checks, 41)['id'], 3)

    def api(self, path, method='GET', body=None):
        if path == 'pulls/9': return self.pr
        if path == 'pulls/9/reviews/41': return self.review
        if path == 'check-runs': return {'id': 81}
        raise AssertionError(path)

    def test_claim_dynamic_number_safe_context_and_single_reservation(self):
        self.comment['body'] += '\n$(touch bad); ${{ secrets.X }}'
        with patch.object(relay, 'api', side_effect=self.api) as api, patch.object(relay, 'pages', side_effect=[[self.comment], [], [self.review]]):
            relay.claim(9, 41)
        self.assertEqual(sum(c.args[0] == 'check-runs' for c in api.call_args_list), 1)
        context = json.loads(Path('relay-context.json').read_text())
        self.assertEqual(context['notification'], 'PR #9에 리뷰 댓글을 작성했습니다.')
        self.assertNotIn('touch bad', Path('relay-context.json').read_text())
        self.assertFalse(Path('bad').exists())

    def test_claim_stale_closed_fork_and_duplicate_skip(self):
        for change in ['stale', 'closed', 'fork', 'duplicate']:
            original = copy.deepcopy(self.pr)
            if change == 'stale': self.pr['head']['sha'] = 'b' * 40
            if change == 'closed': self.pr['state'] = 'closed'
            if change == 'fork': self.pr['head']['repo']['full_name'] = 'outside/repo'
            check = {'id': 1, 'name': relay.CHECK_PREFIX + '41', 'app': {'slug': 'github-actions'}, 'conclusion': 'success'}
            with patch.object(relay, 'api', side_effect=self.api) as api, patch.object(relay, 'pages', side_effect=[[self.comment], [check], [self.review]]):
                relay.claim(9, 41)
            self.assertFalse(any(c.args[0] == 'check-runs' for c in api.call_args_list))
            self.pr = original

    def test_receipt_requires_action_and_claude_success(self):
        Path('relay-context.json').write_text(json.dumps(self.context))
        Path('execution.json').write_text(json.dumps([{'type': 'result', 'subtype': 'success', 'is_error': False, 'permission_denials': []}]))
        with patch.dict(os.environ, {'CLAUDE_OUTCOME': 'success', 'CLAUDE_EXECUTION_FILE': 'execution.json'}), patch.object(relay, 'api', return_value=self.pr):
            relay.finish(81)
        self.assertEqual(json.loads(Path('relay-receipt.json').read_text())['state'], 'completed')
        for outcome in ['failure', 'cancelled', 'skipped']:
            with patch.dict(os.environ, {'CLAUDE_OUTCOME': outcome}), patch.object(relay, 'api'):
                with self.assertRaises(RuntimeError): relay.finish(81)
        self.assertEqual(json.loads(Path('relay-receipt.json').read_text())['state'], 'uncertain')

    def test_changed_head_dispatches_ci_without_claiming_ci_success(self):
        Path('execution.json').write_text(json.dumps({'type': 'result', 'subtype': 'success', 'is_error': False, 'permission_denials': []}))
        Path('relay-context.json').write_text(json.dumps(self.context))
        self.pr['head']['sha'] = 'b' * 40
        self.pr['head']['ref'] = 'fix-branch'
        self.pr['base'] = {'ref': 'main'}
        with patch.dict(os.environ, {'CLAUDE_OUTCOME': 'success', 'CLAUDE_EXECUTION_FILE': 'execution.json'}), patch.object(relay, 'api', return_value=self.pr) as api:
            relay.finish(81)
        self.assertTrue(any(c.args[:2] == ('actions/workflows/platform-builds.yml/dispatches', 'POST') for c in api.call_args_list))
        self.assertEqual(json.loads(Path('relay-receipt.json').read_text())['ci'], 'dispatch_accepted_not_verified')

    def test_auth_failure_not_retried_or_claimed_success(self):
        error = relay.urllib.error.HTTPError('url', 401, 'unauthorized', {}, None)
        with patch.dict(os.environ, {'GH_TOKEN': 'test-only'}), patch.object(relay.urllib.request, 'urlopen', side_effect=error) as call:
            with self.assertRaisesRegex(RuntimeError, '401'): relay.api('pulls')
            self.assertEqual(call.call_count, 1)

    def test_transient_read_retries_but_unknown_write_does_not(self):
        error = relay.urllib.error.URLError('temporary')
        with patch.dict(os.environ, {'GH_TOKEN': 'test-only'}), patch.object(relay.time, 'sleep'), patch.object(relay.urllib.request, 'urlopen', side_effect=error) as call:
            with self.assertRaises(RuntimeError): relay.api('pulls')
            self.assertEqual(call.call_count, 3)
            call.reset_mock()
            with self.assertRaises(RuntimeError): relay.api('check-runs', 'POST', {})
            self.assertEqual(call.call_count, 1)

    def test_multiple_inline_and_event_redelivery_select_one_review(self):
        def pages(path, key=None):
            if path.startswith('pulls?'): return [self.pr]
            if '/reviews' in path: return [self.review]
            if '/comments' in path: return [self.comment, self.comment, self.comment]
            return []
        with patch.object(relay, 'pages', side_effect=pages): relay.scan()
        matrix = Path(os.environ['GITHUB_OUTPUT']).read_text().splitlines()[0]
        self.assertEqual(json.loads(matrix.split('=', 1)[1])['include'], [{'pr': 9, 'review': 41}])

    def test_receipt_rejects_denials_wrong_target_and_missing_ack(self):
        clean = {'type': 'result', 'subtype': 'success', 'is_error': False, 'permission_denials': []}
        for records, ack in [([{**clean, 'permission_denials': ['denied']}], self.ack),
                             ([clean], {}), ([clean], {**self.ack, 'review_id': 42}),
                             ([clean], {**self.ack, 'status': 'blocked'}), ([], self.ack)]:
            self.assertEqual(relay.evaluate_execution('success', records, ack, self.context)['state'], 'uncertain')
        self.assertEqual(relay.evaluate_execution('success', [clean], self.ack, self.context)['state'], 'completed')

    def test_legacy_green_without_receipt_needs_explicit_retry(self):
        self.assertFalse(relay.retry_allowed({'conclusion': 'success'}, 41))
        with patch.dict(os.environ, {'RETRY_REVIEW_ID': '41', 'ACKNOWLEDGE_UNCERTAIN': 'true'}):
            self.assertTrue(relay.retry_allowed({'conclusion': 'success'}, 41))

    def test_claim_rechecks_uncertain_previous_head_after_queue(self):
        previous = {**self.review, 'id': 40, 'commit_id': 'b' * 40}
        check = {'id': 1, 'name': relay.CHECK_PREFIX + '40', 'app': {'slug': 'github-actions'}, 'status': 'in_progress'}
        with patch.object(relay, 'api', side_effect=self.api) as api, patch.object(relay, 'pages',
                side_effect=[[self.comment], [], [previous, self.review], [check]]):
            relay.claim(9, 41)
        self.assertFalse(any(c.args[0] == 'check-runs' for c in api.call_args_list))


if __name__ == '__main__': unittest.main()
