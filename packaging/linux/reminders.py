#!/usr/bin/env python3
"""Per-user persistent reminders. Never run as root or log calendar contents."""
import contextlib
import fcntl
import html
import json
import os
import pathlib
import subprocess
import sys
import time
import uuid


def data_directory():
    base = os.environ.get("XDG_DATA_HOME", "")
    if not base.startswith("/"):
        base = str(pathlib.Path.home() / ".local/share")
    directory = pathlib.Path(base) / "dailycalendar/reminders"
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    return directory


@contextlib.contextmanager
def locked(directory):
    with (directory / ".lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield


def save(path, record):
    temporary = path.with_suffix(f".{uuid.uuid4().hex}.tmp")
    try:
        with temporary.open("x") as stream:
            json.dump(record, stream)
            stream.flush()
            os.fsync(stream.fileno())
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


def validate(record):
    if type(record.get("id")) is not int or abs(record["id"]) > 2147483647:
        raise ValueError("Invalid reminder id")
    if not isinstance(record.get("title"), str) or not isinstance(record.get("body"), str):
        raise ValueError("Invalid reminder content")
    if type(record.get("scheduledAt")) is not int or record["scheduledAt"] < 0:
        raise ValueError("Invalid reminder date")
    if type(record.get("repeatsDaily")) is not bool:
        raise ValueError("Invalid repeat flag")


def deliver(directory, now, notify):
    with locked(directory):
        for path in sorted(directory.glob("*.json")):
            try:
                record = json.loads(path.read_text())
                validate(record)
            except (ValueError, TypeError):
                # Preserve corrupt records for investigation, not repeated retries.
                path.rename(path.with_suffix(".invalid"))
                continue
            due = record["scheduledAt"]
            if due > now:
                continue
            if now - due <= 300 and not notify(record):
                continue
            if record["repeatsDaily"]:
                record["scheduledAt"] = due + (int((now - due) // 86400) + 1) * 86400
                save(path, record)
            else:
                path.unlink()


def notify(record):
    result = subprocess.run(
        ["notify-send", "--app-name=Daily", "--icon=com.littlebit0.daily",
         "--", record["title"], html.escape(record["body"])],
        timeout=10, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return result.returncode == 0


def main():
    if os.geteuid() == 0:
        raise RuntimeError("Daily notifications require a desktop user session")
    os.umask(0o077)
    directory = data_directory()
    command = sys.argv[1]
    if command == "initialize":
        subprocess.run(["systemctl", "--user", "daemon-reload"], check=True, timeout=15)
        subprocess.run(["systemctl", "--user", "enable", "--now",
                        "dailycalendar-reminders.timer"], check=True, timeout=15)
    elif command == "schedule":
        record = json.load(sys.stdin)
        validate(record)
        with locked(directory):
            save(directory / f'{record["id"]}.json', record)
    elif command == "cancel":
        identifier = int(sys.argv[2])
        with locked(directory):
            (directory / f"{identifier}.json").unlink(missing_ok=True)
    elif command == "count":
        with locked(directory):
            print(len(list(directory.glob("*.json"))))
    elif command == "run":
        deliver(directory, int(time.time()), notify)
    else:
        raise ValueError("Unknown reminder command")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        print("Daily notification operation failed; check the desktop session.", file=sys.stderr)
        sys.exit(1)
