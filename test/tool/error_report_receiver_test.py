import tempfile
import unittest
from datetime import datetime, timedelta, timezone

from tool.analytics_receiver import (
    BugReportRateLimited,
    ErrorReportBackend,
    InvalidGoogleToken,
    MAX_NEW_ERROR_ISSUES_PER_DAY,
    UpstreamUnavailable,
    normalize_error_report,
)


def payload(fingerprint="0123456789abcdef", message="boom", environment="production", version="6.1.0"):
    return {
        "report": {
            "fingerprint": fingerprint,
            "severity": "fatal",
            "feature": "drive_sync",
            "errorType": "StateError",
            "message": message,
            "stackTrace": "#0 Foo.bar (package:daily/x.dart:1:2)",
            "firstOccurredAt": "2026-11-05T00:00:00.000Z",
            "lastOccurredAt": "2026-11-05T00:01:00.000Z",
            "occurrenceCount": 1,
            "lifecycle": "resumed",
        },
        "environment": {
            "version": version,
            "buildNumber": "100",
            "platform": "macOS",
            "osVersion": "Version 27.2",
            "deviceType": "desktop",
            "locale": "ko-KR",
            "timeZone": "UTC+09:00",
            "environment": environment,
        },
        "integrations": {"driveLinked": True, "lmsConnected": False, "lastDriveSyncAt": None},
    }


class FakeGitHub:
    def __init__(self):
        self.issues = []
        self.comments = []
        self.fail_create = False

    def create(self, title, body):
        if self.fail_create:
            raise UpstreamUnavailable()
        number = len(self.issues) + 1
        issue = {"number": number, "html_url": f"https://github.com/littlebit0/DailyCalendar/issues/{number}", "title": title, "body": body}
        self.issues.append(issue)
        return issue

    def comment(self, number, body):
        self.comments.append((number, body))

    def find(self, fingerprint):
        for issue in self.issues:
            if f"AutoBug fingerprint: `{fingerprint}`" in issue["body"]:
                return issue
        return None


class ErrorReportTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.github = FakeGitHub()
        self.now = datetime(2026, 11, 5, tzinfo=timezone.utc)
        self.backend = self.make_backend()

    def tearDown(self):
        self.directory.cleanup()

    def make_backend(self):
        return ErrorReportBackend(
            self.directory.name,
            github_token="unused",
            github_repository="littlebit0/DailyCalendar",
            google_identity_fetcher=lambda auth: {"sub": "user", "email": "a@b.co", "email_verified": True},
            github_issue_creator=self.github.create,
            github_comment_creator=self.github.comment,
            github_fingerprint_finder=self.github.find,
            now=lambda: self.now,
        )

    def submit(self, value):
        return self.backend.submit_error(normalize_error_report(value), "Bearer x")

    def test_same_fingerprint_ten_times_creates_one_issue(self):
        for _ in range(10):
            self.submit(payload())
        self.assertEqual(len(self.github.issues), 1)
        self.assertEqual(self.github.comments, [])

    def test_new_environment_comments_once_per_interval(self):
        self.submit(payload())
        self.submit(payload(version="6.2.0"))
        self.submit(payload(version="6.3.0"))
        self.assertEqual(len(self.github.comments), 1)
        self.now += timedelta(hours=25)
        self.submit(payload(version="6.3.0"))
        self.assertEqual(len(self.github.comments), 2)
        self.assertEqual(len(self.github.issues), 1)

    def test_existing_issue_found_without_index(self):
        self.submit(payload())
        self.backend.index_path.unlink()
        result = self.make_backend().submit_error(normalize_error_report(payload()), "Bearer x")
        self.assertEqual(result["status"], "existing")
        self.assertEqual(len(self.github.issues), 1)

    def test_daily_new_issue_cap(self):
        for number in range(MAX_NEW_ERROR_ISSUES_PER_DAY):
            self.submit(payload(fingerprint=f"{number:016x}"))
        with self.assertRaises(BugReportRateLimited):
            self.submit(payload(fingerprint="f" * 16))

    def test_subject_rate_limit(self):
        with self.assertRaises(BugReportRateLimited):
            for _ in range(100):
                self.submit(payload())

    def test_github_failure_raises_and_keeps_no_index(self):
        self.github.fail_create = True
        with self.assertRaises(UpstreamUnavailable):
            self.submit(payload())
        self.github.fail_create = False
        self.assertEqual(self.submit(payload())["status"], "created")

    def test_unverified_google_account_rejected(self):
        backend = self.make_backend()
        backend._google_identity_fetcher = lambda auth: {"sub": "user", "email_verified": False}
        with self.assertRaises(InvalidGoogleToken):
            backend.submit_error(normalize_error_report(payload()), "Bearer x")

    def test_debug_reports_and_bad_schema_rejected(self):
        self.assertIsNone(normalize_error_report(payload(environment="debug")))
        bad = payload()
        bad["report"]["extra"] = "x"
        self.assertIsNone(normalize_error_report(bad))
        self.assertIsNone(normalize_error_report(payload(fingerprint="xyz")))

    def test_new_build_number_is_a_new_environment(self):
        self.submit(payload())
        value = payload()
        value["environment"]["buildNumber"] = "101"
        self.submit(value)
        self.assertEqual(len(self.github.comments), 1)

    def test_retried_delivery_is_counted_once(self):
        delivery = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
        normalized = normalize_error_report(payload())
        self.backend.submit_error(normalized, "Bearer x", delivery)
        self.backend.submit_error(normalized, "Bearer x", delivery)
        self.backend.submit_error(normalized, "Bearer x", delivery)
        self.backend.submit_error(normalized, "Bearer x", "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
        entry = self.backend._read_index()["fingerprints"]["0123456789abcdef"]
        self.assertEqual(entry["occurrences"], 2)
        self.assertEqual(len(self.github.issues), 1)

    def test_retried_delivery_counts_occurrences_added_later(self):
        delivery = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
        self.backend.submit_error(normalize_error_report(payload()), "Bearer x", delivery)
        value = payload()
        value["report"]["occurrenceCount"] = 3
        self.backend.submit_error(normalize_error_report(value), "Bearer x", delivery)
        self.backend.submit_error(normalize_error_report(value), "Bearer x", delivery)
        entry = self.backend._read_index()["fingerprints"]["0123456789abcdef"]
        self.assertEqual(entry["occurrences"], 3)

    def test_failed_environment_comment_is_retried(self):
        self.submit(payload())
        delivery = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
        normalized = normalize_error_report(payload(version="6.2.0"))
        failing = self.github.comment

        def outage(number, body):
            raise UpstreamUnavailable()

        self.backend._github_comment_creator = outage
        with self.assertRaises(UpstreamUnavailable):
            self.backend.submit_error(normalized, "Bearer x", delivery)
        self.backend._github_comment_creator = failing
        self.backend.submit_error(normalized, "Bearer x", delivery)
        self.assertEqual(len(self.github.comments), 1)
        entry = self.backend._read_index()["fingerprints"]["0123456789abcdef"]
        self.assertEqual(entry["occurrences"], 2)

    def test_long_build_numbers_are_accepted(self):
        for build in ("100000", "2026110501"):
            value = payload()
            value["environment"]["buildNumber"] = build
            normalized = normalize_error_report(value)
            self.assertIsNotNone(normalized, build)
            self.assertEqual(normalized["environment"]["buildNumber"], build)

    def test_fingerprint_lookup_reads_every_page(self):
        backend = ErrorReportBackend(self.directory.name, github_token="t", github_repository="littlebit0/DailyCalendar")
        pages = []

        def request(method, path, body=None):
            page = int(path.rsplit("page=", 1)[1])
            pages.append(page)
            start = (page - 1) * 100
            count = 100 if page < 3 else 5
            return [
                {
                    "number": n,
                    "html_url": f"https://github.com/littlebit0/DailyCalendar/issues/{n}",
                    "body": f"AutoBug fingerprint: `{n:016x}`",
                }
                for n in range(start + 1, start + count + 1)
            ]

        backend._github_request = request
        self.assertEqual(backend._find_fingerprint_issue(f"{203:016x}")["number"], 203)
        self.assertEqual(pages, [1, 2, 3])
        pages.clear()
        self.assertIsNone(backend._find_fingerprint_issue("f" * 16))
        self.assertEqual(pages, [1, 2, 3])

    def test_server_masks_secrets_again(self):
        message = (
            "Authorization: Bearer ya29.secret token=abc123 mail kim@example.com "
            "path /Users/kimhwi/Library title \"Dentist\" id 2026123456"
        )
        cleaned = normalize_error_report(payload(message=message))["report"]["message"]
        for secret in ("ya29.secret", "abc123", "kim@example.com", "kimhwi", "Dentist", "2026123456"):
            self.assertNotIn(secret, cleaned)
        self.submit(payload(message=message))
        body = self.github.issues[0]["body"]
        for secret in ("ya29.secret", "abc123", "kim@example.com", "kimhwi", "Dentist", "a@b.co"):
            self.assertNotIn(secret, body)
        self.assertIn("AutoBug fingerprint: `0123456789abcdef`", body)


if __name__ == "__main__":
    unittest.main()
