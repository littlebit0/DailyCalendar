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


class DedupeAcrossMidnightTests(unittest.TestCase):
    def batch(self):
        return {
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

    def count(self, directory):
        total = 0
        for path in Path(directory).glob('analytics-*.json'):
            groups = json.loads(path.read_text())['groups'].values()
            total += sum(group['count'] for group in groups)
        return total

    def test_a_retry_after_utc_midnight_is_not_counted_again(self):
        from datetime import datetime, timedelta, timezone
        with tempfile.TemporaryDirectory() as directory:
            clock = [datetime(2026, 10, 13, 23, 59, tzinfo=timezone.utc)]
            aggregator = Aggregator(directory, now=lambda: clock[0])
            self.assertEqual(aggregator.accept(self.batch()), 1)
            self.assertEqual(aggregator.accept(self.batch()), 0)
            clock[0] += timedelta(minutes=2)  # the next UTC day
            self.assertEqual(aggregator.accept(self.batch()), 0)
            self.assertEqual(self.count(directory), 1)

    def test_a_retry_seven_calendar_days_later_is_still_deduplicated(self):
        from datetime import datetime, timedelta, timezone
        with tempfile.TemporaryDirectory() as directory:
            # Accepted late on Oct 1, retried early on Oct 8: under seven days
            # apart, and the Oct 1 dedupe file is still retained.
            clock = [datetime(2026, 10, 1, 23, 30, tzinfo=timezone.utc)]
            aggregator = Aggregator(directory, now=lambda: clock[0])
            self.assertEqual(aggregator.accept(self.batch()), 1)
            clock[0] = datetime(2026, 10, 8, 1, 0, tzinfo=timezone.utc)
            self.assertEqual(aggregator.accept(self.batch()), 0)
            self.assertEqual(self.count(directory), 1)
            self.assertTrue((Path(directory) / 'dedupe-2026-10-01.json').exists())
            # One more day and the file is gone, so the event counts again.
            clock[0] = datetime(2026, 10, 9, 1, 0, tzinfo=timezone.utc)
            self.assertEqual(aggregator.accept(self.batch()), 1)

    def test_an_event_older_than_the_retention_window_counts_again(self):
        from datetime import datetime, timedelta, timezone
        with tempfile.TemporaryDirectory() as directory:
            clock = [datetime(2026, 10, 1, 12, tzinfo=timezone.utc)]
            aggregator = Aggregator(directory, now=lambda: clock[0])
            self.assertEqual(aggregator.accept(self.batch()), 1)
            clock[0] += timedelta(days=8)
            self.assertEqual(aggregator.accept(self.batch()), 1)


class AtomicAggregateTests(DedupeAcrossMidnightTests):
    """Same batch/count helpers as the midnight tests."""

    def test_a_failed_dedupe_write_is_finished_so_the_retry_counts_once(self):
        from unittest import mock
        with tempfile.TemporaryDirectory() as directory:
            aggregator = Aggregator(directory)
            original = aggregator._write_json
            calls = {'dedupe': 0}

            def flaky(path, value):
                if path.name.startswith('dedupe-') and calls['dedupe'] == 0:
                    calls['dedupe'] += 1
                    raise OSError('disk full')
                return original(path, value)

            with mock.patch.object(aggregator, '_write_json', side_effect=flaky):
                with self.assertRaises(OSError):
                    aggregator.accept(self.batch())
                # The retry finishes the interrupted request: the event is
                # already counted, so it is not counted a second time.
                self.assertEqual(aggregator.accept(self.batch()), 0)
            self.assertEqual(self.count(directory), 1)
            self.assertFalse((Path(directory) / 'pending-transaction.json').exists())
            self.assertEqual(len(list(Path(directory).glob('dedupe-*.json'))), 1)

    def test_storage_that_stays_down_cannot_double_count_after_it_recovers(self):
        from unittest import mock
        with tempfile.TemporaryDirectory() as directory:
            aggregator = Aggregator(directory)
            original = aggregator._write_json

            def down(path, value):
                # Only the single journal file can still be written.
                if path.name.startswith(('analytics-', 'dedupe-')):
                    raise OSError('I/O error')
                return original(path, value)

            with mock.patch.object(aggregator, '_write_json', side_effect=down):
                for _ in range(3):  # several retries while storage is down
                    with self.assertRaises(OSError):
                        aggregator.accept(self.batch())
            self.assertTrue((Path(directory) / 'pending-transaction.json').exists())
            # Storage is back: the pending transaction is finished first.
            self.assertEqual(aggregator.accept(self.batch()), 0)
            self.assertEqual(self.count(directory), 1)
            self.assertFalse((Path(directory) / 'pending-transaction.json').exists())

    def test_a_failure_before_the_journal_changes_nothing(self):
        from unittest import mock
        with tempfile.TemporaryDirectory() as directory:
            aggregator = Aggregator(directory)
            with mock.patch.object(aggregator, '_write_json', side_effect=OSError('full')):
                with self.assertRaises(OSError):
                    aggregator.accept(self.batch())
            self.assertEqual(self.count(directory), 0)
            self.assertEqual(aggregator.accept(self.batch()), 1)
            self.assertEqual(self.count(directory), 1)

    def test_an_unreadable_journal_does_not_block_intake(self):
        with tempfile.TemporaryDirectory() as directory:
            (Path(directory) / 'pending-transaction.json').write_text('{not json')
            self.assertEqual(Aggregator(directory).accept(self.batch()), 1)

    def test_totals_from_earlier_requests_survive_a_later_failure(self):
        from unittest import mock
        with tempfile.TemporaryDirectory() as directory:
            aggregator = Aggregator(directory)
            self.assertEqual(aggregator.accept(self.batch()), 1)
            second = self.batch()
            second['events'][0]['eventId'] = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'
            original = aggregator._write_json

            def flaky(path, value):
                if path.name.startswith('dedupe-'):
                    raise OSError('disk full')
                return original(path, value)

            with mock.patch.object(aggregator, '_write_json', side_effect=flaky):
                with self.assertRaises(OSError):
                    aggregator.accept(second)
            # Finished by the next request; neither event is lost or doubled.
            self.assertEqual(aggregator.accept(second), 0)
            self.assertEqual(aggregator.accept(self.batch()), 0)
            self.assertEqual(self.count(directory), 2)


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
