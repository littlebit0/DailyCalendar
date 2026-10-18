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


class BuildNumberTests(unittest.TestCase):
    def test_real_build_numbers_and_unknown_are_accepted(self):
        for value in ("400", "4.0.0", "4.0.0.12", "unknown"):
            payload = _payload()
            payload["environment"]["buildNumber"] = value
            self.assertIsNotNone(normalize_bug_report(payload), value)
        for value in ("abc", "4.0.0+1", "1.2.3.4.5", "4 0"):
            payload = _payload()
            payload["environment"]["buildNumber"] = value
            self.assertIsNone(normalize_bug_report(payload), value)


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
