import json
import os
import stat
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

from tool.analytics_receiver import (
    Aggregator,
    BugReportRateLimited,
    BugReportStore,
    InvalidGoogleToken,
    MAX_BUG_REPORT_BYTES,
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
        self.assertTrue(self.valid('sync_abandoned', {**good, 'attempt': 3, 'durationMs': 120000, 'durationTruncated': True}))
        self.assertFalse(self.valid('sync_abandoned', {**good, 'reason': 'crash'}))
        self.assertFalse(self.valid('sync_abandoned', {**good, 'errorCode': 'unknown'}))

    def test_stage_times_are_optional_bounded_and_only_on_terminal_results(self):
        ok = {'operation': 'backupThenDetectRemoteChanges', 'trigger': 'resume',
              'outcome': 'succeeded', 'durationMs': 900}
        stages = {'backupMs': 100, 'changesMs': 200, 'downloadMs': 0, 'applyMs': 120000}
        failed = {**ok, 'outcome': 'failed', 'errorCode': 'network'}
        self.assertTrue(self.valid('sync_succeeded', {**ok, **stages}))
        self.assertTrue(self.valid('sync_failed', {**failed, 'backupMs': 5}))
        self.assertTrue(self.valid('sync_succeeded', ok))
        for bad in (-1, 120001, '5', None, 1.5, True):
            self.assertFalse(self.valid('sync_succeeded', {**ok, 'backupMs': bad}))
        self.assertFalse(self.valid('sync_succeeded', {**ok, 'waitMs': 3000}))
        abandoned = {'operation': 'backup', 'trigger': 'manual', 'reason': 'sessionChanged', 'durationMs': 5}
        self.assertFalse(self.valid('sync_abandoned', {**abandoned, 'backupMs': 5}))
        self.assertFalse(self.valid('sync_started', {'operation': 'backup', 'trigger': 'manual', 'backupMs': 5}))


class LmsLoginTests(unittest.TestCase):
    BASE = {'eventId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'occurredAt': '2026-10-19T00:00:00Z',
            'name': 'lms_login'}
    COMMON = {'method': 'automatic', 'stage': 'authentication'}

    def valid(self, **attributes):
        from tool.analytics_receiver import valid_event
        return valid_event({**self.BASE, 'attributes': {**self.COMMON, **attributes}})

    def test_result_decides_which_detail_is_required(self):
        self.assertTrue(self.valid(result='succeeded'))
        self.assertTrue(self.valid(result='canceled'))
        self.assertTrue(self.valid(result='failed', cause='timedOut'))
        self.assertFalse(self.valid(result='failed'))
        self.assertFalse(self.valid(result='succeeded', cause='timedOut'))
        self.assertTrue(self.valid(result='skipped', skipReason='attemptLimit'))
        self.assertFalse(self.valid(result='skipped'))
        self.assertFalse(self.valid(result='failed', cause='timedOut', skipReason='paused'))

    def test_only_fixed_codes_are_accepted(self):
        self.assertFalse(self.valid(result='failed', cause='Exception: bad password for kim'))
        self.assertFalse(self.valid(result='failed', cause='wrongPassword'))
        self.assertFalse(self.valid(result='succeeded', stage='https://school.example/?ticket=1'))
        self.assertFalse(self.valid(result='succeeded', username='kim'))

    def test_accepted_events_are_aggregated_apart_from_drive_sync(self):
        batch = {
            'schemaVersion': 1,
            'sessionId': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
            'environment': {'appVersion': '4.1.2', 'platform': 'ios', 'osMajor': 27},
            'events': [
                {**self.BASE, 'attributes': {**self.COMMON, 'result': 'failed', 'cause': 'timedOut'}},
                {**self.BASE, 'eventId': 'cccccccc-cccc-4ccc-8ccc-cccccccccccc', 'name': 'sync_failed',
                 'attributes': {'operation': 'backup', 'trigger': 'manual', 'outcome': 'failed',
                                'durationMs': 5, 'errorCode': 'timeout'}},
            ],
        }
        self.assertTrue(valid_batch(batch))
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual(Aggregator(directory).accept(batch), 2)
            text = next(Path(directory).glob('analytics-*.json')).read_text()
            groups = json.loads(text)['groups'].values()
            self.assertEqual(sorted(g['name'] for g in groups), ['lms_login', 'sync_failed'])
            for forbidden in ('password', 'ticket', 'student@'):
                self.assertNotIn(forbidden, text)


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


class DayChangeExportTests(SqliteStateTests):
    """Counts held back by the export interval reach their own day's report."""

    IDS = [f'00000000-0000-4000-8000-00000000000{n}' for n in range(1, 6)]

    def report(self, directory, day):
        return json.loads((Path(directory) / f'analytics-{day}.json').read_text())['groups']

    def stored(self, directory, day):
        import sqlite3
        with sqlite3.connect(Path(directory) / 'analytics-state.sqlite') as db:
            rows = db.execute('SELECT key, data FROM groups WHERE day = ?', (day,)).fetchall()
        return {key: json.loads(data) for key, data in rows}

    def timed_batch(self, event_id, duration):
        batch = self.event_batch(event_id)
        batch['events'][0]['attributes']['durationMs'] = duration
        return batch

    def assert_report_matches_store(self, directory, day):
        report, stored = self.report(directory, day), self.stored(directory, day)
        self.assertEqual(set(report), set(stored))
        for key, group in stored.items():
            for field in ('count', 'durationTotalMs', 'durationMaxMs'):
                self.assertEqual(report[key][field], group[field], field)

    def before_midnight(self, directory, clock):
        from datetime import timedelta
        aggregator = Aggregator(directory, now=lambda: clock[0], export_interval=60)
        self.assertEqual(aggregator.accept(self.timed_batch(self.IDS[0], 25)), 1)
        clock[0] += timedelta(seconds=20)  # 23:59:50, inside the interval
        self.assertEqual(aggregator.accept(self.timed_batch(self.IDS[1], 25)), 1)
        self.assertEqual(sum(g['count'] for g in self.report(directory, '2026-10-13').values()), 1)
        return aggregator

    def clock(self):
        from datetime import datetime, timezone
        return [datetime(2026, 10, 13, 23, 59, 30, tzinfo=timezone.utc)]

    def test_the_next_day_request_finishes_the_previous_report(self):
        from datetime import timedelta
        with tempfile.TemporaryDirectory() as directory:
            clock = self.clock()
            aggregator = self.before_midnight(directory, clock)
            clock[0] += timedelta(seconds=11)  # 00:00:01 the next UTC day
            self.assertEqual(aggregator.accept(self.timed_batch(self.IDS[2], 40)), 1)
            aggregator.flush_report()
            self.assert_report_matches_store(directory, '2026-10-13')
            self.assert_report_matches_store(directory, '2026-10-14')
            self.assertEqual(sum(g['count'] for g in self.report(directory, '2026-10-13').values()), 2)
            # Resending a counted event changes neither day.
            self.assertEqual(aggregator.accept(self.timed_batch(self.IDS[1], 25)), 0)
            aggregator.flush_report()
            self.assertEqual(sum(g['count'] for g in self.report(directory, '2026-10-13').values()), 2)
            self.assertEqual(sum(g['count'] for g in self.report(directory, '2026-10-14').values()), 1)

    def test_shutdown_after_midnight_still_writes_the_previous_day(self):
        from datetime import timedelta
        with tempfile.TemporaryDirectory() as directory:
            clock = self.clock()
            aggregator = self.before_midnight(directory, clock)
            clock[0] += timedelta(seconds=11)
            aggregator.flush_report()
            self.assert_report_matches_store(directory, '2026-10-13')
            self.assertFalse((Path(directory) / 'analytics-2026-10-14.json').exists())

    def test_a_failed_export_of_the_previous_day_is_retried(self):
        from datetime import timedelta
        from unittest import mock
        with tempfile.TemporaryDirectory() as directory:
            clock = self.clock()
            aggregator = self.before_midnight(directory, clock)
            clock[0] += timedelta(seconds=11)
            with mock.patch.object(aggregator, '_write_json', side_effect=OSError('read-only')):
                self.assertEqual(aggregator.accept(self.timed_batch(self.IDS[2], 40)), 1)
                aggregator.flush_report()
            self.assertEqual(sum(g['count'] for g in self.report(directory, '2026-10-13').values()), 1)
            aggregator.flush_report()
            self.assert_report_matches_store(directory, '2026-10-13')
            self.assert_report_matches_store(directory, '2026-10-14')

    def test_a_restart_recovers_reports_left_pending(self):
        from datetime import timedelta
        with tempfile.TemporaryDirectory() as directory:
            clock = self.clock()
            self.before_midnight(directory, clock)  # stopped without a flush
            clock[0] += timedelta(seconds=11)
            restarted = Aggregator(directory, now=lambda: clock[0], export_interval=60)
            self.assertEqual(restarted.accept(self.timed_batch(self.IDS[2], 40)), 1)
            self.assert_report_matches_store(directory, '2026-10-13')
            self.assert_report_matches_store(directory, '2026-10-14')
            # Exported days are no longer pending: a later request only rewrites today.
            with open(Path(directory) / 'analytics-2026-10-13.json') as report:
                before = report.read()
            clock[0] += timedelta(seconds=61)
            self.assertEqual(restarted.accept(self.timed_batch(self.IDS[3], 10)), 1)
            self.assertEqual((Path(directory) / 'analytics-2026-10-13.json').read_text(), before)
            self.assert_report_matches_store(directory, '2026-10-14')


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

    def test_stores_the_report_privately_with_masked_text_and_contact(self):
        with tempfile.TemporaryDirectory() as directory:
            store = _store(directory)
            value = _payload()
            value["report"]["description"] = "토큰 token=abc123 연락 kim@example.com \"치과 예약\""
            submission = store.submit(value, "Bearer google-token", REQUEST_A)
            self.assertRegex(submission["reportId"], r"^[0-9a-f-]{36}$")
            path = Path(directory) / "bug-reports-2026-11-07.json"
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
            self.assertEqual(stat.S_IMODE((Path(directory) / "bug-reports-state.sqlite").stat().st_mode), 0o600)
            report = json.loads(path.read_text())["reports"][0]
            self.assertEqual(report["reportId"], submission["reportId"])
            self.assertEqual(report["contactEmail"], "daily-user@example.com")
            self.assertEqual(report["title"], "일정 저장 실패")
            self.assertEqual(report["environment"]["platform"], "macOS")
            for secret in ("abc123", "kim@example.com", "치과", "google-token"):
                self.assertNotIn(secret, path.read_text())
            self.assertFalse((Path(directory) / "bug-report-contacts").exists())

    def test_retry_returns_the_same_report_and_accounts_stay_separate(self):
        with tempfile.TemporaryDirectory() as directory:
            store = _store(directory)
            first = store.submit(_payload(), "Bearer t", REQUEST_A)
            for _ in range(10):
                self.assertEqual(store.submit(_payload(), "Bearer t", REQUEST_A), first)
            self.assertNotEqual(store.submit(_payload(), "Bearer t", REQUEST_B), first)
            other = _store(directory, subject="google-subject-2")
            self.assertNotEqual(other.submit(_payload(), "Bearer t", REQUEST_A), first)
            reports = json.loads((Path(directory) / "bug-reports-2026-11-07.json").read_text())["reports"]
            self.assertEqual(len(reports), 3)

    def test_rate_limit_and_identity_checks(self):
        with tempfile.TemporaryDirectory() as directory:
            store = _store(directory)
            with self.assertRaises(BugReportRateLimited):
                for _ in range(6):
                    store.submit(_payload(), "Bearer t")
            unverified = _store(directory, verified=False)
            with self.assertRaises(InvalidGoogleToken):
                unverified.submit(_payload(), "Bearer t")

    def test_reports_expire_after_90_days_and_legacy_files_after_365(self):
        with tempfile.TemporaryDirectory() as directory:
            clock = [datetime(2026, 11, 7, tzinfo=timezone.utc)]
            store = _store(directory, now=lambda: clock[0])
            legacy = Path(directory) / "bug-report-contacts"
            legacy.mkdir()
            old, recent = legacy / "old.json", legacy / "recent.json"
            old.write_text("{}")
            recent.write_text("{}")
            stamp = (clock[0] - timedelta(days=400)).timestamp()
            os.utime(old, (stamp, stamp))
            store.submit(_payload(), "Bearer t")
            self.assertFalse(old.exists())
            self.assertTrue(recent.exists())
            clock[0] += timedelta(days=91)
            store.submit(_payload(), "Bearer t")
            self.assertFalse((Path(directory) / "bug-reports-2026-11-07.json").exists())


class BugReportExportRecoveryTest(unittest.TestCase):
    def test_retry_writes_a_copy_that_failed_before(self):
        with tempfile.TemporaryDirectory() as directory:
            store = _store(directory)
            original = store._export_pending

            def failing(_connection):
                raise OSError("disk full")

            store._export_pending = failing
            with self.assertRaises(OSError):
                store.submit(_payload(), "Bearer t", REQUEST_A)
            store._export_pending = original
            store.submit(_payload(), "Bearer t", REQUEST_A)
            reports = json.loads((Path(directory) / "bug-reports-2026-11-07.json").read_text())["reports"]
            self.assertEqual(len(reports), 1)

    def test_expire_runs_without_a_new_report(self):
        with tempfile.TemporaryDirectory() as directory:
            clock = [datetime(2026, 11, 7, tzinfo=timezone.utc)]
            _store(directory, now=lambda: clock[0]).submit(_payload(), "Bearer t")
            clock[0] += timedelta(days=91)
            _store(directory, now=lambda: clock[0]).expire()
            self.assertFalse((Path(directory) / "bug-reports-2026-11-07.json").exists())


def _store(directory, subject="google-subject-1", verified=True, now=None):
    return BugReportStore(
        directory,
        google_identity_fetcher=lambda _auth: {
            "sub": subject,
            "email": "daily-user@example.com",
            "email_verified": verified,
        },
        now=now or (lambda: datetime(2026, 11, 7, tzinfo=timezone.utc)),
    )


REQUEST_A = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
REQUEST_B = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"


if __name__ == "__main__":
    unittest.main()
