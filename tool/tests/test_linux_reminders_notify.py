import importlib.util
import os
import socket
import struct
import tempfile
import threading
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("reminders", ROOT / "packaging/linux/reminders.py")
reminders = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reminders)


def read_string(data, offset):
    offset += -offset % 4
    size = struct.unpack_from("<I", data, offset)[0]
    return data[offset + 4:offset + 4 + size].decode(), offset + 4 + size + 1


class FakeBus(threading.Thread):
    """Accepts one client, authenticates it and records the Notify call."""

    def __init__(self, path, notify_ok=True):
        super().__init__(daemon=True)
        self.server = socket.socket(socket.AF_UNIX)
        self.server.bind(path)
        self.server.listen(1)
        self.notify_ok = notify_ok
        self.calls = []

    def read_message(self, connection):
        fixed = reminders._read_exact(connection, 16)
        _, _, _, _, body_length, serial, fields_length = struct.unpack("<BBBBIII", fixed)
        rest = reminders._read_exact(connection, fields_length + (-(16 + fields_length) % 8) + body_length)
        return serial, rest[:fields_length], rest[len(rest) - body_length:]

    def reply(self, connection, to, kind=2):
        fields = reminders._Writer()
        fields.data.append(5)
        fields.signature("u")
        fields.u32(to)
        header = struct.pack("<BBBBIII", ord("l"), kind, 0, 1, 0, 99, len(fields.data))
        out = header + bytes(fields.data)
        connection.sendall(out + b"\0" * (-len(out) % 8))

    def run(self):
        connection, _ = self.server.accept()
        with connection:
            reminders._read_exact(connection, 1)
            auth = reminders._read_line(connection)
            assert auth.startswith(b"AUTH EXTERNAL "), auth
            connection.sendall(b"OK 0123\r\n")
            assert reminders._read_line(connection) == b"BEGIN\r\n"
            serial, _, _ = self.read_message(connection)
            self.reply(connection, serial)
            serial, fields, body = self.read_message(connection)
            self.calls.append((fields, body))
            self.reply(connection, serial, 2 if self.notify_ok else 3)


class NotifyOverDBusTest(unittest.TestCase):
    def deliver(self, notify_ok=True):
        record = {"title": "회의 <b>", "body": "장소 & 시간"}
        with tempfile.TemporaryDirectory() as directory:
            path = str(Path(directory) / "bus")
            bus = FakeBus(path, notify_ok)
            bus.start()
            environment = {"DBUS_SESSION_BUS_ADDRESS": f"unix:path={path},guid=1"}
            with mock.patch.dict(os.environ, environment), \
                    mock.patch.object(reminders.subprocess, "run", side_effect=AssertionError("no process")):
                result = reminders.notify(record)
            bus.join(5)
            return result, bus.calls

    def test_content_travels_over_the_bus_not_through_a_process(self):
        result, calls = self.deliver()
        self.assertTrue(result)
        fields, body = calls[0]
        self.assertIn(b"susssasa{sv}i", fields)
        app, offset = read_string(body, 0)
        offset += -offset % 4 + 4  # replaces_id
        icon, offset = read_string(body, offset)
        summary, offset = read_string(body, offset)
        text, offset = read_string(body, offset)
        self.assertEqual((app, icon), ("Daily", "com.littlebit0.daily"))
        self.assertEqual(summary, "회의 <b>")
        self.assertEqual(text, "장소 &amp; 시간")
        offset += -offset % 4 + 4  # actions
        offset += -offset % 4 + 4  # hints length
        offset += -offset % 8
        self.assertEqual(struct.unpack_from("<i", body, offset)[0], -1)
        self.assertEqual(offset + 4, len(body))

    def test_bus_error_keeps_the_reminder_for_retry(self):
        self.assertFalse(self.deliver(notify_ok=False)[0])

    def test_missing_session_bus_is_not_fatal(self):
        with mock.patch.dict(os.environ, {"DBUS_SESSION_BUS_ADDRESS": "unix:path=/nonexistent/bus"}):
            self.assertFalse(reminders.notify({"title": "a", "body": "b"}))


if __name__ == "__main__":
    unittest.main()
