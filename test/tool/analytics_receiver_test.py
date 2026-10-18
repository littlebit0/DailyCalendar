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
    UpstreamUnavailable,
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


class MalformedTypeTests(unittest.TestCase):
    """Valid JSON of the wrong type is rejected, never an exception."""

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

    def test_unhashable_platform_name_and_outcome_are_invalid_not_errors(self):
        for bad in ([], {}, [1], {'a': 1}, None, 3):
            batch = self.batch()
            batch['environment']['platform'] = bad
            self.assertFalse(valid_batch(batch), f'platform {bad!r}')
            batch = self.batch()
            batch['events'][0]['name'] = bad
            self.assertFalse(valid_batch(batch), f'name {bad!r}')
            batch = self.batch()
            batch['events'][0]['name'] = 'sync_failed'
            batch['events'][0]['attributes'] = {
                'operation': 'upload',
                'trigger': 'manual',
                'outcome': bad,
                'durationMs': 5,
                'errorCode': 'network',
            }
            self.assertFalse(valid_batch(batch), f'outcome {bad!r}')

    def test_the_normal_batch_is_still_accepted(self):
        self.assertTrue(valid_batch(self.batch()))


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


REQUEST_A = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
REQUEST_B = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"


class _FakeGithub:
    """Stands in for GitHub; the creation can succeed while its answer is lost."""

    def __init__(self):
        self.issues = []
        self.lose_answer = False
        self.fail_before_create = False
        self.find_fails = False

    def create(self, title, body):
        if self.fail_before_create:
            raise UpstreamUnavailable()
        number = len(self.issues) + 1
        issue = {
            "number": number,
            "html_url": f"https://github.com/littlebit0/DailyCalendar/issues/{number}",
            "body": body,
        }
        self.issues.append(issue)
        if self.lose_answer:
            raise UpstreamUnavailable()
        return issue

    def find(self, report_id):
        if self.find_fails:
            raise UpstreamUnavailable()
        for issue in self.issues:
            if f"`{report_id}`" in issue["body"]:
                return issue
        return None


class IdempotentBugReportTest(unittest.TestCase):
    def backend(self, directory, github, subject="google-subject-1"):
        return BugReportBackend(
            directory,
            github_token="test-token",
            google_identity_fetcher=lambda _authorization: {
                "sub": subject,
                "email": "daily-user@example.com",
                "email_verified": True,
            },
            github_issue_creator=github.create,
            github_issue_finder=github.find,
        )

    def submit(self, backend, request_id):
        return backend.submit(_payload(), "Bearer token", request_id)

    def test_lost_answer_retry_reuses_the_created_issue_and_keeps_the_contact(self):
        with tempfile.TemporaryDirectory() as directory:
            github = _FakeGithub()
            backend = self.backend(directory, github)
            github.lose_answer = True
            with self.assertRaises(UpstreamUnavailable):
                self.submit(backend, REQUEST_A)
            contacts = list((Path(directory) / "bug-report-contacts").glob("*.json"))
            self.assertEqual(len(contacts), 1)
            github.lose_answer = False
            retried = self.submit(backend, REQUEST_A)
            self.assertEqual(len(github.issues), 1)
            self.assertEqual(retried["issueNumber"], 1)
            stored = json.loads(contacts[0].read_text())
            self.assertEqual(stored["status"], "created")
            self.assertEqual(stored["issueNumber"], 1)
            # Replaying a finished request returns the same issue without a new one.
            self.assertEqual(self.submit(backend, REQUEST_A)["issueNumber"], 1)
            self.assertEqual(len(github.issues), 1)

    def test_retry_after_a_failure_before_creation_creates_exactly_one_issue(self):
        with tempfile.TemporaryDirectory() as directory:
            github = _FakeGithub()
            backend = self.backend(directory, github)
            github.fail_before_create = True
            with self.assertRaises(UpstreamUnavailable):
                self.submit(backend, REQUEST_A)
            github.fail_before_create = False
            self.assertEqual(self.submit(backend, REQUEST_A)["issueNumber"], 1)
            self.assertEqual(len(github.issues), 1)
            self.assertEqual(len(list((Path(directory) / "bug-report-contacts").glob("*.json"))), 1)

    def test_unresolvable_lookup_never_creates_a_second_issue(self):
        with tempfile.TemporaryDirectory() as directory:
            github = _FakeGithub()
            backend = self.backend(directory, github)
            github.lose_answer = True
            with self.assertRaises(UpstreamUnavailable):
                self.submit(backend, REQUEST_A)
            github.find_fails = True
            with self.assertRaises(UpstreamUnavailable):
                self.submit(backend, REQUEST_A)
            self.assertEqual(len(github.issues), 1)

    def test_distinct_requests_and_accounts_stay_separate(self):
        with tempfile.TemporaryDirectory() as directory:
            github = _FakeGithub()
            backend = self.backend(directory, github)
            self.assertEqual(self.submit(backend, REQUEST_A)["issueNumber"], 1)
            self.assertEqual(self.submit(backend, REQUEST_B)["issueNumber"], 2)
            other = self.backend(directory, github, subject="google-subject-2")
            self.assertEqual(self.submit(other, REQUEST_A)["issueNumber"], 3)

    def test_without_a_request_id_a_failed_report_leaves_no_contact(self):
        with tempfile.TemporaryDirectory() as directory:
            github = _FakeGithub()
            backend = self.backend(directory, github)
            github.fail_before_create = True
            with self.assertRaises(UpstreamUnavailable):
                backend.submit(_payload(), "Bearer token")
            self.assertEqual(list((Path(directory) / "bug-report-contacts").glob("*.json")), [])

    def test_replaying_a_finished_request_does_not_use_the_hourly_limit(self):
        with tempfile.TemporaryDirectory() as directory:
            github = _FakeGithub()
            backend = self.backend(directory, github)
            for _ in range(10):
                self.submit(backend, REQUEST_A)
            self.assertEqual(len(github.issues), 1)


if __name__ == "__main__":
    unittest.main()
