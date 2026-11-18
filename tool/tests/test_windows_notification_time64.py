import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "third_party/flutter_local_notifications_windows"
HEADER = (PKG / "src/ffi_api.h").read_text()
NATIVE = (PKG / "src/ffi_api.cpp").read_text()
BINDINGS = (PKG / "lib/src/ffi/bindings.dart").read_text()
PLUGIN = (PKG / "lib/src/plugin/ffi.dart").read_text()


class WindowsNotificationTime64Test(unittest.TestCase):
    """#222: the schedule time crosses the FFI boundary as a 64-bit second."""

    def test_header_native_and_dart_binding_agree_on_int64(self):
        self.assertIn("bool scheduleNotification(NativePlugin* plugin, int id, char* xml, int64_t time);", HEADER)
        self.assertIn("bool scheduleNotification(NativePlugin* plugin, int id, char* xml, int64_t time) {", NATIVE)
        lookup = BINDINGS[: BINDINGS.index(">('scheduleNotification')")]
        native_signature = lookup[lookup.rindex("ffi.Bool Function("):]
        self.assertEqual(re.findall(r"ffi\.(Int64|Int)\b", native_signature), ["Int", "Int64"])

    def test_refused_schedule_is_caught_natively_and_reported_in_dart(self):
        body = NATIVE[NATIVE.index("bool scheduleNotification("):]
        body = body[: body.index("\n}\n")]
        add = body.index("AddToSchedule(notification)")
        self.assertLess(body.rindex("try {", 0, add), add)
        self.assertIn("catch (winrt::hresult_error error)", body[add:])
        self.assertEqual(PLUGIN.count("_scheduleOrThrow("), 3)  # helper + two schedule methods
        self.assertNotIn("_bindings.scheduleNotification(\n      _plugin", PLUGIN)

    def test_seconds_reach_windows_without_32_bit_narrowing(self):
        conversion = "final int secondsSinceEpoch = scheduledDate.millisecondsSinceEpoch ~/ 1000;"
        self.assertEqual(PLUGIN.count(conversion), 2)  # both schedule methods
        self.assertIn("_bindings.scheduleNotification(plugin, id, xml, secondsSinceEpoch)", PLUGIN)
        self.assertNotRegex(PLUGIN, r"secondsSinceEpoch\s*(&|\.toSigned|\.toUnsigned|\.toInt)")
        self.assertIn("winrt::clock::from_time_t(static_cast<time_t>(time))", NATIVE)


if __name__ == "__main__":
    unittest.main()
