"""The Apple plugin must expose and implement cancelGetCurrentPosition."""
from pathlib import Path
import unittest

SRC = Path(__file__).resolve().parents[2] / "third_party/geolocator_apple/darwin/geolocator_apple/Sources/geolocator_apple"


class GeolocatorAppleCancelTest(unittest.TestCase):
    def test_cancel_method_stops_one_time_manager(self):
        plugin = (SRC / "GeolocatorPlugin.m").read_text()
        branch = plugin[plugin.index('"cancelGetCurrentPosition"') :][:400]
        self.assertIn("stopOneTimeLocationListening", branch)
        self.assertIn("result(nil)", branch)

    def test_method_is_declared_for_the_plugin(self):
        header = (SRC / "include/geolocator_apple/Handlers/GeolocationHandler.h").read_text()
        self.assertIn("- (void)stopOneTimeLocationListening;", header)


if __name__ == "__main__":
    unittest.main()
