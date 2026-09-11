import importlib.util
import json
import pathlib
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("reminders", ROOT / "packaging/linux/reminders.py")
reminders = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reminders)


class ReminderTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.directory = pathlib.Path(self.temporary.name)
        self.addCleanup(self.temporary.cleanup)

    def write(self, identifier=1, due=100, repeat=False):
        record = dict(id=identifier, title="Meeting", body="Details", scheduledAt=due, repeatsDaily=repeat)
        reminders.save(self.directory / f"{identifier}.json", record)

    def test_future_not_delivered(self):
        self.write(due=200)
        reminders.deliver(self.directory, 100, lambda _: self.fail("Early delivery"))
        self.assertTrue((self.directory / "1.json").exists())

    def test_due_delivered_once(self):
        self.write()
        sent = []
        reminders.deliver(self.directory, 120, lambda r: sent.append(r) or True)
        reminders.deliver(self.directory, 121, lambda r: sent.append(r) or True)
        self.assertEqual(len(sent), 1)

    def test_failed_delivery_retained_then_expires(self):
        self.write()
        reminders.deliver(self.directory, 120, lambda _: False)
        self.assertTrue((self.directory / "1.json").exists())
        reminders.deliver(self.directory, 401, lambda _: self.fail("Stale reminder"))
        self.assertFalse((self.directory / "1.json").exists())

    def test_daily_repeat_skips_missed_days(self):
        self.write(repeat=True)
        reminders.deliver(self.directory, 172930, lambda _: self.fail("Missed day"))
        record = json.loads((self.directory / "1.json").read_text())
        self.assertEqual(record["scheduledAt"], 259300)

    def test_update_replaces_same_id_not_same_title(self):
        self.write(identifier=1)
        self.write(identifier=2)
        self.write(identifier=1, due=500)
        sent = []
        reminders.deliver(self.directory, 120, lambda r: sent.append(r["id"]) or True)
        self.assertEqual(sent, [2])

    def test_corrupt_record_preserved_without_blocking_others(self):
        (self.directory / "1.json").write_text("broken")
        self.write(identifier=2)
        reminders.deliver(self.directory, 120, lambda _: True)
        self.assertTrue((self.directory / "1.invalid").exists())
        self.assertFalse((self.directory / "2.json").exists())

    def test_reject_path_or_command_as_id(self):
        with self.assertRaises(ValueError):
            reminders.validate(dict(id="../bad", title="", body="", scheduledAt=0, repeatsDaily=False))


if __name__ == "__main__":
    unittest.main()
