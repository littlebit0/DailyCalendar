import json
import os
import stat
import tempfile
import unittest
from pathlib import Path

from tool.analytics_receiver import (
    Aggregator,
    BugReportBackend,
    BugReportRateLimited,
    InvalidGoogleToken,
    MAX_BUG_REPORT_BYTES,
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


class DurationTruncationTests(unittest.TestCase):
    BASE = {'eventId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'occurredAt': '2026-10-19T00:00:00Z'}

    def event(self, name, attributes):
        return {**self.BASE, 'name': name, 'attributes': attributes}

    def valid(self, name, attributes):
        from tool.analytics_receiver import valid_event
        return valid_event(self.event(name, attributes))

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

    def test_legacy_event_save_without_phase_is_still_accepted(self):
        # Apps before `phase` existed send neither field; the receiver is deployed first.
        self.assertTrue(self.valid('event_save_succeeded', {'operation': 'create', 'durationMs': 5}))
        self.assertTrue(self.valid('event_save_failed', {
            'operation': 'create', 'durationMs': 5, 'errorCode': 'unknown'}))
        self.assertFalse(self.valid('event_save_succeeded', {
            'operation': 'create', 'phase': 'later', 'durationMs': 5}))

    def test_truncated_flag_requires_the_capped_duration(self):
        self.assertTrue(self.valid('app_load_completed', {'durationMs': 120000, 'durationTruncated': True}))
        self.assertFalse(self.valid('app_load_completed', {'durationMs': 5, 'durationTruncated': True}))
        self.assertFalse(self.valid('app_load_completed', {'durationMs': 119999, 'durationTruncated': True}))

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


class BugReportSizeContractTests(unittest.TestCase):
    """Whatever the form allows must fit the receiver's request limit."""

    def payload(self, text, lengths):
        payload = _payload()
        for key, length in lengths.items():
            payload["report"][key] = text * length
        return payload

    def test_korean_reports_below_the_field_limits_fit_the_request_limit(self):
        # The case from the report: 3000 Korean characters in two fields.
        payload = self.payload("가", {"description": 3000, "reproductionSteps": 3000})
        self.assertIsNotNone(normalize_bug_report(payload))
        size = len(json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode())
        self.assertLess(size, MAX_BUG_REPORT_BYTES)

    def test_worst_case_form_input_fits(self):
        lengths = {
            "title": 120,
            "description": 4000,
            "reproductionSteps": 4000,
            "expectedBehavior": 2000,
            "actualBehavior": 2000,
        }
        for text in ("😀", "가", '"', "\n", "a"):
            payload = self.payload(text, lengths)
            if text == "\n":
                # Newlines are kept; keep at least one visible character.
                payload = self.payload("a\n", {k: v // 2 for k, v in lengths.items()})
            if normalize_bug_report(payload) is None:
                continue
            # Dart's jsonEncode writes non-ASCII as raw UTF-8 (no \\u escapes).
            size = len(json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode())
            self.assertLess(size, MAX_BUG_REPORT_BYTES, text)

    def test_the_request_limit_stays_bounded(self):
        self.assertLessEqual(MAX_BUG_REPORT_BYTES, 128 * 1024)


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

    def test_a_failure_while_counting_leaves_neither_totals_nor_dedupe(self):
        from unittest import mock
        with tempfile.TemporaryDirectory() as directory:
            aggregator = Aggregator(directory)
            with mock.patch.object(aggregator, '_count', side_effect=OSError('disk full')):
                with self.assertRaises(OSError):
                    aggregator.accept(self.batch())
            # The failed request left nothing behind, so its retry counts once.
            self.assertEqual(self.count(directory), 0)
            self.assertEqual(aggregator.accept(self.batch()), 1)
            self.assertEqual(self.count(directory), 1)

    def test_totals_from_earlier_requests_survive_a_later_failure(self):
        from unittest import mock
        with tempfile.TemporaryDirectory() as directory:
            aggregator = Aggregator(directory)
            self.assertEqual(aggregator.accept(self.batch()), 1)
            second = self.batch()
            second['events'][0]['eventId'] = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'
            with mock.patch.object(aggregator, '_count', side_effect=OSError('disk full')):
                with self.assertRaises(OSError):
                    aggregator.accept(second)
            self.assertEqual(self.count(directory), 1)
            self.assertEqual(aggregator.accept(second), 1)
            self.assertEqual(self.count(directory), 2)

    def test_a_failed_report_export_does_not_fail_or_double_count(self):
        from unittest import mock
        with tempfile.TemporaryDirectory() as directory:
            aggregator = Aggregator(directory)
            with mock.patch.object(aggregator, '_write_json', side_effect=OSError('read-only')):
                self.assertEqual(aggregator.accept(self.batch()), 1)
            # The retry is a duplicate; the report catches up on the next request.
            self.assertEqual(aggregator.accept(self.batch()), 0)
            self.assertEqual(self.count(directory), 1)


class IncrementalStorageTests(DedupeAcrossMidnightTests):
    def test_many_requests_never_write_a_growing_dedupe_file(self):
        with tempfile.TemporaryDirectory() as directory:
            aggregator = Aggregator(directory)
            for index in range(300):
                batch = self.batch()
                batch['events'][0]['eventId'] = f'00000000-0000-4000-8000-{index:012d}'
                self.assertEqual(aggregator.accept(batch), 1)
            self.assertEqual(self.count(directory), 300)
            self.assertEqual(list(Path(directory).glob('dedupe-*.json')), [])
            report = next(Path(directory).glob('analytics-*.json'))
            # One counter group, however many events: the report stays small.
            self.assertLess(report.stat().st_size, 2000)

    def test_earlier_json_state_is_imported_once(self):
        from datetime import datetime, timezone
        import hashlib
        with tempfile.TemporaryDirectory() as directory:
            today = datetime.now(timezone.utc).strftime('%Y-%m-%d')
            event_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
            digest = hashlib.sha256(event_id.encode()).hexdigest()
            group = {'appVersion': '4.1.2', 'platform': 'macos', 'osMajor': 27,
                     'name': 'app_load_completed', 'attributes': {'durationMs': 25},
                     'count': 5, 'durationTotalMs': 125, 'durationMaxMs': 25}
            key = json.dumps({k: group[k] for k in ('appVersion', 'platform', 'osMajor', 'name', 'attributes')},
                             ensure_ascii=True, sort_keys=True, separators=(',', ':'))
            (Path(directory) / f'analytics-{today}.json').write_text(
                json.dumps({'schemaVersion': 1, 'date': today, 'groups': {key: group}}))
            (Path(directory) / f'dedupe-{today}.json').write_text(json.dumps([digest]))
            aggregator = Aggregator(directory)
            # The event seen before the upgrade is still a duplicate ...
            self.assertEqual(aggregator.accept(self.batch()), 0)
            # ... and the old totals were kept.
            self.assertEqual(self.count(directory), 5)
            other = self.batch()
            other['events'][0]['eventId'] = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'
            self.assertEqual(aggregator.accept(other), 1)
            self.assertEqual(self.count(directory), 6)


class SqliteStateTests(DedupeAcrossMidnightTests):
    def event_batch(self, event_id):
        batch = self.batch()
        batch['events'][0]['eventId'] = event_id
        return batch

    def test_importing_a_hash_seen_on_several_days_keeps_the_newest_day(self):
        import hashlib
        import sqlite3
        from datetime import datetime, timezone
        with tempfile.TemporaryDirectory() as directory:
            event_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
            digest = hashlib.sha256(event_id.encode()).hexdigest()
            for day in ('2026-10-05', '2026-10-01', '2026-10-03'):
                (Path(directory) / f'dedupe-{day}.json').write_text(json.dumps([digest]))
            clock = datetime(2026, 10, 9, 12, tzinfo=timezone.utc)
            aggregator = Aggregator(directory, now=lambda: clock)
            # Cleanup (cutoff Oct 2) must not drop the Oct 5 sighting.
            self.assertEqual(aggregator.accept(self.batch()), 0)
            with sqlite3.connect(Path(directory) / 'analytics-state.sqlite') as db:
                days = db.execute('SELECT day FROM dedupe WHERE hash = ?', (digest,)).fetchall()
            self.assertEqual(days, [('2026-10-05',)])

    def test_sqlite_errors_become_storage_errors_for_the_http_handler(self):
        import sqlite3
        from unittest import mock
        with tempfile.TemporaryDirectory() as directory:
            aggregator = Aggregator(directory)
            for error in (sqlite3.OperationalError('database is locked'),
                          sqlite3.DatabaseError('file is not a database')):
                with mock.patch.object(aggregator, '_count', side_effect=error):
                    with self.assertRaises(OSError):
                        aggregator.accept(self.batch())
            self.assertEqual(aggregator.accept(self.batch()), 1)

    def test_state_is_private_even_under_a_permissive_umask(self):
        import stat
        old = os.umask(0o022)
        try:
            with tempfile.TemporaryDirectory() as parent:
                directory = Path(parent) / 'analytics'
                aggregator = Aggregator(directory)
                self.assertEqual(aggregator.accept(self.batch()), 1)
                self.assertEqual(stat.S_IMODE(directory.stat().st_mode), 0o700)
                database = directory / 'analytics-state.sqlite'
                self.assertEqual(stat.S_IMODE(database.stat().st_mode), 0o600)
                for extra in directory.glob('analytics-state.sqlite-*'):
                    self.assertEqual(stat.S_IMODE(extra.stat().st_mode) & 0o077, 0)
        finally:
            os.umask(old)

    def test_retention_cleanup_uses_an_index_on_the_day(self):
        import sqlite3
        with tempfile.TemporaryDirectory() as directory:
            Aggregator(directory).accept(self.batch())
            with sqlite3.connect(Path(directory) / 'analytics-state.sqlite') as db:
                indexes = [row[1] for row in db.execute('PRAGMA index_list(dedupe)')]
                self.assertIn('dedupe_day', indexes)
                plan = ' '.join(
                    str(row[3]) for row in db.execute(
                        "EXPLAIN QUERY PLAN DELETE FROM dedupe WHERE day < '2026-01-01'"))
            self.assertIn('dedupe_day', plan)

    def test_the_report_is_not_rewritten_on_every_request(self):
        from datetime import datetime, timedelta, timezone
        with tempfile.TemporaryDirectory() as directory:
            clock = [datetime(2026, 10, 13, 12, tzinfo=timezone.utc)]
            aggregator = Aggregator(directory, now=lambda: clock[0], export_interval=60)
            report = None

            def reported():
                return self.count(directory)

            self.assertEqual(aggregator.accept(self.event_batch('00000000-0000-4000-8000-000000000001')), 1)
            self.assertEqual(reported(), 1)  # the first request exports
            clock[0] += timedelta(seconds=10)
            self.assertEqual(aggregator.accept(self.event_batch('00000000-0000-4000-8000-000000000002')), 1)
            self.assertEqual(aggregator.accept(self.batch()), 1)
            self.assertEqual(reported(), 1, 'within the interval the report is not rebuilt')
            # A duplicate-only request changes nothing and exports nothing.
            self.assertEqual(aggregator.accept(self.batch()), 0)
            clock[0] += timedelta(seconds=61)
            self.assertEqual(aggregator.accept(self.batch()), 0)
            self.assertEqual(reported(), 3, 'a due request catches the report up')
            self.assertEqual(aggregator.accept(self.event_batch('00000000-0000-4000-8000-000000000003')), 1)
            self.assertEqual(reported(), 3)
            aggregator.flush_report()
            self.assertEqual(reported(), 4, 'shutdown writes the pending report')

    def test_a_new_day_exports_immediately(self):
        from datetime import datetime, timedelta, timezone
        with tempfile.TemporaryDirectory() as directory:
            clock = [datetime(2026, 10, 13, 23, 59, 30, tzinfo=timezone.utc)]
            aggregator = Aggregator(directory, now=lambda: clock[0], export_interval=3600)
            aggregator.accept(self.event_batch('00000000-0000-4000-8000-000000000001'))
            clock[0] += timedelta(seconds=60)
            aggregator.accept(self.event_batch('00000000-0000-4000-8000-000000000002'))
            self.assertTrue((Path(directory) / 'analytics-2026-10-14.json').exists())


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
