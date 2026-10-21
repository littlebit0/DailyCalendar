import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
W = ROOT / "third_party/flutter_inappwebview_windows/windows"
MANAGER = (W / "in_app_webview/in_app_webview_manager.cpp").read_text()
GRAPHICS = (W / "custom_platform_view/graphics_context.cc").read_text()


class CaptureFactoryReleaseTest(unittest.TestCase):
    """#244: every GraphicsCapture activation factory is owned by a com_ptr."""

    FACTORIES = [
        (MANAGER, "IGraphicsCaptureSessionStatics", "capture_session_statics"),
        (GRAPHICS, "IGraphicsCaptureItemStatics", "capture_item_statics"),
        (GRAPHICS, "IDirect3D11CaptureFramePoolStatics", "capture_frame_pool_statics"),
        (GRAPHICS, "IDirect3D11CaptureFramePoolStatics2", "capture_frame_pool_statics"),
    ]

    def test_factories_are_received_into_com_ptr(self):
        for source, interface, name in self.FACTORIES:
            with self.subTest(interface=interface):
                self.assertRegex(
                    source,
                    r"winrt::com_ptr<ABI::Windows::Graphics::Capture::" + interface + r">\s+" + name + ";",
                )
        self.assertEqual(GRAPHICS.count(".put_void()))) {"), 4)  # compositor + three capture factories
        self.assertIn("capture_session_statics.put_void()", MANAGER)

    def test_no_raw_out_pointer_factory_remains(self):
        for source in (MANAGER, GRAPHICS):
            self.assertNotIn("(void**)&", source)
            self.assertIsNone(re.search(r"Capture::I\w+Statics2?\*\s*\n\s*\w+;", source))


if __name__ == "__main__":
    unittest.main()
