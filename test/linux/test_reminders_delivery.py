import importlib.util
import json
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


if __name__ == "__main__":
    unittest.main()
