#!/usr/bin/env python3
"""Per-user persistent reminders. Never run as root or log calendar contents."""
import contextlib
import fcntl
import html
import json
import os
import pathlib
import socket
import struct
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


class _Writer:
    """Minimal D-Bus marshalling (little endian) for the calls this helper needs."""

    def __init__(self):
        self.data = bytearray()

    def align(self, size):
        self.data.extend(b"\0" * (-len(self.data) % size))

    def u32(self, value):
        self.align(4)
        self.data += struct.pack("<I", value)

    def i32(self, value):
        self.align(4)
        self.data += struct.pack("<i", value)

    def string(self, value):
        raw = value.replace("\0", "").encode("utf-8")
        self.u32(len(raw))
        self.data += raw + b"\0"

    def signature(self, value):
        self.data += bytes([len(value)]) + value.encode("ascii") + b"\0"


def _message(serial, destination, path, interface, member, signature="", body=b""):
    fields = _Writer()
    for code, kind, value in ((1, "o", path), (2, "s", interface), (3, "s", member),
                              (6, "s", destination)):
        fields.align(8)
        fields.data.append(code)
        fields.signature(kind)
        fields.string(value)
    if signature:
        fields.align(8)
        fields.data.append(8)
        fields.signature("g")
        fields.signature(signature)
    header = struct.pack("<BBBBIII", ord("l"), 1, 0, 1, len(body), serial, len(fields.data))
    out = bytearray(header + bytes(fields.data))
    out.extend(b"\0" * (-len(out) % 8))
    return bytes(out) + body


def _read_exact(connection, count):
    data = bytearray()
    while len(data) < count:
        chunk = connection.recv(count - len(data))
        if not chunk:
            raise ConnectionError("D-Bus connection closed")
        data += chunk
    return bytes(data)


def _read_reply(connection, serial):
    """Waits for the method return of [serial]; signals are skipped."""
    while True:
        fixed = _read_exact(connection, 16)
        _, kind, _, _, body_length, _, fields_length = struct.unpack("<BBBBIII", fixed)
        rest = _read_exact(connection, fields_length + (-(16 + fields_length) % 8) + body_length)
        if kind not in (2, 3):
            continue
        reply_to = None
        offset = 0
        fields = rest[:fields_length]
        while offset < len(fields):
            offset += -offset % 8
            if offset >= len(fields):
                break
            code, length = fields[offset], fields[offset + 1]
            kind_char = fields[offset + 2:offset + 2 + length]
            offset += 3 + length
            if kind_char == b"u":
                offset += -offset % 4
                value = struct.unpack_from("<I", fields, offset)[0]
                offset += 4
                if code == 5:
                    reply_to = value
            elif kind_char in (b"s", b"o"):
                offset += -offset % 4
                size = struct.unpack_from("<I", fields, offset)[0]
                offset += 4 + size + 1
            elif kind_char == b"g":
                offset += 1 + fields[offset] + 1
            else:
                raise ValueError("Unexpected D-Bus header field")
        if reply_to == serial:
            return kind == 2


def _session_bus_path():
    for address in os.environ.get("DBUS_SESSION_BUS_ADDRESS", "").split(";"):
        if not address.startswith("unix:"):
            continue
        options = dict(part.split("=", 1) for part in address[5:].split(",") if "=" in part)
        if "path" in options:
            return options["path"]
        if "abstract" in options:
            return "\0" + options["abstract"]
    return f"/run/user/{os.geteuid()}/bus"


def notify(record):
    """Sends the notification over D-Bus so its content never enters argv or env."""
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
            connection.settimeout(10)
            connection.connect(_session_bus_path())
            connection.sendall(b"\0AUTH EXTERNAL " + str(os.geteuid()).encode().hex().encode() + b"\r\n")
            if not _read_line(connection).startswith(b"OK"):
                return False
            connection.sendall(b"BEGIN\r\n")
            connection.sendall(_message(1, "org.freedesktop.DBus", "/org/freedesktop/DBus",
                                        "org.freedesktop.DBus", "Hello"))
            if not _read_reply(connection, 1):
                return False
            body = _Writer()
            body.string("Daily")
            body.u32(0)
            body.string("com.littlebit0.daily")
            body.string(record["title"])
            body.string(html.escape(record["body"]))
            body.u32(0)  # actions: empty string array
            body.u32(0)  # hints: empty a{sv}, padded to its 8-byte element alignment
            body.align(8)
            body.i32(-1)
            connection.sendall(_message(
                2, "org.freedesktop.Notifications", "/org/freedesktop/Notifications",
                "org.freedesktop.Notifications", "Notify", "susssasa{sv}i", bytes(body.data)))
            return _read_reply(connection, 2)
    except (OSError, ValueError, struct.error):
        return False


def _read_line(connection):
    line = bytearray()
    while not line.endswith(b"\r\n"):
        line += _read_exact(connection, 1)
    return bytes(line)


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
