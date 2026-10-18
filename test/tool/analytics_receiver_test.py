import json
import stat
import tempfile
import unittest
from pathlib import Path

from tool.analytics_receiver import (
    Aggregator,
    BugReportBackend,
    BugReportRateLimited,
    InvalidGoogleToken,
    normalize_bug_report,
    valid_batch,
)


class AnalyticsVersionTests(unittest.TestCase):
    def test_test_and_production_versions_are_valid_and_separate(self):
        batch = {
            'schemaVersion': 1,
            'sessionId': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
            'environment': {'appVersion': '4.1.2', 'platform': 'macos', 'osMajor': 27},
            'events': [{
                'eventId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
                'name': 'app_load_completed',
                'occurredAt': '2026-10-13T00:00:00Z',
                'attributes': {'durationMs': 25},
            }],
        }
        with tempfile.TemporaryDirectory() as directory:
            aggregator = Aggregator(directory)
            self.assertTrue(valid_batch(batch))
            self.assertEqual(aggregator.accept(batch), 1)
            batch['environment']['appVersion'] = '4.1.2-test'
            batch['events'][0]['eventId'] = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'
            self.assertTrue(valid_batch(batch))
            self.assertEqual(aggregator.accept(batch), 1)
            aggregate = json.loads(next(Path(directory).glob('analytics-*.json')).read_text())
            self.assertEqual(
                {group['appVersion'] for group in aggregate['groups'].values()},
                {'4.1.2', '4.1.2-test'},
            )
        batch['environment']['appVersion'] = '4.1.2-private-data'
        self.assertFalse(valid_batch(batch))


class DurationTruncationTests(unittest.TestCase):
    BASE = {'eventId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'occurredAt': '2026-10-19T00:00:00Z'}

    def event(self, name, attributes):
        return {**self.BASE, 'name': name, 'attributes': attributes}

    def test_flag_is_optional_and_only_true_is_valid(self):
        from tool.analytics_receiver import valid_event
        self.assertTrue(valid_event(self.event('app_load_completed', {'durationMs': 120000})))
        self.assertTrue(valid_event(self.event('app_load_completed', {'durationMs': 120000, 'durationTruncated': True})))
        for bad in (False, 'true', 1, None):
            self.assertFalse(valid_event(self.event('app_load_completed', {'durationMs': 5, 'durationTruncated': bad})))
        self.assertFalse(valid_event(self.event('app_load_completed', {'durationMs': 120001})))
        self.assertFalse(valid_event(self.event('app_load_completed', {'durationTruncated': True})))
        self.assertFalse(valid_event(self.event('screen_view', {'screen': 'calendar', 'durationTruncated': True})))

    def test_truncated_runs_are_aggregated_apart_from_exact_runs(self):
        batch = {
            'schemaVersion': 1,
            'sessionId': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
            'environment': {'appVersion': '4.1.2', 'platform': 'ios', 'osMajor': 27},
            'events': [
                {**self.BASE, 'name': 'app_load_completed', 'attributes': {'durationMs': 120000}},
                {**self.BASE, 'eventId': 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
                 'name': 'app_load_completed',
                 'attributes': {'durationMs': 120000, 'durationTruncated': True}},
            ],
        }
        self.assertTrue(valid_batch(batch))
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual(Aggregator(directory).accept(batch), 2)
            aggregate = json.loads(next(Path(directory).glob('analytics-*.json')).read_text())
            groups = list(aggregate['groups'].values())
            self.assertEqual(len(groups), 2)
            self.assertEqual(sorted('durationTruncated' in g['attributes'] for g in groups), [False, True])

    def test_event_save_phase_matches_the_app(self):
        from tool.analytics_receiver import valid_event
        self.assertTrue(valid_event(self.event('event_save_succeeded', {
            'operation': 'create', 'phase': 'database', 'durationMs': 5})))
        self.assertTrue(valid_event(self.event('event_save_failed', {
            'operation': 'create', 'phase': 'followUp', 'durationMs': 5, 'errorCode': 'unknown'})))


class FrameSummaryTests(unittest.TestCase):
    BASE = {'eventId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'occurredAt': '2026-10-19T00:00:00Z',
            'name': 'frame_summary'}
    GOOD = {'frameCount': 600, 'slowFrameCount': 3, 'durationMs': 80, 'refreshRateHz': 120,
            'buildMode': 'release'}

    def valid(self, **changes):
        from tool.analytics_receiver import valid_event
        return valid_event({**self.BASE, 'attributes': {**self.GOOD, **changes}})

    def test_accepts_a_window_and_rejects_out_of_range_or_inconsistent_values(self):
        self.assertTrue(self.valid())
        self.assertTrue(self.valid(slowFrameCount=0))
        self.assertTrue(self.valid(slowFrameCount=600))
        self.assertFalse(self.valid(slowFrameCount=601))
        self.assertFalse(self.valid(frameCount=0))
        self.assertFalse(self.valid(frameCount=100001, slowFrameCount=0))
        self.assertFalse(self.valid(refreshRateHz=23))
        self.assertFalse(self.valid(refreshRateHz=241))
        self.assertFalse(self.valid(buildMode='beta'))
        self.assertFalse(self.valid(refreshRateHz=120.0))

    def test_missing_or_extra_attributes_are_rejected(self):
        from tool.analytics_receiver import valid_event
        partial = {k: v for k, v in self.GOOD.items() if k != 'buildMode'}
        self.assertFalse(valid_event({**self.BASE, 'attributes': partial}))
        self.assertFalse(self.valid(screen='calendar'))


class StartupMilestoneTests(unittest.TestCase):
    BASE = {'eventId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'occurredAt': '2026-10-19T00:00:00Z',
            'name': 'startup_milestone'}

    def valid(self, attributes):
        from tool.analytics_receiver import valid_event
        return valid_event({**self.BASE, 'attributes': attributes})

    def test_known_milestones_only(self):
        self.assertTrue(self.valid({'milestone': 'firstCalendarFrame', 'durationMs': 800}))
        self.assertTrue(self.valid({'milestone': 'localCalendarReady', 'durationMs': 120000, 'durationTruncated': True}))
        self.assertFalse(self.valid({'milestone': 'syncDone', 'durationMs': 800}))
        self.assertFalse(self.valid({'milestone': 'firstCalendarFrame'}))
        self.assertFalse(self.valid({'milestone': 'firstCalendarFrame', 'durationMs': -1}))


class SyncAttemptTests(unittest.TestCase):
    BASE = {'eventId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'occurredAt': '2026-10-19T00:00:00Z'}

    def valid(self, name, attributes):
        from tool.analytics_receiver import valid_event
        return valid_event({**self.BASE, 'name': name, 'attributes': attributes})

    def test_attempt_is_optional_and_only_two_to_six(self):
        start = {'operation': 'backup', 'trigger': 'manual'}
        self.assertTrue(self.valid('sync_started', start))
        self.assertTrue(self.valid('sync_started', {**start, 'attempt': 2}))
        for bad in (0, 1, 7, '2', None, 2.0):
            self.assertFalse(self.valid('sync_started', {**start, 'attempt': bad}))

    def test_abandoned_event_contract(self):
        good = {'operation': 'backup', 'trigger': 'manual', 'reason': 'sessionChanged', 'durationMs': 5}
        self.assertTrue(self.valid('sync_abandoned', good))
        self.assertTrue(self.valid('sync_abandoned', {**good, 'attempt': 3, 'durationTruncated': True}))
        self.assertFalse(self.valid('sync_abandoned', {**good, 'reason': 'crash'}))
        self.assertFalse(self.valid('sync_abandoned', {**good, 'errorCode': 'unknown'}))


def _payload():
    return {
        "report": {
            "title": "일정 저장 실패",
            "description": "저장 버튼을 눌러도 일정이 보이지 않습니다.",
            "reproductionSteps": "1. 일정을 추가합니다.\n2. 저장을 누릅니다.",
            "expectedBehavior": "월간 달력에 일정이 표시됩니다.",
            "actualBehavior": "일정이 표시되지 않습니다.",
        },
        "environment": {
            "version": "3.2.0",
            "buildNumber": "3.2.0",
            "platform": "macOS",
            "osVersion": "Version 26.5.2",
        },
    }


class BugReportBackendTest(unittest.TestCase):
    def test_normalizes_the_expected_report_schema(self):
        self.assertEqual(normalize_bug_report(_payload()), _payload())

        invalid = _payload()
        invalid["report"]["title"] = " "
        self.assertIsNone(normalize_bug_report(invalid))

    def test_creates_an_issue_without_publishing_the_email(self):
        with tempfile.TemporaryDirectory() as directory:
            captured = {}

            def create_issue(title, body):
                captured["title"] = title
                captured["body"] = body
                return {
                    "number": 321,
                    "html_url": "https://github.com/littlebit0/DailyCalendar/issues/321",
                }

            backend = BugReportBackend(
                directory,
                github_token="test-token",
                github_repository="littlebit0/DailyCalendar",
                google_identity_fetcher=lambda _authorization: {
                    "sub": "google-subject-1",
                    "email": "daily-user@example.com",
                    "email_verified": True,
                },
                github_issue_creator=create_issue,
            )

            submission = backend.submit(_payload(), "Bearer google-access-token")

            self.assertEqual(submission["issueNumber"], 321)
            self.assertEqual(captured["title"], "[Bug] 일정 저장 실패")
            self.assertNotIn("daily-user@example.com", captured["body"])
            self.assertIn("Google 로그인: 서버 검증 완료", captured["body"])

            contacts = list((Path(directory) / "bug-report-contacts").glob("*.json"))
            self.assertEqual(len(contacts), 1)
            stored = json.loads(contacts[0].read_text())
            self.assertEqual(stored["email"], "daily-user@example.com")
            self.assertEqual(stored["issueNumber"], 321)
            self.assertNotIn("google-subject-1", contacts[0].read_text())
            self.assertEqual(stat.S_IMODE(contacts[0].stat().st_mode), 0o600)

    def test_rejects_an_unverified_google_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            backend = BugReportBackend(
                directory,
                github_token="test-token",
                google_identity_fetcher=lambda _authorization: {
                    "sub": "google-subject-1",
                    "email": "daily-user@example.com",
                    "email_verified": False,
                },
                github_issue_creator=lambda _title, _body: {},
            )

            with self.assertRaises(InvalidGoogleToken):
                backend.submit(_payload(), "Bearer invalid-token")

    def test_limits_each_verified_google_account_to_five_reports_per_hour(self):
        with tempfile.TemporaryDirectory() as directory:
            issue_number = 0

            def create_issue(_title, _body):
                nonlocal issue_number
                issue_number += 1
                return {
                    "number": issue_number,
                    "html_url": (
                        "https://github.com/littlebit0/DailyCalendar/issues/"
                        f"{issue_number}"
                    ),
                }

            backend = BugReportBackend(
                directory,
                github_token="test-token",
                google_identity_fetcher=lambda _authorization: {
                    "sub": "google-subject-1",
                    "email": "daily-user@example.com",
                    "email_verified": True,
                },
                github_issue_creator=create_issue,
            )

            for _ in range(5):
                backend.submit(_payload(), "Bearer google-access-token")
            with self.assertRaises(BugReportRateLimited):
                backend.submit(_payload(), "Bearer google-access-token")


if __name__ == "__main__":
    unittest.main()
