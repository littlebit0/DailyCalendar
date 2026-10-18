"""Cancelling a one-time Android location request must release it from the manager."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
PLUGIN = ROOT / "third_party/geolocator_android/android/src/main/java/com/baseflow/geolocator"
HANDLER = (PLUGIN / "MethodCallHandlerImpl.java").read_text()
FUSED = (PLUGIN / "location/FusedLocationClient.java").read_text()


class GeolocatorAndroidCancelTest(unittest.TestCase):
    def test_cancel_removes_client_from_manager(self):
        cancel = HANDLER[HANDLER.index("private void onCancelGetCurrentPosition") :]
        self.assertIn("geolocationManager.stopPositionUpdates(locationClient)", cancel)
        self.assertNotIn("locationClient.stopPositionUpdates()", cancel)
        self.assertIn("pendingCurrentPositionLocationClients.remove(requestId)", cancel)

    def test_a_pending_settings_check_cannot_restart_cancelled_updates(self):
        start = FUSED[FUSED.index("public void startPositionUpdates") : FUSED.index("public void stopPositionUpdates")]
        # The start resets the flag, and both asynchronous callbacks honour it.
        self.assertIn("this.stopRequested = false;", start)
        success = start[start.index("addOnSuccessListener") : start.index("addOnFailureListener")]
        self.assertLess(success.index("if (stopRequested) return;"), success.index("requestPositionUpdates"))
        failure = start[start.index("addOnFailureListener") :]
        self.assertIn("if (stopRequested) return;", failure[:200])
        stop = FUSED[FUSED.index("public void stopPositionUpdates") :]
        self.assertIn("this.stopRequested = true;", stop[:120])
        result = FUSED[FUSED.index("public boolean onActivityResult") : FUSED.index("public void startPositionUpdates")]
        self.assertIn("stopRequested", result)

    def test_override_is_declared(self):
        pubspec = (ROOT / "pubspec.yaml").read_text()
        self.assertRegex(pubspec, r"geolocator_android:\n    path: third_party/geolocator_android")


if __name__ == "__main__":
    unittest.main()
