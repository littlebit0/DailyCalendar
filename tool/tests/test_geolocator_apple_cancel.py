"""Timeout cancellation in the vendored geolocator_apple plugin (#227)."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCES = ROOT / "third_party/geolocator_apple/darwin/geolocator_apple/Sources/geolocator_apple"
DART = (ROOT / "third_party/geolocator_apple/lib/src/geolocator_apple.dart").read_text()
PLUGIN = (SOURCES / "GeolocatorPlugin.m").read_text()
HEADER = (SOURCES / "include/geolocator_apple/Handlers/GeolocationHandler.h").read_text()


class GeolocatorAppleCancelTest(unittest.TestCase):
    def test_dart_sends_the_same_request_id_on_cancel(self):
        self.assertIn("'requestId': requestId", DART)
        self.assertIn("'cancelGetCurrentPosition'", DART)
        cancel = DART[DART.index("'cancelGetCurrentPosition'") :][:160]
        self.assertIn("'requestId': requestId", cancel)

    def test_plugin_cancels_by_request_id_only(self):
        branch = PLUGIN[PLUGIN.index('"cancelGetCurrentPosition"') :][:500]
        self.assertIn("cancelOneTimeRequestWithId", branch)
        self.assertNotIn("stopOneTimeLocationListening", branch)
        self.assertIn("cancelOneTimeRequestWithId", HEADER)

    @unittest.skipUnless(shutil.which("clang") and shutil.which("xcrun"), "clang and the Apple SDK are required")
    def test_native_handler_stops_updates_and_ignores_stale_requests(self):
        with tempfile.TemporaryDirectory() as directory:
            executable = Path(directory) / "handler_test"
            build = subprocess.run(
                [
                    "clang", "-fobjc-arc", "-Wno-nullability-completeness",
                    "-framework", "Foundation", "-framework", "CoreLocation",
                    str(ROOT / "tool/tests/geolocator_apple_handler_test.m"),
                    str(SOURCES / "Handlers/GeolocationHandler.m"),
                    str(SOURCES / "Constants/ErrorCodes.m"),
                    "-I", str(SOURCES / "include"),
                    "-o", str(executable),
                ],
                capture_output=True, text=True,
            )
            self.assertEqual(build.returncode, 0, build.stderr)
            run = subprocess.run([str(executable)], capture_output=True, text=True)
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertIn("geolocator_apple handler checks passed", run.stdout)


if __name__ == "__main__":
    unittest.main()
