#!/usr/bin/env python3
import copy
import hashlib
import json
import os
import re
import signal
import sqlite3
import tempfile
import threading
import uuid
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


MAX_REQUEST_BYTES = 64 * 1024
MAX_EVENTS = 25
MAX_REQUESTS_PER_MINUTE = 120
# Field limits allow 12,120 characters; four-byte UTF-8 (emoji) is the worst case
# at about 48.5 KB, so 64 KiB covers every form-valid report plus the environment.
MAX_BUG_REPORT_BYTES = 64 * 1024
MAX_BUG_REPORTS_PER_HOUR = 5
BUG_REPORT_RETENTION_DAYS = 90
# Contact/request files written by the earlier GitHub-issue version are only
# expired now, on their original 365-day schedule.
LEGACY_BUG_REPORT_RETENTION_DAYS = 365
DEDUPE_RETENTION_DAYS = 7
REPORT_EXPORT_INTERVAL_SECONDS = 60
MAX_ERROR_REPORT_BYTES = 32 * 1024
MAX_ERROR_REPORTS_PER_HOUR = 30
# Bounds storage when a crash loop hits many devices at once.
MAX_ERROR_FINGERPRINTS_PER_DAY = 200
MAX_ERROR_REPORT_ENVIRONMENTS = 20
ERROR_REPORT_RETENTION_DAYS = 90
FINGERPRINT_PATTERN = re.compile(r"^[0-9a-f]{16}$")
GOOGLE_USERINFO_URL = "https://openidconnect.googleapis.com/v1/userinfo"
VERSION_PATTERN = re.compile(r"^\d+\.\d+\.\d+(?:\.\d+)?$")
# A package build number is a plain integer or dotted number; 'unknown' when the platform has none.
BUILD_NUMBER_PATTERN = re.compile(r"^(?:\d+(?:\.\d+){0,3}|unknown)$")
ANALYTICS_VERSION_PATTERN = re.compile(r"^\d+\.\d+\.\d+(?:\.\d+)?(?:-test)?$")
EMAIL_PATTERN = re.compile(r"^[^\s@]+@[^\s@]+\.[^\s@]+$")
UUID_PATTERN = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
    re.IGNORECASE,
)

BUG_REPORT_FIELDS = {
    "title": 120,
    "description": 4000,
    "reproductionSteps": 4000,
    "expectedBehavior": 2000,
    "actualBehavior": 2000,
}
BUG_REPORT_ENVIRONMENT_FIELDS = {
    "version": 32,
    "buildNumber": 32,
    "platform": 16,
    "osVersion": 256,
}

ENUMS = {
    "screen": {
        "onboarding", "calendar", "quickView", "search", "settings",
        "notificationSettings", "accountSettings", "eventDetails",
    },
    "view": {"quickView", "week", "month", "day"},
    "mode": {"create", "edit"},
    "operation": {"create", "update", "delete", "complete", "uncomplete"},
    "syncOperation": {
        "backup", "restore", "backupThenRestore", "detectRemoteChanges",
        "backupThenDetectRemoteChanges",
    },
    "phase": {"database", "followUp"},
    "buildMode": {"debug", "profile", "release"},
    "milestone": {"firstCalendarFrame", "localCalendarReady"},
    "abandonReason": {"sessionChanged"},
    "lmsMethod": {"manual", "automatic"},
    "lmsStage": {"credentials", "prepare", "authentication", "session"},
    "lmsResult": {"succeeded", "failed", "skipped", "canceled"},
    "lmsSkipReason": {"noCredentials", "paused", "attemptLimit"},
    "lmsCause": {
        "network", "timedOut", "additionalAuthentication", "credentialsRejected",
        "accountLocked", "passwordExpired", "accountMismatch", "unsupportedForm",
        "authenticationUnconfirmed", "invalidResponse", "hostUnavailable",
        "viewUnavailable", "scriptUnavailable", "busy", "secureStorage",
        "certificate", "serverRejected", "unknown",
    },
    "feature": {"search", "filter", "widget", "calendarImport", "siri", "map"},
    "trigger": {"automatic", "manual", "startup", "resume", "localChange"},
    "outcome": {"succeeded", "failed", "canceled"},
    "errorCode": {
        "authenticationRequired", "canceled", "timeout", "network",
        "permission", "validation", "storage", "conflict", "unavailable", "unknown",
    },
    "interaction": {
        "app_start", "calendar_transition", "event_save", "search_open", "sync",
        "frame_batch",
    },
}

# Attributes a sender may add on top of the required ones; older apps omit them.
OPTIONAL_SCHEMAS = {
    **{
        name: {"durationTruncated": "truncatedFlag"}
        for name in (
            "app_load_completed", "event_editor_completed", "event_save_succeeded",
            "event_save_failed", "slow_interaction_detected", "frame_summary",
            "startup_milestone",
        )
    },
    "sync_started": {"attempt": "syncAttempt"},
    "lms_login": {"cause": "lmsCause", "skipReason": "lmsSkipReason"},
    **{
        name: {"durationTruncated": "truncatedFlag", "attempt": "syncAttempt"}
        for name in ("sync_succeeded", "sync_failed", "sync_abandoned")
    },
}
# Per-stage sync times (newer apps only); capped like durationMs, without a flag.
for _name in ("sync_succeeded", "sync_failed"):
    for _stage in ("backup", "changes", "download", "apply"):
        OPTIONAL_SCHEMAS[_name][f"{_stage}Ms"] = "duration"
for _name in ("event_save_succeeded", "event_save_failed"):
    OPTIONAL_SCHEMAS[_name]["phase"] = "phase"

SCHEMAS = {
    "app_load_completed": {"durationMs": "duration"},
    "screen_view": {"screen": "screen"},
    "calendar_view_changed": {"view": "view", "trigger": "trigger"},
    "event_editor_opened": {"mode": "mode", "trigger": "trigger"},
    "event_editor_completed": {
        "mode": "mode", "outcome": "outcome", "durationMs": "duration",
    },
    # `phase` is sent by newer apps only; apps before it send neither value.
    "event_save_succeeded": {"operation": "operation", "durationMs": "duration"},
    "event_save_failed": {
        "operation": "operation", "durationMs": "duration", "errorCode": "errorCode",
    },
    "feature_used": {"feature": "feature", "outcome": "outcome"},
    "sync_started": {"operation": "syncOperation", "trigger": "trigger"},
    "sync_succeeded": {
        "operation": "syncOperation", "trigger": "trigger", "outcome": "succeeded",
        "durationMs": "duration",
    },
    "lms_login": {"method": "lmsMethod", "stage": "lmsStage", "result": "lmsResult"},
    "sync_abandoned": {
        "operation": "syncOperation", "trigger": "trigger", "reason": "abandonReason",
        "durationMs": "duration",
    },
    "sync_failed": {
        "operation": "syncOperation", "trigger": "trigger", "outcome": "failedOutcome",
        "durationMs": "duration", "errorCode": "errorCode",
    },
    "startup_milestone": {"milestone": "milestone", "durationMs": "duration"},
    "frame_summary": {
        "frameCount": "framesInWindow", "slowFrameCount": "slowFramesInWindow",
        "durationMs": "duration", "refreshRateHz": "refreshRate",
        "buildMode": "buildMode",
    },
    "slow_interaction_detected": {
        "interaction": "interaction", "durationMs": "duration",
        "slowFrameCount": "frameCount",
    },
}


def _valid_value(kind, value):
    if kind == "duration":
        return type(value) is int and 0 <= value <= 120000
    if kind == "framesInWindow":
        return type(value) is int and 1 <= value <= 100000
    if kind == "slowFramesInWindow":
        return type(value) is int and 0 <= value <= 100000
    if kind == "refreshRate":
        return type(value) is int and 24 <= value <= 240
    if kind == "syncAttempt":
        return type(value) is int and 2 <= value <= 6
    if kind == "truncatedFlag":
        return value is True
    if kind == "frameCount":
        return type(value) is int and 0 <= value <= 120
    if kind == "succeeded":
        return value == "succeeded"
    if kind == "failedOutcome":
        return isinstance(value, str) and value in {"failed", "canceled"}
    return isinstance(value, str) and value in ENUMS[kind]


def _valid_timestamp(value):
    if not isinstance(value, str):
        return False
    try:
        datetime.fromisoformat(value.replace("Z", "+00:00"))
        return True
    except ValueError:
        return False


def valid_event(event):
    if not isinstance(event, dict):
        return False
    if set(event) != {"eventId", "name", "occurredAt", "attributes"}:
        return False
    if not isinstance(event["eventId"], str) or not UUID_PATTERN.fullmatch(event["eventId"]):
        return False
    if not _valid_timestamp(event["occurredAt"]):
        return False
    # A list or object is valid JSON but unhashable: reject it, never raise.
    if not isinstance(event["name"], str):
        return False
    schema = SCHEMAS.get(event["name"])
    attributes = event["attributes"]
    if schema is None or not isinstance(attributes, dict):
        return False
    optional = OPTIONAL_SCHEMAS.get(event["name"], {})
    keys = set(attributes)
    if not set(schema) <= keys <= set(schema) | set(optional):
        return False
    kinds = {**optional, **schema}
    if not all(_valid_value(kinds[key], value) for key, value in attributes.items()):
        return False
    if event["name"] == "lms_login" and (
        ("cause" in attributes) != (attributes["result"] == "failed")
        or ("skipReason" in attributes) != (attributes["result"] == "skipped")
    ):
        return False
    # The flag means the real duration was longer than the cap and was cut to it.
    if "durationTruncated" in attributes and attributes["durationMs"] != 120000:
        return False
    if event["name"] == "frame_summary" and attributes["slowFrameCount"] > attributes["frameCount"]:
        return False
    return True


def valid_batch(batch):
    if not isinstance(batch, dict):
        return False
    if set(batch) != {"schemaVersion", "sessionId", "environment", "events"}:
        return False
    if batch["schemaVersion"] != 1:
        return False
    if not isinstance(batch["sessionId"], str) or not UUID_PATTERN.fullmatch(batch["sessionId"]):
        return False
    environment = batch["environment"]
    if not isinstance(environment, dict) or set(environment) != {"appVersion", "platform", "osMajor"}:
        return False
    if not isinstance(environment["appVersion"], str) or not ANALYTICS_VERSION_PATTERN.fullmatch(environment["appVersion"]):
        return False
    if not isinstance(environment["platform"], str) or environment["platform"] not in {
        "ios",
        "macos",
        "android",
        "windows",
        "linux",
    }:
        return False
    if type(environment["osMajor"]) is not int:
        return False
    events = batch["events"]
    return isinstance(events, list) and 0 < len(events) <= MAX_EVENTS and all(valid_event(e) for e in events)


def _clean_report_text(value, maximum):
    if not isinstance(value, str):
        return None
    cleaned = "".join(character for character in value.strip() if character >= " " or character in "\n\t")
    if not cleaned or len(cleaned) > maximum:
        return None
    return cleaned


def normalize_bug_report(payload):
    if not isinstance(payload, dict) or set(payload) != {"report", "environment"}:
        return None
    report = payload["report"]
    environment = payload["environment"]
    if not isinstance(report, dict) or set(report) != set(BUG_REPORT_FIELDS):
        return None
    if not isinstance(environment, dict) or set(environment) != set(BUG_REPORT_ENVIRONMENT_FIELDS):
        return None

    clean_report = {}
    for key, maximum in BUG_REPORT_FIELDS.items():
        cleaned = _clean_report_text(report[key], maximum)
        if cleaned is None:
            return None
        clean_report[key] = cleaned

    clean_environment = {}
    for key, maximum in BUG_REPORT_ENVIRONMENT_FIELDS.items():
        cleaned = _clean_report_text(environment[key], maximum)
        if cleaned is None or "\n" in cleaned or "\t" in cleaned:
            return None
        clean_environment[key] = cleaned
    if not VERSION_PATTERN.fullmatch(clean_environment["version"]):
        return None
    if not BUILD_NUMBER_PATTERN.fullmatch(clean_environment["buildNumber"]):
        return None
    if clean_environment["platform"] not in {"iOS", "macOS", "Android", "Windows", "Linux"}:
        return None
    return {"report": clean_report, "environment": clean_environment}


ERROR_REPORT_FIELDS = {
    "fingerprint": 16,
    "severity": 16,
    "feature": 64,
    "errorType": 200,
    "message": 1000,
    "stackTrace": 6000,
    "firstOccurredAt": 40,
    "lastOccurredAt": 40,
    "occurrenceCount": None,
    "lifecycle": 32,
}
ERROR_REPORT_ENVIRONMENT_FIELDS = {
    "version": 32,
    "buildNumber": 32,
    "platform": 16,
    "osVersion": 256,
    "deviceType": 16,
    "locale": 35,
    "timeZone": 16,
    "environment": 16,
}
_ERROR_SANITIZERS = [
    (re.compile(r"\b(Bearer|Basic)\s+[A-Za-z0-9._~+/=-]+", re.I), lambda m: f"{m[1]} ***"),
    (re.compile(r"\b(Cookie|Set-Cookie|Authorization)\s*:[^\n]*", re.I), lambda m: f"{m[1]}: ***"),
    (
        re.compile(
            r"\b(access_token|refresh_token|id_token|token|password|passwd|pwd|pw|"
            r"cookie|session(?:_?id)?|jsessionid|api[_-]?key|secret|code|user_?id|"
            r"student_?id|email)([\"']?\s*[=:]\s*)[\"']?[^\s&;,\"'}]+",
            re.I,
        ),
        lambda m: f"{m[1]}{m[2]}***",
    ),
    (re.compile(r"eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*"), lambda m: "***"),
    (re.compile(r"\bya29\.[A-Za-z0-9._-]+"), lambda m: "***"),
    (re.compile(r"[^\s@<>()\"]+@[^\s@<>()\"]+\.[A-Za-z]{2,}"), lambda m: "***@***"),
    (re.compile(r"(https?://[^\s?#]+)\?[^\s#)]*", re.I), lambda m: f"{m[1]}?***"),
    (re.compile(r"(/Users/|/home/|[A-Za-z]:\\Users\\)[^/\\\s]+", re.I), lambda m: f"{m[1]}***"),
    (
        re.compile(r"\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b", re.I),
        lambda m: "<uuid>",
    ),
    (re.compile(r"\b[0-9a-f]{16,}\b", re.I), lambda m: "<hex>"),
    (re.compile(r"\+?\d[\d -]{8,}\d"), lambda m: "<number>"),
    (re.compile(r"\d{6,}"), lambda m: "<number>"),
    # An unterminated quote (such as a cut-off JSON value) is masked to the end of its line.
    (re.compile(r"\"[^\"\n]*(?:\"|$)", re.M), lambda m: '"***"'),
    (re.compile(r"'[^'\n]*(?:'|$)", re.M), lambda m: "'***'"),
]


def sanitize_error_text(value):
    """Same masking as the app's `sanitizeErrorText`, applied again here so a
    modified or older client cannot publish tokens or personal data."""
    for pattern, replace in _ERROR_SANITIZERS:
        value = pattern.sub(replace, value)
    return value.replace("`", "'")


def normalize_error_report(payload):
    if not isinstance(payload, dict) or set(payload) != {"report", "environment", "integrations"}:
        return None
    report, environment, integrations = payload["report"], payload["environment"], payload["integrations"]
    if not isinstance(report, dict) or set(report) != set(ERROR_REPORT_FIELDS):
        return None
    if not isinstance(environment, dict) or set(environment) != set(ERROR_REPORT_ENVIRONMENT_FIELDS):
        return None
    if not isinstance(integrations, dict) or set(integrations) != {"driveLinked", "lmsConnected", "lastDriveSyncAt"}:
        return None

    clean_report = {}
    for key, maximum in ERROR_REPORT_FIELDS.items():
        if maximum is None:
            continue
        value = report[key]
        if key == "stackTrace" and value == "":
            clean_report[key] = ""
            continue
        cleaned = _clean_report_text(value, maximum)
        if cleaned is None:
            return None
        clean_report[key] = cleaned
    count = report["occurrenceCount"]
    if type(count) is not int or not 1 <= count <= 1_000_000:
        return None
    clean_report["occurrenceCount"] = count
    if not FINGERPRINT_PATTERN.fullmatch(clean_report["fingerprint"]):
        return None
    if clean_report["severity"] not in {"fatal", "nonFatal"}:
        return None
    for key in ("firstOccurredAt", "lastOccurredAt"):
        if not _valid_timestamp(clean_report[key]):
            return None
    for key in ("feature", "errorType", "message", "stackTrace", "lifecycle"):
        clean_report[key] = sanitize_error_text(clean_report[key])

    clean_environment = {}
    for key, maximum in ERROR_REPORT_ENVIRONMENT_FIELDS.items():
        cleaned = _clean_report_text(environment[key], maximum)
        if cleaned is None or "\n" in cleaned or "\t" in cleaned:
            return None
        # Structured fields are checked against fixed patterns below; only
        # free text is masked, so long build numbers stay valid.
        clean_environment[key] = sanitize_error_text(cleaned) if key in {"osVersion", "locale"} else cleaned
    if not VERSION_PATTERN.fullmatch(clean_environment["version"]):
        return None
    if not BUILD_NUMBER_PATTERN.fullmatch(clean_environment["buildNumber"]):
        return None
    if clean_environment["platform"] not in {"iOS", "macOS", "Android", "Windows", "Linux"}:
        return None
    if clean_environment["deviceType"] not in {"mobile", "desktop"}:
        return None
    # Debug builds never report; this guards against a modified client.
    if clean_environment["environment"] not in {"profile", "test", "production"}:
        return None

    last_sync = integrations["lastDriveSyncAt"]
    if (
        type(integrations["driveLinked"]) is not bool
        or type(integrations["lmsConnected"]) is not bool
        or (last_sync is not None and not _valid_timestamp(last_sync))
    ):
        return None
    return {"report": clean_report, "environment": clean_environment, "integrations": dict(integrations)}


class InvalidGoogleToken(Exception):
    pass


class UpstreamUnavailable(Exception):
    pass


class BugReportRateLimited(Exception):
    pass


class Aggregator:
    """Anonymous aggregate counters with hash-only duplicate protection.

    State lives in one SQLite file so a request only touches its own events: a
    duplicate hash is a primary-key conflict and the counters change in the same
    transaction (a failure rolls both back). `analytics-YYYY-MM-DD.json` stays as
    the readable report and is rebuilt from the counter rows of that day, whose
    count is bounded by the number of distinct groups, not by the event count.
    The report is a convenience copy: with `export_interval` seconds above zero
    it is rewritten at most that often (and by `flush_report`), so a busy
    receiver does not re-export every group on every request. Days whose
    counters changed after their last export stay in `export_pending` (written
    in the counting transaction), so a UTC day change, a failed write or a
    restart cannot drop a day's last counts from its report.
    """

    def __init__(self, directory, now=None, export_interval=0):
        self.directory = Path(directory)
        self.lock = threading.Lock()
        self._now = now or (lambda: datetime.now(timezone.utc))
        self._database = self.directory / "analytics-state.sqlite"
        self._export_interval = export_interval
        self._last_export = None
        self._last_export_day = None

    def accept(self, batch):
        # Storage failures surface as OSError, which the HTTP handler turns into
        # a 500 store_failed response instead of an unhandled traceback.
        try:
            return self._accept(batch)
        except sqlite3.Error as error:
            raise OSError(f"analytics state store failed: {type(error).__name__}") from error

    def flush_report(self):
        """Writes the pending report now (used when the receiver shuts down)."""
        with self.lock:
            now = self._now()
            try:
                connection = self._connect()
                try:
                    self._export_pending(connection, now)
                finally:
                    connection.close()
            except (sqlite3.Error, OSError):
                pass

    def _accept(self, batch):
        with self.lock:
            self._make_private(self.directory, directory=True)
            now = self._now()
            day = now.strftime("%Y-%m-%d")
            connection = self._connect()
            try:
                self._migrate(connection)
                self._delete_expired(connection, now)
                environment = batch["environment"]
                accepted = 0
                connection.execute("BEGIN IMMEDIATE")
                try:
                    for event in batch["events"]:
                        event_hash = hashlib.sha256(event["eventId"].encode()).hexdigest()
                        inserted = connection.execute(
                            "INSERT OR IGNORE INTO dedupe(hash, day) VALUES (?, ?)",
                            (event_hash, day),
                        ).rowcount
                        if not inserted:
                            continue
                        accepted += 1
                        self._count(connection, day, environment, event)
                    if accepted:
                        connection.execute(
                            "INSERT OR IGNORE INTO export_pending(day) VALUES (?)", (day,)
                        )
                    connection.execute("COMMIT")
                except BaseException:
                    connection.execute("ROLLBACK")
                    raise
                if self._export_due(day, now):
                    self._export_pending(connection, now)
                return accepted
            finally:
                connection.close()

    def _export_due(self, day, now):
        return (
            self._export_interval <= 0
            or self._last_export is None
            or self._last_export_day != day
            or (now - self._last_export).total_seconds() >= self._export_interval
        )

    @staticmethod
    def _make_private(path, directory=False):
        """Directory 0700 / files 0600, whatever the process umask is."""
        if directory:
            path.mkdir(mode=0o700, parents=True, exist_ok=True)
        try:
            os.chmod(path, 0o700 if directory else 0o600)
        except OSError:
            pass

    def _connect(self):
        # Create the file private before SQLite does; its journal and WAL files
        # inherit the main file's mode.
        if not self._database.exists():
            os.close(os.open(self._database, os.O_CREAT | os.O_WRONLY, 0o600))
        self._make_private(self._database)
        connection = sqlite3.connect(self._database, timeout=10, isolation_level=None)
        connection.execute(
            "CREATE TABLE IF NOT EXISTS dedupe(hash TEXT PRIMARY KEY, day TEXT NOT NULL)"
        )
        connection.execute(
            "CREATE TABLE IF NOT EXISTS groups("
            "day TEXT NOT NULL, key TEXT NOT NULL, data TEXT NOT NULL, "
            "PRIMARY KEY(day, key))"
        )
        # Retention cleanup filters on the day, which the hash key cannot serve.
        connection.execute("CREATE INDEX IF NOT EXISTS dedupe_day ON dedupe(day)")
        connection.execute("CREATE TABLE IF NOT EXISTS export_pending(day TEXT PRIMARY KEY)")
        connection.execute("CREATE TABLE IF NOT EXISTS meta(name TEXT PRIMARY KEY, value TEXT)")
        return connection

    def _count(self, connection, day, environment, event):
        attributes = dict(sorted(event["attributes"].items()))
        key_data = {
            "appVersion": environment["appVersion"],
            "platform": environment["platform"],
            "osMajor": environment["osMajor"],
            "name": event["name"],
            "attributes": attributes,
        }
        key = json.dumps(key_data, ensure_ascii=True, sort_keys=True, separators=(",", ":"))
        row = connection.execute(
            "SELECT data FROM groups WHERE day = ? AND key = ?", (day, key)
        ).fetchone()
        group = (
            json.loads(row[0])
            if row
            else {**key_data, "count": 0, "durationTotalMs": 0, "durationMaxMs": 0}
        )
        group["count"] += 1
        duration = attributes.get("durationMs", 0)
        group["durationTotalMs"] += duration
        group["durationMaxMs"] = max(group["durationMaxMs"], duration)
        connection.execute(
            "INSERT OR REPLACE INTO groups(day, key, data) VALUES (?, ?, ?)",
            (day, key, json.dumps(group, ensure_ascii=True, sort_keys=True, separators=(",", ":"))),
        )

    def _export_pending(self, connection, now):
        """Exports every day whose counters changed since its last report, oldest first."""
        days = [row[0] for row in connection.execute("SELECT day FROM export_pending ORDER BY day")]
        for day in days:
            self._export(connection, day, now)

    def _export(self, connection, day, now):
        """Rewrites the day's report from its counter rows (best effort)."""
        rows = connection.execute("SELECT key, data FROM groups WHERE day = ?", (day,)).fetchall()
        aggregate = {
            "schemaVersion": 1,
            "date": day,
            "groups": {key: json.loads(data) for key, data in rows},
            "updatedAt": now.isoformat().replace("+00:00", "Z"),
        }
        try:
            self._write_json(self.directory / f"analytics-{day}.json", aggregate)
        except OSError:
            # The counters are already committed and the day stays pending, so
            # the next due request or shutdown retries it.
            return
        connection.execute("DELETE FROM export_pending WHERE day = ?", (day,))
        self._last_export = now
        self._last_export_day = day

    def _migrate(self, connection):
        """One-time import of the earlier JSON aggregate and dedupe files."""
        done = connection.execute("SELECT 1 FROM meta WHERE name = 'imported'").fetchone()
        if done:
            return
        connection.execute("BEGIN IMMEDIATE")
        try:
            for path in self.directory.glob("dedupe-*.json"):
                match = re.fullmatch(r"dedupe-(\d{4}-\d{2}-\d{2})\.json", path.name)
                if not match:
                    continue
                for event_hash in self._read_json(path, []):
                    if isinstance(event_hash, str):
                        # An event retried across UTC days sits in several files:
                        # keep the newest day so cleanup cannot drop it early.
                        connection.execute(
                            "INSERT INTO dedupe(hash, day) VALUES (?, ?) "
                            "ON CONFLICT(hash) DO UPDATE SET day = MAX(day, excluded.day)",
                            (event_hash, match.group(1)),
                        )
            for path in self.directory.glob("analytics-*.json"):
                match = re.fullmatch(r"analytics-(\d{4}-\d{2}-\d{2})\.json", path.name)
                groups = self._read_json(path, {}).get("groups", {}) if match else {}
                for key, group in groups.items():
                    connection.execute(
                        "INSERT OR IGNORE INTO groups(day, key, data) VALUES (?, ?, ?)",
                        (
                            match.group(1),
                            key,
                            json.dumps(group, ensure_ascii=True, sort_keys=True, separators=(",", ":")),
                        ),
                    )
            connection.execute("INSERT INTO meta(name, value) VALUES ('imported', '1')")
            connection.execute("COMMIT")
        except BaseException:
            connection.execute("ROLLBACK")
            raise

    def _read_json(self, path, fallback):
        try:
            return json.loads(path.read_text()) if path.exists() else fallback
        except (OSError, ValueError, TypeError):
            return fallback

    def _write_json(self, path, value):
        fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=self.directory)
        try:
            with os.fdopen(fd, "w") as output:
                json.dump(value, output, ensure_ascii=True, sort_keys=True, separators=(",", ":"))
                output.flush()
                os.fsync(output.fileno())
            os.replace(temporary, path)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)

    def _delete_expired(self, connection, now):
        today = now.date()
        dedupe_cutoff = (today - timedelta(days=DEDUPE_RETENTION_DAYS)).strftime("%Y-%m-%d")
        group_cutoff = (today - timedelta(days=90)).strftime("%Y-%m-%d")
        connection.execute("DELETE FROM dedupe WHERE day < ?", (dedupe_cutoff,))
        connection.execute("DELETE FROM groups WHERE day < ?", (group_cutoff,))
        connection.execute("DELETE FROM export_pending WHERE day < ?", (group_cutoff,))
        for path in self.directory.glob("*.json"):
            match = re.fullmatch(r"(analytics|dedupe)-(\d{4}-\d{2}-\d{2})\.json", path.name)
            if not match:
                continue
            try:
                date = datetime.strptime(match.group(2), "%Y-%m-%d").date()
            except ValueError:
                continue
            retention = 90 if match.group(1) == "analytics" else DEDUPE_RETENTION_DAYS
            if today - date > timedelta(days=retention):
                path.unlink(missing_ok=True)


REQUEST_ID_PATTERN = re.compile(
    r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"
)


def fetch_google_identity(authorization):
    if (
        not isinstance(authorization, str)
        or not authorization.startswith("Bearer ")
        or len(authorization) > 8192
    ):
        raise InvalidGoogleToken()
    request = Request(
        GOOGLE_USERINFO_URL,
        headers={"Authorization": authorization, "Accept": "application/json"},
        method="GET",
    )
    try:
        with urlopen(request, timeout=10) as response:
            body = response.read(64 * 1024 + 1)
    except HTTPError as error:
        if error.code in {400, 401, 403}:
            raise InvalidGoogleToken() from None
        raise UpstreamUnavailable() from None
    except (OSError, URLError, TimeoutError):
        raise UpstreamUnavailable() from None
    if len(body) > 64 * 1024:
        raise UpstreamUnavailable()
    try:
        decoded = json.loads(body)
    except (TypeError, ValueError, UnicodeDecodeError):
        raise UpstreamUnavailable() from None
    if not isinstance(decoded, dict):
        raise UpstreamUnavailable()
    return decoded


class BugReportStore:
    """User-submitted bug reports, stored privately like the error reports.

    `bug-reports-state.sqlite` holds one row per report (masked text, app
    environment and the verified contact email); `bug-reports-YYYY-MM-DD.json`
    is the readable copy of the UTC day the report arrived. Both are 0600 and
    deleted after `BUG_REPORT_RETENTION_DAYS`. Nothing is published. A request
    ID (the app's `Idempotency-Key`) bound to the account returns the same
    report on a retry instead of storing it twice.
    """

    def __init__(self, directory, *, google_identity_fetcher=None, now=None):
        self.directory = Path(directory)
        self._database = self.directory / "bug-reports-state.sqlite"
        self._google_identity_fetcher = google_identity_fetcher or fetch_google_identity
        self._now = now or (lambda: datetime.now(timezone.utc))
        self._lock = threading.Lock()
        self._rate_lock = threading.Lock()
        self._rate_windows = defaultdict(list)

    def submit(self, payload, authorization, request_id=None):
        identity = self._google_identity_fetcher(authorization)
        subject = identity.get("sub") if isinstance(identity, dict) else None
        email = identity.get("email") if isinstance(identity, dict) else None
        if (
            not isinstance(subject, str)
            or not subject
            or len(subject) > 255
            or not isinstance(email, str)
            or len(email) > 320
            or not EMAIL_PATTERN.fullmatch(email)
            or identity.get("email_verified") is not True
        ):
            raise InvalidGoogleToken()
        subject_hash = hashlib.sha256(subject.encode()).hexdigest()
        key = None
        if isinstance(request_id, str) and REQUEST_ID_PATTERN.fullmatch(request_id):
            # Bound to the verified account, so another user cannot reuse it.
            key = hashlib.sha256(f"{subject_hash}:{request_id.lower()}".encode()).hexdigest()
        report = payload["report"]
        environment = payload["environment"]
        now = self._now()
        day = now.date().isoformat()
        with self._lock:
            self._delete_legacy_files(now)
            connection = self._connect()
            try:
                connection.execute("BEGIN IMMEDIATE")
                self._delete_expired(connection, now)
                if key is not None:
                    row = connection.execute("SELECT report_id FROM requests WHERE key = ?", (key,)).fetchone()
                    if row is not None:
                        connection.execute("COMMIT")
                        try:
                            # An earlier attempt may have stored it but failed the copy.
                            self._export_pending(connection)
                        finally:
                            connection.close()
                        return {"reportId": row[0]}
                self._check_rate(subject_hash)
                report_id = str(uuid.uuid4())
                connection.execute(
                    "INSERT INTO reports(id, day, received_at, title, description, reproduction_steps,"
                    " expected_behavior, actual_behavior, version, build_number, platform, os_version, email)"
                    " VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
                    (
                        report_id, day, now.isoformat().replace("+00:00", "Z"),
                        *(sanitize_error_text(report[field]) for field in BUG_REPORT_FIELDS),
                        environment["version"], environment["buildNumber"], environment["platform"],
                        sanitize_error_text(environment["osVersion"]), email,
                    ),
                )
                if key is not None:
                    connection.execute("INSERT INTO requests(key, report_id, day) VALUES (?,?,?)", (key, report_id, day))
                connection.execute("INSERT OR IGNORE INTO export_pending(day) VALUES (?)", (day,))
                connection.execute("COMMIT")
            except BaseException:
                if connection.in_transaction:
                    connection.execute("ROLLBACK")
                connection.close()
                raise
            try:
                self._export_pending(connection)
            finally:
                connection.close()
        return {"reportId": report_id}

    def expire(self):
        """Deletes expired data without waiting for the next report."""
        with self._lock:
            self._delete_legacy_files(self._now())
            connection = self._connect()
            try:
                connection.execute("BEGIN IMMEDIATE")
                self._delete_expired(connection, self._now())
                connection.execute("COMMIT")
            except BaseException:
                if connection.in_transaction:
                    connection.execute("ROLLBACK")
                raise
            finally:
                connection.close()

    def _check_rate(self, subject_hash):
        timestamp = self._now().timestamp()
        with self._rate_lock:
            window = [value for value in self._rate_windows[subject_hash] if timestamp - value < 60 * 60]
            if len(window) >= MAX_BUG_REPORTS_PER_HOUR:
                self._rate_windows[subject_hash] = window
                raise BugReportRateLimited()
            window.append(timestamp)
            self._rate_windows[subject_hash] = window

    def _connect(self):
        Aggregator._make_private(self.directory, directory=True)
        if not self._database.exists():
            os.close(os.open(self._database, os.O_CREAT | os.O_WRONLY, 0o600))
        Aggregator._make_private(self._database)
        connection = sqlite3.connect(self._database, timeout=10, isolation_level=None)
        connection.execute(
            "CREATE TABLE IF NOT EXISTS reports(id TEXT PRIMARY KEY, day TEXT NOT NULL, received_at TEXT NOT NULL,"
            " title TEXT NOT NULL, description TEXT NOT NULL, reproduction_steps TEXT NOT NULL,"
            " expected_behavior TEXT NOT NULL, actual_behavior TEXT NOT NULL, version TEXT NOT NULL,"
            " build_number TEXT NOT NULL, platform TEXT NOT NULL, os_version TEXT NOT NULL, email TEXT NOT NULL)"
        )
        connection.execute("CREATE INDEX IF NOT EXISTS reports_day ON reports(day)")
        connection.execute(
            "CREATE TABLE IF NOT EXISTS requests(key TEXT PRIMARY KEY, report_id TEXT NOT NULL, day TEXT NOT NULL)"
        )
        connection.execute("CREATE TABLE IF NOT EXISTS export_pending(day TEXT PRIMARY KEY)")
        return connection

    def _delete_expired(self, connection, now):
        cutoff = (now.date() - timedelta(days=BUG_REPORT_RETENTION_DAYS)).isoformat()
        for table in ("reports", "requests", "export_pending"):
            connection.execute(f"DELETE FROM {table} WHERE day < ?", (cutoff,))
        for path in self.directory.glob("bug-reports-*.json"):
            match = re.fullmatch(r"bug-reports-(\d{4}-\d{2}-\d{2})\.json", path.name)
            if match and match.group(1) < cutoff:
                path.unlink(missing_ok=True)

    def _delete_legacy_files(self, now):
        cutoff = now - timedelta(days=LEGACY_BUG_REPORT_RETENTION_DAYS)
        for folder in ("bug-report-contacts", "bug-report-requests"):
            for path in (self.directory / folder).glob("*.json"):
                try:
                    modified = datetime.fromtimestamp(path.stat().st_mtime, timezone.utc)
                except OSError:
                    continue
                if modified < cutoff:
                    path.unlink(missing_ok=True)

    def _export_pending(self, connection):
        days = [row[0] for row in connection.execute("SELECT day FROM export_pending ORDER BY day")]
        for day in days:
            reports = [
                {
                    "reportId": row[0],
                    "receivedAt": row[1],
                    "title": row[2],
                    "description": row[3],
                    "reproductionSteps": row[4],
                    "expectedBehavior": row[5],
                    "actualBehavior": row[6],
                    "environment": {"version": row[7], "buildNumber": row[8], "platform": row[9], "osVersion": row[10]},
                    "contactEmail": row[11],
                }
                for row in connection.execute(
                    "SELECT id, received_at, title, description, reproduction_steps, expected_behavior,"
                    " actual_behavior, version, build_number, platform, os_version, email"
                    " FROM reports WHERE day = ? ORDER BY received_at, id",
                    (day,),
                )
            ]
            try:
                write_private_json(self.directory, self.directory / f"bug-reports-{day}.json",
                                   {"schemaVersion": 1, "day": day, "reports": reports})
            except OSError:
                # The report is stored; the readable copy is rewritten next time.
                return
            connection.execute("DELETE FROM export_pending WHERE day = ?", (day,))


def write_private_json(directory, path, value):
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=directory)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w") as output:
            json.dump(value, output, ensure_ascii=False, sort_keys=True, indent=2)
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


class ErrorReportStore:
    """Automatic error reports, stored like the analytics aggregates.

    `error-reports-state.sqlite` holds one row per UTC day and fingerprint (and
    per environment under it); `error-reports-YYYY-MM-DD.json` is the readable
    copy of that day, rebuilt after each accepted report. Both are private
    (0600 in a 0700 directory) and deleted after `ERROR_REPORT_RETENTION_DAYS`.
    Nothing is published anywhere. Delivery IDs (kept `DEDUPE_RETENTION_DAYS`)
    remember how many occurrences each request already added, so a retry after
    a lost response adds only what is new.
    """

    def __init__(self, directory, *, google_identity_fetcher=None, now=None):
        self.directory = Path(directory)
        self._database = self.directory / "error-reports-state.sqlite"
        self._google_identity_fetcher = google_identity_fetcher or fetch_google_identity
        self._now = now or (lambda: datetime.now(timezone.utc))
        self._lock = threading.Lock()
        self._rate_lock = threading.Lock()
        self._rate_windows = defaultdict(list)

    def submit_error(self, payload, authorization, delivery_id=None):
        identity = self._google_identity_fetcher(authorization)
        subject = identity.get("sub") if isinstance(identity, dict) else None
        if not isinstance(subject, str) or not subject or len(subject) > 255 or identity.get("email_verified") is not True:
            raise InvalidGoogleToken()
        # The account is used only for rate limiting and never stored.
        subject_hash = hashlib.sha256(subject.encode()).hexdigest()
        if not isinstance(delivery_id, str) or not REQUEST_ID_PATTERN.fullmatch(delivery_id):
            delivery_id = None
        else:
            delivery_id = delivery_id.lower()
        self._check_rate(subject_hash)

        report = payload["report"]
        environment = payload["environment"]
        integrations = payload["integrations"]
        fingerprint = report["fingerprint"]
        environment_key = "|".join(
            environment[key] for key in ("version", "buildNumber", "platform", "osVersion", "environment")
        )
        now = self._now()
        day = now.date().isoformat()
        with self._lock:
            connection = self._connect()
            try:
                connection.execute("BEGIN IMMEDIATE")
                self._delete_expired(connection, now)
                acknowledged = 0
                if delivery_id is not None:
                    row = connection.execute(
                        "SELECT acknowledged FROM deliveries WHERE id = ?", (delivery_id,)
                    ).fetchone()
                    acknowledged = row[0] if row else 0
                added = max(report["occurrenceCount"] - acknowledged, 0)
                existing = connection.execute(
                    "SELECT severity FROM reports WHERE day = ? AND fingerprint = ?", (day, fingerprint)
                ).fetchone()
                if existing is None:
                    stored = connection.execute("SELECT COUNT(*) FROM reports WHERE day = ?", (day,)).fetchone()[0]
                    if stored >= MAX_ERROR_FINGERPRINTS_PER_DAY:
                        raise BugReportRateLimited()
                    connection.execute(
                        "INSERT INTO reports(day, fingerprint, severity, feature, error_type, message, stack_trace,"
                        " first_occurred_at, last_occurred_at, lifecycle, occurrences) VALUES (?,?,?,?,?,?,?,?,?,?,?)",
                        (
                            day, fingerprint, report["severity"], report["feature"], report["errorType"],
                            report["message"], report["stackTrace"], report["firstOccurredAt"],
                            report["lastOccurredAt"], report["lifecycle"], added,
                        ),
                    )
                else:
                    severity = "fatal" if "fatal" in (existing[0], report["severity"]) else "nonFatal"
                    connection.execute(
                        "UPDATE reports SET severity = ?, message = ?, stack_trace = ?, lifecycle = ?,"
                        " first_occurred_at = MIN(first_occurred_at, ?), last_occurred_at = MAX(last_occurred_at, ?),"
                        " occurrences = occurrences + ? WHERE day = ? AND fingerprint = ?",
                        (
                            severity, report["message"], report["stackTrace"], report["lifecycle"],
                            report["firstOccurredAt"], report["lastOccurredAt"], added, day, fingerprint,
                        ),
                    )
                known = connection.execute(
                    "SELECT 1 FROM environments WHERE day = ? AND fingerprint = ? AND key = ?",
                    (day, fingerprint, environment_key),
                ).fetchone()
                if known is not None:
                    connection.execute(
                        "UPDATE environments SET occurrences = occurrences + ?, details = ?"
                        " WHERE day = ? AND fingerprint = ? AND key = ?",
                        (added, json.dumps({**environment, **integrations}, sort_keys=True), day, fingerprint, environment_key),
                    )
                else:
                    count = connection.execute(
                        "SELECT COUNT(*) FROM environments WHERE day = ? AND fingerprint = ?", (day, fingerprint)
                    ).fetchone()[0]
                    if count < MAX_ERROR_REPORT_ENVIRONMENTS:
                        connection.execute(
                            "INSERT INTO environments(day, fingerprint, key, details, occurrences) VALUES (?,?,?,?,?)",
                            (day, fingerprint, environment_key, json.dumps({**environment, **integrations}, sort_keys=True), added),
                        )
                if delivery_id is not None:
                    connection.execute(
                        "INSERT INTO deliveries(id, day, acknowledged) VALUES (?,?,?)"
                        " ON CONFLICT(id) DO UPDATE SET acknowledged = MAX(acknowledged, excluded.acknowledged)",
                        (delivery_id, day, max(report["occurrenceCount"], acknowledged)),
                    )
                # Recorded with the data, so a failed export is retried by
                # later requests and after a restart.
                connection.execute("INSERT OR IGNORE INTO export_pending(day) VALUES (?)", (day,))
                connection.execute("COMMIT")
            except BaseException:
                if connection.in_transaction:
                    connection.execute("ROLLBACK")
                raise
            try:
                # Under the same lock, so an older snapshot never replaces a newer one.
                self._export_pending(connection)
            finally:
                connection.close()
        return {"status": "stored"}

    def _export_pending(self, connection):
        days = [row[0] for row in connection.execute("SELECT day FROM export_pending ORDER BY day")]
        for day in days:
            try:
                self._write_json(self.directory / f"error-reports-{day}.json", self._day_export(connection, day))
            except OSError:
                # The report is stored; the readable copy is rewritten next time.
                return
            connection.execute("DELETE FROM export_pending WHERE day = ?", (day,))

    def expire(self):
        """Deletes expired data without waiting for the next report."""
        with self._lock:
            connection = self._connect()
            try:
                connection.execute("BEGIN IMMEDIATE")
                self._delete_expired(connection, self._now())
                connection.execute("COMMIT")
            except BaseException:
                if connection.in_transaction:
                    connection.execute("ROLLBACK")
                raise
            finally:
                connection.close()

    def _check_rate(self, subject_hash):
        timestamp = self._now().timestamp()
        with self._rate_lock:
            window = [value for value in self._rate_windows[subject_hash] if timestamp - value < 60 * 60]
            if len(window) >= MAX_ERROR_REPORTS_PER_HOUR:
                self._rate_windows[subject_hash] = window
                raise BugReportRateLimited()
            window.append(timestamp)
            self._rate_windows[subject_hash] = window

    def _connect(self):
        Aggregator._make_private(self.directory, directory=True)
        if not self._database.exists():
            os.close(os.open(self._database, os.O_CREAT | os.O_WRONLY, 0o600))
        Aggregator._make_private(self._database)
        connection = sqlite3.connect(self._database, timeout=10, isolation_level=None)
        connection.execute(
            "CREATE TABLE IF NOT EXISTS reports(day TEXT NOT NULL, fingerprint TEXT NOT NULL,"
            " severity TEXT NOT NULL, feature TEXT NOT NULL, error_type TEXT NOT NULL, message TEXT NOT NULL,"
            " stack_trace TEXT NOT NULL, first_occurred_at TEXT NOT NULL, last_occurred_at TEXT NOT NULL,"
            " lifecycle TEXT NOT NULL, occurrences INTEGER NOT NULL, PRIMARY KEY(day, fingerprint))"
        )
        connection.execute(
            "CREATE TABLE IF NOT EXISTS environments(day TEXT NOT NULL, fingerprint TEXT NOT NULL,"
            " key TEXT NOT NULL, details TEXT NOT NULL, occurrences INTEGER NOT NULL,"
            " PRIMARY KEY(day, fingerprint, key))"
        )
        connection.execute(
            "CREATE TABLE IF NOT EXISTS deliveries(id TEXT PRIMARY KEY, day TEXT NOT NULL, acknowledged INTEGER NOT NULL)"
        )
        connection.execute("CREATE TABLE IF NOT EXISTS export_pending(day TEXT PRIMARY KEY)")
        return connection

    def _delete_expired(self, connection, now):
        today = now.date()
        report_cutoff = (today - timedelta(days=ERROR_REPORT_RETENTION_DAYS)).isoformat()
        delivery_cutoff = (today - timedelta(days=DEDUPE_RETENTION_DAYS)).isoformat()
        connection.execute("DELETE FROM reports WHERE day < ?", (report_cutoff,))
        connection.execute("DELETE FROM environments WHERE day < ?", (report_cutoff,))
        connection.execute("DELETE FROM deliveries WHERE day < ?", (delivery_cutoff,))
        connection.execute("DELETE FROM export_pending WHERE day < ?", (report_cutoff,))
        for path in self.directory.glob("error-reports-*.json"):
            match = re.fullmatch(r"error-reports-(\d{4}-\d{2}-\d{2})\.json", path.name)
            if match and match.group(1) < report_cutoff:
                path.unlink(missing_ok=True)

    @staticmethod
    def _day_export(connection, day):
        reports = []
        for row in connection.execute(
            "SELECT fingerprint, severity, feature, error_type, message, stack_trace, first_occurred_at,"
            " last_occurred_at, lifecycle, occurrences FROM reports WHERE day = ? ORDER BY fingerprint",
            (day,),
        ):
            environments = [
                {**json.loads(details), "occurrences": occurrences}
                for details, occurrences in connection.execute(
                    "SELECT details, occurrences FROM environments WHERE day = ? AND fingerprint = ? ORDER BY key",
                    (day, row[0]),
                )
            ]
            reports.append(
                {
                    "fingerprint": row[0],
                    "severity": row[1],
                    "feature": row[2],
                    "errorType": row[3],
                    "message": row[4],
                    "stackTrace": row[5],
                    "firstOccurredAt": row[6],
                    "lastOccurredAt": row[7],
                    "lifecycle": row[8],
                    "occurrences": row[9],
                    "environments": environments,
                }
            )
        return {"schemaVersion": 1, "day": day, "reports": reports}

    def _write_json(self, path, value):
        write_private_json(self.directory, path, value)


class ReceiverHandler(BaseHTTPRequestHandler):
    aggregator = None
    bug_reports = None
    error_reports = None
    rate_lock = threading.Lock()
    rate_windows = defaultdict(list)

    def log_message(self, _format, *_args):
        return

    def do_GET(self):
        if self.path == "/health":
            self._respond(200, {"status": "ok"})
        else:
            self._respond(404, {"error": "not_found"})

    def do_POST(self):
        if self.path not in {"/v1/events", "/v1/bug-reports", "/v1/error-reports"}:
            self._respond(404, {"error": "not_found"})
            return
        if not self._allow_request():
            self._respond(429, {"error": "rate_limited"})
            return
        if self.path == "/v1/events":
            self._post_events()
            return
        if self.path == "/v1/error-reports":
            self._post_error_report()
            return
        self._post_bug_report()

    def _post_error_report(self):
        payload, error_status, error_code = self._read_json(MAX_ERROR_REPORT_BYTES)
        if error_code is not None:
            self._respond(error_status, {"error": error_code})
            return
        normalized = normalize_error_report(payload)
        if normalized is None:
            self._respond(400, {"error": "invalid_report"})
            return
        try:
            result = self.error_reports.submit_error(
                normalized, self.headers.get("Authorization"), self.headers.get("Idempotency-Key")
            )
        except InvalidGoogleToken:
            self._respond(401, {"error": "invalid_google_token"})
            return
        except BugReportRateLimited:
            self._respond(429, {"error": "rate_limited"})
            return
        except UpstreamUnavailable:
            self._respond(503, {"error": "upstream_unavailable"})
            return
        except (OSError, sqlite3.Error):
            self._respond(500, {"error": "store_failed"})
            return
        self._respond(202, result)

    def _post_events(self):
        batch, error_status, error_code = self._read_json(MAX_REQUEST_BYTES)
        if error_code is not None:
            self._respond(error_status, {"error": error_code})
            return
        if not valid_batch(batch):
            self._respond(400, {"error": "invalid_schema"})
            return
        try:
            accepted = self.aggregator.accept(batch)
        except OSError:
            self._respond(500, {"error": "store_failed"})
            return
        self._respond(202, {"accepted": accepted})

    def _post_bug_report(self):
        payload, error_status, error_code = self._read_json(MAX_BUG_REPORT_BYTES)
        if error_code is not None:
            self._respond(error_status, {"error": error_code})
            return
        normalized = normalize_bug_report(payload)
        if normalized is None:
            self._respond(400, {"error": "invalid_report"})
            return
        try:
            submission = self.bug_reports.submit(
                normalized,
                self.headers.get("Authorization"),
                self.headers.get("Idempotency-Key"),
            )
        except InvalidGoogleToken:
            self._respond(401, {"error": "invalid_google_token"})
            return
        except BugReportRateLimited:
            self._respond(429, {"error": "rate_limited"})
            return
        except UpstreamUnavailable:
            self._respond(503, {"error": "upstream_unavailable"})
            return
        except (OSError, sqlite3.Error):
            self._respond(500, {"error": "store_failed"})
            return
        self._respond(201, submission)

    def _read_json(self, maximum):
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            length = 0
        if length <= 0 or length > maximum:
            return None, 413 if length > maximum else 400, "invalid_size"
        try:
            return json.loads(self.rfile.read(length)), None, None
        except (ValueError, UnicodeDecodeError):
            return None, 400, "invalid_json"

    def _allow_request(self):
        now = datetime.now(timezone.utc).timestamp()
        address = self.client_address[0]
        with self.rate_lock:
            window = [value for value in self.rate_windows[address] if now - value < 60]
            if len(window) >= MAX_REQUESTS_PER_MINUTE:
                self.rate_windows[address] = window
                return False
            window.append(now)
            self.rate_windows[address] = window
            return True

    def _respond(self, status, body):
        payload = json.dumps(body, separators=(",", ":")).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(payload)


REPORT_EXPIRY_INTERVAL_SECONDS = 6 * 60 * 60


def expire_stored_reports():
    """Retention must hold even when no new report arrives."""
    for store in (ReceiverHandler.bug_reports, ReceiverHandler.error_reports):
        try:
            store.expire()
        except (OSError, sqlite3.Error):
            # Retried on the next interval and on every submission.
            pass


def _expire_periodically():
    stop = threading.Event()
    while not stop.wait(REPORT_EXPIRY_INTERVAL_SECONDS):
        expire_stored_reports()


def main():
    address = os.environ.get("DAILY_ANALYTICS_BIND", "127.0.0.1")
    port = int(os.environ.get("DAILY_ANALYTICS_PORT", "8787"))
    directory = os.environ.get("DAILY_ANALYTICS_DATA_DIR", "var/analytics")
    ReceiverHandler.aggregator = Aggregator(directory, export_interval=REPORT_EXPORT_INTERVAL_SECONDS)
    ReceiverHandler.bug_reports = BugReportStore(directory)
    ReceiverHandler.error_reports = ErrorReportStore(directory)
    expire_stored_reports()
    threading.Thread(target=_expire_periodically, daemon=True).start()
    server = ThreadingHTTPServer((address, port), ReceiverHandler)
    server.daemon_threads = True

    def stop(_signum, _frame):
        threading.Thread(target=server.shutdown, daemon=True).start()

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    server.serve_forever()
    server.server_close()
    ReceiverHandler.aggregator.flush_report()


if __name__ == "__main__":
    main()
