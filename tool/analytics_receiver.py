#!/usr/bin/env python3
import hashlib
import json
import os
import re
import signal
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
MAX_BUG_REPORT_BYTES = 16 * 1024
MAX_BUG_REPORTS_PER_HOUR = 5
BUG_REPORT_RETENTION_DAYS = 365
GOOGLE_USERINFO_URL = "https://openidconnect.googleapis.com/v1/userinfo"
GITHUB_API_VERSION = "2026-03-10"
VERSION_PATTERN = re.compile(r"^\d+\.\d+\.\d+(?:\.\d+)?$")
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

SCHEMAS = {
    "app_load_completed": {"durationMs": "duration"},
    "screen_view": {"screen": "screen"},
    "calendar_view_changed": {"view": "view", "trigger": "trigger"},
    "event_editor_opened": {"mode": "mode", "trigger": "trigger"},
    "event_editor_completed": {
        "mode": "mode", "outcome": "outcome", "durationMs": "duration",
    },
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
    "sync_failed": {
        "operation": "syncOperation", "trigger": "trigger", "outcome": "failedOutcome",
        "durationMs": "duration", "errorCode": "errorCode",
    },
    "slow_interaction_detected": {
        "interaction": "interaction", "durationMs": "duration",
        "slowFrameCount": "frameCount",
    },
}


def _valid_value(kind, value):
    if kind == "duration":
        return type(value) is int and 0 <= value <= 120000
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
    if schema is None or not isinstance(attributes, dict) or set(attributes) != set(schema):
        return False
    return all(_valid_value(kind, attributes[key]) for key, kind in schema.items())


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
    if not VERSION_PATTERN.fullmatch(clean_environment["buildNumber"]):
        return None
    if clean_environment["platform"] not in {"iOS", "macOS", "Android", "Windows", "Linux"}:
        return None
    return {"report": clean_report, "environment": clean_environment}


class InvalidGoogleToken(Exception):
    pass


class UpstreamUnavailable(Exception):
    pass


class BugReportRateLimited(Exception):
    pass


class Aggregator:
    def __init__(self, directory):
        self.directory = Path(directory)
        self.lock = threading.Lock()

    def accept(self, batch):
        with self.lock:
            self.directory.mkdir(parents=True, exist_ok=True)
            self._delete_expired()
            now = datetime.now(timezone.utc)
            day = now.strftime("%Y-%m-%d")
            aggregate_path = self.directory / f"analytics-{day}.json"
            dedupe_path = self.directory / f"dedupe-{day}.json"
            aggregate = self._read_json(
                aggregate_path,
                {"schemaVersion": 1, "date": day, "groups": {}},
            )
            hashes = set(self._read_json(dedupe_path, []))
            environment = batch["environment"]
            accepted = 0
            for event in batch["events"]:
                event_hash = hashlib.sha256(event["eventId"].encode()).hexdigest()
                if event_hash in hashes:
                    continue
                hashes.add(event_hash)
                accepted += 1
                attributes = dict(sorted(event["attributes"].items()))
                key_data = {
                    "appVersion": environment["appVersion"],
                    "platform": environment["platform"],
                    "osMajor": environment["osMajor"],
                    "name": event["name"],
                    "attributes": attributes,
                }
                key = json.dumps(key_data, ensure_ascii=True, sort_keys=True, separators=(",", ":"))
                group = aggregate["groups"].setdefault(
                    key,
                    {**key_data, "count": 0, "durationTotalMs": 0, "durationMaxMs": 0},
                )
                group["count"] += 1
                duration = attributes.get("durationMs", 0)
                group["durationTotalMs"] += duration
                group["durationMaxMs"] = max(group["durationMaxMs"], duration)
            aggregate["updatedAt"] = now.isoformat().replace("+00:00", "Z")
            self._write_json(aggregate_path, aggregate)
            self._write_json(dedupe_path, sorted(hashes))
            return accepted

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

    def _delete_expired(self):
        now = datetime.now(timezone.utc).date()
        for path in self.directory.glob("*.json"):
            match = re.fullmatch(r"(analytics|dedupe)-(\d{4}-\d{2}-\d{2})\.json", path.name)
            if not match:
                continue
            try:
                date = datetime.strptime(match.group(2), "%Y-%m-%d").date()
            except ValueError:
                continue
            retention = 90 if match.group(1) == "analytics" else 7
            if now - date > timedelta(days=retention):
                path.unlink(missing_ok=True)


REQUEST_ID_PATTERN = re.compile(
    r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"
)


class BugReportBackend:
    def __init__(
        self,
        directory,
        *,
        github_token=None,
        github_repository=None,
        google_identity_fetcher=None,
        github_issue_creator=None,
        github_issue_finder=None,
        now=None,
    ):
        self.contact_directory = Path(directory) / "bug-report-contacts"
        self.request_directory = Path(directory) / "bug-report-requests"
        self.github_token = github_token if github_token is not None else os.environ.get("DAILY_GITHUB_TOKEN", "")
        self.github_repository = (
            github_repository
            if github_repository is not None
            else os.environ.get("DAILY_GITHUB_REPOSITORY", "littlebit0/DailyCalendar")
        )
        if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", self.github_repository):
            raise ValueError("invalid GitHub repository")
        self._google_identity_fetcher = google_identity_fetcher or self._fetch_google_identity
        self._github_issue_creator = github_issue_creator or self._create_github_issue
        self._github_issue_finder = github_issue_finder or self._find_github_issue
        self._request_lock = threading.Lock()
        self._inflight_requests = set()
        self._now = now or (lambda: datetime.now(timezone.utc))
        self._rate_lock = threading.Lock()
        self._rate_windows = defaultdict(list)

    def submit(self, payload, authorization, request_id=None):
        identity = self._google_identity_fetcher(authorization)
        subject = identity.get("sub") if isinstance(identity, dict) else None
        email = identity.get("email") if isinstance(identity, dict) else None
        email_verified = identity.get("email_verified") if isinstance(identity, dict) else None
        if (
            not isinstance(subject, str)
            or not subject
            or len(subject) > 255
            or not isinstance(email, str)
            or len(email) > 320
            or not EMAIL_PATTERN.fullmatch(email)
            or email_verified is not True
        ):
            raise InvalidGoogleToken()

        subject_hash = hashlib.sha256(subject.encode()).hexdigest()
        if not isinstance(request_id, str) or not REQUEST_ID_PATTERN.fullmatch(request_id):
            # Without a client request ID a retry cannot be told from a new report.
            self._check_report_rate(subject_hash)
            return self._create_report(payload, email, subject_hash, str(uuid.uuid4()), None)

        # The request ID is bound to the verified account, so another user cannot
        # read or reuse this report's result.
        key = hashlib.sha256(f"{subject_hash}:{request_id.lower()}".encode()).hexdigest()
        with self._request_lock:
            if key in self._inflight_requests:
                raise UpstreamUnavailable()
            self._inflight_requests.add(key)
        try:
            record = self._read_request(key)
            if record is not None and record.get("state") == "created":
                return {"issueNumber": record["issueNumber"], "issueUrl": record["issueUrl"]}
            if record is None:
                self._check_report_rate(subject_hash)
                report_id = str(uuid.uuid4())
                record = {
                    "schemaVersion": 1,
                    "reportId": report_id,
                    "state": "pending",
                    "createdAt": self._now().isoformat().replace("+00:00", "Z"),
                }
                self._write_request(key, record)
            else:
                # An earlier attempt ended without a known result. Never create a
                # second issue before checking whether the first one exists.
                report_id = record["reportId"]
                existing = self._github_issue_finder(report_id)
                if existing is not None:
                    return self._finish_report(
                        email, subject_hash, report_id, existing, key, record
                    )
            return self._create_report(payload, email, subject_hash, report_id, (key, record))
        finally:
            with self._request_lock:
                self._inflight_requests.discard(key)

    def _create_report(self, payload, email, subject_hash, report_id, request):
        created_at = self._now().isoformat().replace("+00:00", "Z")
        contact = {
            "schemaVersion": 1,
            "reportId": report_id,
            "createdAt": created_at,
            "status": "pending",
            "email": email,
            "googleSubjectHash": subject_hash,
        }
        contact_path = self._write_contact(contact)
        title, body = self._github_content(payload, report_id)

        def fail():
            if request is None:
                contact_path.unlink(missing_ok=True)
            else:
                # The issue may exist even though no answer arrived: keep the
                # private contact and let the same request resolve it.
                key, record = request
                self._write_request(key, {**record, "state": "unknown"})
            raise UpstreamUnavailable()

        try:
            issue = self._github_issue_creator(title, body)
        except Exception:
            fail()
        issue_number = issue.get("number") if isinstance(issue, dict) else None
        issue_url = issue.get("html_url") if isinstance(issue, dict) else None
        if type(issue_number) is not int or not self._valid_issue_url(issue_url, issue_number):
            fail()
        return self._finish_report(
            email, subject_hash, report_id, issue, *(request or (None, None)), contact=contact, contact_path=contact_path
        )

    def _finish_report(
        self, email, subject_hash, report_id, issue, key=None, record=None, *, contact=None, contact_path=None
    ):
        issue_number = issue.get("number")
        issue_url = issue.get("html_url")
        if contact is None:
            contact_path = self.contact_directory / f"{report_id}.json"
            try:
                contact = json.loads(contact_path.read_text())
            except (OSError, ValueError):
                contact = {
                    "schemaVersion": 1,
                    "reportId": report_id,
                    "createdAt": self._now().isoformat().replace("+00:00", "Z"),
                    "email": email,
                    "googleSubjectHash": subject_hash,
                }
        contact.update({"status": "created", "issueNumber": issue_number, "issueUrl": issue_url})
        try:
            self._write_contact(contact, path=contact_path)
        except OSError:
            # The pending file still retains the private contact and report ID.
            # Returning the created issue avoids duplicate reports on retry.
            pass
        if key is not None:
            try:
                self._write_request(
                    key,
                    {**record, "state": "created", "issueNumber": issue_number, "issueUrl": issue_url},
                )
            except OSError:
                pass
        return {"issueNumber": issue_number, "issueUrl": issue_url}

    def _read_request(self, key):
        try:
            record = json.loads((self.request_directory / f"{key}.json").read_text())
        except (OSError, ValueError):
            return None
        if (
            not isinstance(record, dict)
            or not isinstance(record.get("reportId"), str)
            or not REQUEST_ID_PATTERN.fullmatch(record["reportId"])
        ):
            return None
        if record.get("state") == "created" and (
            type(record.get("issueNumber")) is not int
            or not self._valid_issue_url(record.get("issueUrl"), record.get("issueNumber"))
        ):
            return None
        return record

    def _write_request(self, key, record):
        self.request_directory.mkdir(parents=True, exist_ok=True)
        os.chmod(self.request_directory, 0o700)
        target = self.request_directory / f"{key}.json"
        fd, temporary = tempfile.mkstemp(prefix=f".{target.name}.", dir=self.request_directory)
        try:
            os.fchmod(fd, 0o600)
            with os.fdopen(fd, "w") as output:
                json.dump(record, output, ensure_ascii=True, sort_keys=True, separators=(",", ":"))
                output.flush()
                os.fsync(output.fileno())
            os.replace(temporary, target)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)

    def _find_github_issue(self, report_id):
        """Finds an already created issue by its report ID marker, or None."""
        if not self.github_token:
            raise UpstreamUnavailable()
        request = Request(
            f"https://api.github.com/repos/{self.github_repository}/issues"
            "?state=all&sort=created&direction=desc&per_page=100",
            headers={
                "Accept": "application/vnd.github+json",
                "Authorization": f"Bearer {self.github_token}",
                "X-GitHub-Api-Version": GITHUB_API_VERSION,
                "User-Agent": "DailyCalendar-Bug-Reporter",
            },
            method="GET",
        )
        try:
            with urlopen(request, timeout=15) as response:
                response_body = response.read(2 * 1024 * 1024 + 1)
        except (HTTPError, OSError, URLError, TimeoutError):
            raise UpstreamUnavailable() from None
        if len(response_body) > 2 * 1024 * 1024:
            raise UpstreamUnavailable()
        try:
            decoded = json.loads(response_body)
        except (TypeError, ValueError, UnicodeDecodeError):
            raise UpstreamUnavailable() from None
        if not isinstance(decoded, list):
            raise UpstreamUnavailable()
        for issue in decoded:
            if (
                isinstance(issue, dict)
                and "pull_request" not in issue
                and isinstance(issue.get("body"), str)
                and f"`{report_id}`" in issue["body"]
                and type(issue.get("number")) is int
                and self._valid_issue_url(issue.get("html_url"), issue["number"])
            ):
                return {"number": issue["number"], "html_url": issue["html_url"]}
        return None

    def _fetch_google_identity(self, authorization):
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

    def _create_github_issue(self, title, body):
        if not self.github_token:
            raise UpstreamUnavailable()
        request = Request(
            f"https://api.github.com/repos/{self.github_repository}/issues",
            data=json.dumps({"title": title, "body": body}, ensure_ascii=False).encode(),
            headers={
                "Accept": "application/vnd.github+json",
                "Authorization": f"Bearer {self.github_token}",
                "Content-Type": "application/json",
                "X-GitHub-Api-Version": GITHUB_API_VERSION,
                "User-Agent": "DailyCalendar-Bug-Reporter",
            },
            method="POST",
        )
        try:
            with urlopen(request, timeout=15) as response:
                response_body = response.read(128 * 1024 + 1)
        except (HTTPError, OSError, URLError, TimeoutError):
            raise UpstreamUnavailable() from None
        if len(response_body) > 128 * 1024:
            raise UpstreamUnavailable()
        try:
            decoded = json.loads(response_body)
        except (TypeError, ValueError, UnicodeDecodeError):
            raise UpstreamUnavailable() from None
        if not isinstance(decoded, dict):
            raise UpstreamUnavailable()
        return decoded

    def _check_report_rate(self, subject_hash):
        timestamp = self._now().timestamp()
        with self._rate_lock:
            window = [
                value
                for value in self._rate_windows[subject_hash]
                if timestamp - value < 60 * 60
            ]
            if len(window) >= MAX_BUG_REPORTS_PER_HOUR:
                self._rate_windows[subject_hash] = window
                raise BugReportRateLimited()
            window.append(timestamp)
            self._rate_windows[subject_hash] = window

    def _github_content(self, payload, report_id):
        report = payload["report"]
        environment = payload["environment"]
        title = f"[Bug] {report['title']}"
        body = "\n".join(
            [
                "## 문제 설명 / Description",
                report["description"],
                "",
                "## 재현 방법 / Steps to reproduce",
                report["reproductionSteps"],
                "",
                "## 예상 동작 / Expected behavior",
                report["expectedBehavior"],
                "",
                "## 실제 동작 / Actual behavior",
                report["actualBehavior"],
                "",
                "## 실행 환경 / Environment",
                f"- Daily: {environment['version']} ({environment['buildNumber']})",
                f"- 플랫폼: {environment['platform']}",
                f"- OS: {environment['osVersion']}",
                f"- 제보 ID: `{report_id}`",
                "- Google 로그인: 서버 검증 완료",
                "",
                "> 연락용 이메일은 공개 이슈에 포함하지 않고 Daily 운영 서버의 비공개 연락 정보로만 보관합니다.",
            ]
        )
        return title, body

    def _write_contact(self, value, *, path=None):
        self.contact_directory.mkdir(parents=True, exist_ok=True)
        os.chmod(self.contact_directory, 0o700)
        self._delete_expired_contacts()
        target = path or self.contact_directory / f"{value['reportId']}.json"
        fd, temporary = tempfile.mkstemp(prefix=f".{target.name}.", dir=self.contact_directory)
        try:
            os.fchmod(fd, 0o600)
            with os.fdopen(fd, "w") as output:
                json.dump(value, output, ensure_ascii=True, sort_keys=True, separators=(",", ":"))
                output.flush()
                os.fsync(output.fileno())
            os.replace(temporary, target)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
        return target

    def _delete_expired_contacts(self):
        cutoff = self._now() - timedelta(days=BUG_REPORT_RETENTION_DAYS)
        for path in self.contact_directory.glob("*.json"):
            try:
                modified = datetime.fromtimestamp(path.stat().st_mtime, timezone.utc)
            except OSError:
                continue
            if modified < cutoff:
                path.unlink(missing_ok=True)
        for path in self.request_directory.glob("*.json"):
            try:
                modified = datetime.fromtimestamp(path.stat().st_mtime, timezone.utc)
            except OSError:
                continue
            if modified < cutoff:
                path.unlink(missing_ok=True)

    def _valid_issue_url(self, value, issue_number):
        return (
            isinstance(value, str)
            and value == f"https://github.com/{self.github_repository}/issues/{issue_number}"
        )


class ReceiverHandler(BaseHTTPRequestHandler):
    aggregator = None
    bug_reports = None
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
        if self.path not in {"/v1/events", "/v1/bug-reports"}:
            self._respond(404, {"error": "not_found"})
            return
        if not self._allow_request():
            self._respond(429, {"error": "rate_limited"})
            return
        if self.path == "/v1/events":
            self._post_events()
            return
        self._post_bug_report()

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
        except OSError:
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


def main():
    address = os.environ.get("DAILY_ANALYTICS_BIND", "127.0.0.1")
    port = int(os.environ.get("DAILY_ANALYTICS_PORT", "8787"))
    directory = os.environ.get("DAILY_ANALYTICS_DATA_DIR", "var/analytics")
    ReceiverHandler.aggregator = Aggregator(directory)
    ReceiverHandler.bug_reports = BugReportBackend(directory)
    server = ThreadingHTTPServer((address, port), ReceiverHandler)
    server.daemon_threads = True

    def stop(_signum, _frame):
        threading.Thread(target=server.shutdown, daemon=True).start()

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    server.serve_forever()
    server.server_close()


if __name__ == "__main__":
    main()
