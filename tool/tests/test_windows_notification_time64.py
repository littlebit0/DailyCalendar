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

    def test_post_2038_seconds_need_more_than_32_bits(self):
        boundary = 2_147_483_647  # 2038-01-19 03:14:07 UTC
        year_2100 = 4_102_444_800
        self.assertGreater(year_2100, boundary)
        self.assertLess(year_2100, 2**63 - 1)


if __name__ == "__main__":
    unittest.main()
