"""Cancelling a one-time Android location request must release it from the manager."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
HANDLER = (ROOT / "third_party/geolocator_android/android/src/main/java/com/baseflow/geolocator/MethodCallHandlerImpl.java").read_text()


class GeolocatorAndroidCancelTest(unittest.TestCase):
    def test_cancel_removes_client_from_manager(self):
        cancel = HANDLER[HANDLER.index("private void onCancelGetCurrentPosition") :]
        self.assertIn("geolocationManager.stopPositionUpdates(locationClient)", cancel)
        self.assertNotIn("locationClient.stopPositionUpdates()", cancel)
        self.assertIn("pendingCurrentPositionLocationClients.remove(requestId)", cancel)

    def test_override_is_declared(self):
        pubspec = (ROOT / "pubspec.yaml").read_text()
        self.assertRegex(pubspec, r"geolocator_android:\n    path: third_party/geolocator_android")


if __name__ == "__main__":
    unittest.main()
