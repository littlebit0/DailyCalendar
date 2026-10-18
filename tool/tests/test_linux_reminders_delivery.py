import fcntl
import importlib.util
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("reminders", ROOT / "packaging/linux/reminders.py")
reminders = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reminders)

NOW = 1_800_000_000


def record(identifier, scheduled=NOW - 10, repeats=False):
    return {"id": identifier, "title": "t", "body": "b", "scheduledAt": scheduled, "repeatsDaily": repeats}


class DeliveryIsolationTest(unittest.TestCase):
    def run_batch(self, files, notify):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            for name, content in files.items():
                (folder / name).write_text(content)
            reminders.deliver(folder, NOW, notify)
            return sorted(path.name for path in folder.iterdir() if path.name != ".lock")

    def test_non_object_json_is_quarantined_and_later_reminders_still_fire(self):
        for corrupt in ("[]", "null", '"text"', "7"):
            delivered = []
            left = self.run_batch(
                {"000.json": corrupt, "001.json": json.dumps(record(1))},
                lambda value: delivered.append(value["id"]) or True,
            )
            self.assertEqual(delivered, [1], corrupt)
            self.assertEqual(left, ["000.invalid"], corrupt)

    def test_a_notify_timeout_does_not_stop_the_batch_and_keeps_the_record(self):
        delivered = []

        def notify(value):
            if value["id"] == 1:
                raise subprocess.TimeoutExpired("notify", 10)
            delivered.append(value["id"])
            return True

        left = self.run_batch(
            {"000.json": json.dumps(record(1)), "001.json": json.dumps(record(2))}, notify
        )
        self.assertEqual(delivered, [2])
        # The first one stays for the next timer run (still inside the grace window).
        self.assertEqual(left, ["000.json"])

    def test_repeating_reminder_is_rescheduled_after_delivery(self):
        left = self.run_batch({"000.json": json.dumps(record(1, repeats=True))}, lambda _value: True)
        self.assertEqual(left, ["000.json"])


class LockScopeTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.folder = Path(self.tmp.name)
        self.addCleanup(self.tmp.cleanup)

    def write(self, name, value):
        (self.folder / name).write_text(json.dumps(value))

    def lock_is_free(self):
        """True when another process could take the store lock right now."""
        with (self.folder / ".lock").open("a") as other:
            try:
                fcntl.flock(other, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                return False
            return True

    def test_the_store_lock_is_free_while_a_notification_is_being_delivered(self):
        self.write("000.json", record(1))
        self.write("001.json", record(2))
        observed = []

        def notify(_value):
            observed.append(self.lock_is_free())
            return True

        reminders.deliver(self.folder, NOW, notify)
        self.assertEqual(observed, [True, True])

    def test_a_reminder_cancelled_during_delivery_stays_cancelled(self):
        self.write("000.json", record(1, repeats=True))

        def notify(_value):
            (self.folder / "000.json").unlink()
            return True

        reminders.deliver(self.folder, NOW, notify)
        self.assertFalse((self.folder / "000.json").exists())

    def test_a_reminder_rescheduled_during_delivery_keeps_the_new_time(self):
        self.write("000.json", record(1))
        later = record(1, scheduled=NOW + 3600)

        def notify(_value):
            self.write("000.json", later)
            return True

        reminders.deliver(self.folder, NOW, notify)
        self.assertEqual(json.loads((self.folder / "000.json").read_text()), later)

    def test_a_late_reminder_is_dropped_without_a_notification(self):
        self.write("000.json", record(1, scheduled=NOW - 1000))
        calls = []
        reminders.deliver(self.folder, NOW, lambda value: calls.append(value) or True)
        self.assertEqual(calls, [])
        self.assertFalse((self.folder / "000.json").exists())


if __name__ == "__main__":
    unittest.main()
