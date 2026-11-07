import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CORE = (ROOT / "third_party/flutter_inappwebview_windows/windows/in_app_webview/in_app_webview.cpp").read_text()


class WebViewController3ReleaseTest(unittest.TestCase):
    """#401: composition controller setup must not leak a raw ICoreWebView2Controller3 reference."""

    def test_no_raw_controller3_out_pointer(self):
        self.assertIsNone(re.search(r"ICoreWebView2Controller3\s*\*\s*\w+\s*;", CORE))

    def test_both_composition_branches_configure_owned_controller(self):
        owned = "wil::com_ptr<ICoreWebView2Controller3> webViewController = compositionController.try_query<ICoreWebView2Controller3>();"
        self.assertEqual(CORE.count(owned), 2)
        for setter in (
            "webViewController->put_BoundsMode(COREWEBVIEW2_BOUNDS_MODE_USE_RAW_PIXELS);",
            "webViewController->put_ShouldDetectMonitorScaleChanges(FALSE);",
            "webViewController->put_RasterizationScale(1.0);",
        ):
            with self.subTest(setter=setter):
                self.assertEqual(CORE.count(setter), 2)


if __name__ == "__main__":
    unittest.main()
