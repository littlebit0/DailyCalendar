import json
import os
import stat
import tempfile
from pathlib import Path
import unittest
from datetime import datetime, timedelta, timezone

from tool.analytics_receiver import (
    BugReportRateLimited,
    ErrorReportStore,
    InvalidGoogleToken,
    MAX_ERROR_FINGERPRINTS_PER_DAY,
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


DELIVERY = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"


class ErrorReportTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.now = datetime(2026, 11, 5, 3, tzinfo=timezone.utc)
        self.store = self.make_store()

    def tearDown(self):
        self.directory.cleanup()

    def make_store(self):
        return ErrorReportStore(
            self.directory.name,
            google_identity_fetcher=lambda auth: {"sub": "user", "email": "a@b.co", "email_verified": True},
            now=lambda: self.now,
        )

    def submit(self, value, delivery=None):
        return self.store.submit_error(normalize_error_report(value), "Bearer x", delivery)

    def export(self, day="2026-11-05"):
        return json.loads((Path(self.directory.name) / f"error-reports-{day}.json").read_text())

    def test_same_fingerprint_is_one_entry_with_counts(self):
        for _ in range(10):
            self.submit(payload())
        reports = self.export()["reports"]
        self.assertEqual(len(reports), 1)
        self.assertEqual(reports[0]["occurrences"], 10)
        self.assertEqual(reports[0]["fingerprint"], "0123456789abcdef")
        # The day file alone must be enough to write an issue.
        for key in ("fingerprint", "firstOccurredAt", "lastOccurredAt", "occurrences", "message", "stackTrace", "errorType", "feature", "severity"):
            self.assertTrue(reports[0][key], key)
        environment = reports[0]["environments"][0]
        for key in ("version", "buildNumber", "platform", "osVersion", "environment", "deviceType"):
            self.assertTrue(environment[key], key)

    def test_environments_are_listed_per_build_and_os(self):
        self.submit(payload())
        self.submit(payload(version="6.2.0"))
        value = payload()
        value["environment"]["buildNumber"] = "101"
        self.submit(value)
        self.submit(payload())
        environments = self.export()["reports"][0]["environments"]
        self.assertEqual(len(environments), 3)
        counts = {(e["version"], e["buildNumber"]): e["occurrences"] for e in environments}
        self.assertEqual(counts[("6.1.0", "100")], 2)
        self.assertTrue(all("driveLinked" in e for e in environments))

    def test_retried_delivery_adds_only_new_occurrences(self):
        self.submit(payload(), DELIVERY)
        self.submit(payload(), DELIVERY)
        value = payload()
        value["report"]["occurrenceCount"] = 3
        self.submit(value, DELIVERY)
        self.submit(value, DELIVERY)
        self.submit(payload(), "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
        self.assertEqual(self.export()["reports"][0]["occurrences"], 4)

    def test_days_are_stored_separately_and_expire(self):
        self.submit(payload())
        self.now += timedelta(days=1)
        self.submit(payload())
        self.assertEqual(self.export("2026-11-06")["reports"][0]["occurrences"], 1)
        self.now += timedelta(days=91)
        self.submit(payload(fingerprint="f" * 16))
        directory = Path(self.directory.name)
        self.assertFalse((directory / "error-reports-2026-11-05.json").exists())
        self.assertFalse((directory / "error-reports-2026-11-06.json").exists())

    def test_failed_export_is_written_by_a_later_request(self):
        original = self.store._write_json

        def failing(path, value):
            raise OSError("disk full")

        self.store._write_json = failing
        self.assertEqual(self.submit(payload())["status"], "stored")
        self.store._write_json = original
        self.now += timedelta(days=1)
        self.submit(payload(fingerprint="f" * 16))
        self.assertEqual(self.export("2026-11-05")["reports"][0]["occurrences"], 1)
        self.assertEqual(self.export("2026-11-06")["reports"][0]["fingerprint"], "f" * 16)

    def test_concurrent_requests_leave_the_latest_export(self):
        import threading

        threads = [threading.Thread(target=self.submit, args=(payload(),)) for _ in range(8)]
        for thread in threads:
            thread.start()
        for thread in threads:
            thread.join()
        self.assertEqual(self.export()["reports"][0]["occurrences"], 8)

    def test_expire_runs_without_a_new_report(self):
        import sqlite3

        self.submit(payload())
        self.now += timedelta(days=91)
        self.make_store().expire()
        directory = Path(self.directory.name)
        self.assertFalse((directory / "error-reports-2026-11-05.json").exists())
        with sqlite3.connect(directory / "error-reports-state.sqlite") as connection:
            self.assertEqual(connection.execute("SELECT COUNT(*) FROM reports").fetchone()[0], 0)

    def test_files_are_private(self):
        self.submit(payload())
        directory = Path(self.directory.name)
        for name in ("error-reports-state.sqlite", "error-reports-2026-11-05.json"):
            self.assertEqual(stat.S_IMODE(os.stat(directory / name).st_mode), 0o600, name)

    def test_daily_fingerprint_cap(self):
        for number in range(MAX_ERROR_FINGERPRINTS_PER_DAY):
            self.store._rate_windows.clear()
            self.submit(payload(fingerprint=f"{number:016x}"))
        with self.assertRaises(BugReportRateLimited):
            self.submit(payload(fingerprint="f" * 16))

    def test_subject_rate_limit(self):
        with self.assertRaises(BugReportRateLimited):
            for _ in range(100):
                self.submit(payload())

    def test_unverified_google_account_rejected(self):
        store = self.make_store()
        store._google_identity_fetcher = lambda auth: {"sub": "user", "email_verified": False}
        with self.assertRaises(InvalidGoogleToken):
            store.submit_error(normalize_error_report(payload()), "Bearer x")

    def test_debug_reports_and_bad_schema_rejected(self):
        self.assertIsNone(normalize_error_report(payload(environment="debug")))
        bad = payload()
        bad["report"]["extra"] = "x"
        self.assertIsNone(normalize_error_report(bad))
        self.assertIsNone(normalize_error_report(payload(fingerprint="xyz")))

    def test_server_masks_secrets_and_stores_no_account(self):
        message = (
            "Authorization: Bearer ya29.secret token=abc123 mail kim@example.com "
            "path /Users/kimhwi/Library title \"Dentist\" id 2026123456"
        )
        cleaned = normalize_error_report(payload(message=message))["report"]["message"]
        for secret in ("ya29.secret", "abc123", "kim@example.com", "kimhwi", "Dentist", "2026123456"):
            self.assertNotIn(secret, cleaned)
        self.submit(payload(message=message))
        directory = Path(self.directory.name)
        stored = (directory / "error-reports-2026-11-05.json").read_text()
        stored += (directory / "error-reports-state.sqlite").read_bytes().decode("utf-8", "replace")
        for secret in ("ya29.secret", "abc123", "kim@example.com", "kimhwi", "Dentist", "a@b.co", "user"):
            self.assertNotIn(secret, stored)

    def test_unterminated_quoted_text_is_masked(self):
        message = 'FormatException: Unterminated string\n{"title": "Oncology appointment with Dr Smith'
        cleaned = normalize_error_report(payload(message=message))["report"]["message"]
        self.assertNotIn("Oncology", cleaned)
        self.assertNotIn("Smith", cleaned)

    def test_long_build_numbers_are_accepted(self):
        for build in ("100000", "2026110501"):
            value = payload()
            value["environment"]["buildNumber"] = build
            normalized = normalize_error_report(value)
            self.assertIsNotNone(normalized, build)
            self.assertEqual(normalized["environment"]["buildNumber"], build)


if __name__ == "__main__":
    unittest.main()
