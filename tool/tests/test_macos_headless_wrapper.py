import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CLASSES = ROOT / "third_party/flutter_inappwebview_macos/macos/Classes/HeadlessInAppWebView"
SWIFT = (CLASSES / "HeadlessInAppWebView.swift").read_text()


def body(signature):
    start = SWIFT.index(signature)
    depth, i = 0, SWIFT.index("{", start)
    while True:
        depth += {"{": 1, "}": -1}.get(SWIFT[i], 0)
        if depth == 0:
            return SWIFT[start:i]
        i += 1


class HeadlessWrapperOwnershipTest(unittest.TestCase):
    """#235: a headless run leaves no empty wrapper in the window."""

    @unittest.skipUnless(shutil.which("swiftc"), "Swift compiler is required")
    def test_wrapper_hierarchy_behavior(self):
        with tempfile.TemporaryDirectory() as directory:
            executable = Path(directory) / "headless_wrapper"
            compiled = subprocess.run(
                ["swiftc", "-parse-as-library", str(CLASSES / "HeadlessViewWrapper.swift"),
                 str(ROOT / "tool/tests/headless_view_wrapper_test.swift"), "-o", str(executable)],
                capture_output=True, text=True)
            self.assertEqual(compiled.returncode, 0, compiled.stderr)
            run = subprocess.run([str(executable)], capture_output=True, text=True)
            self.assertEqual(run.returncode, 0, run.stdout + run.stderr)

    def test_headless_view_uses_the_wrapper_on_every_path(self):
        self.assertIn("wrapper.attach(view, to: NSApplication.shared.mainWindow?.contentView)",
                      body("public func prepare(params: NSDictionary)"))
        self.assertIn("wrapper.remove()", body("public func dispose(disposeWebView: Bool)"))
        # The visible move and the plain dispose both go through dispose(disposeWebView:).
        self.assertIn("dispose(disposeWebView: false)", body("public func disposeAndGetFlutterWebView"))
        self.assertIn("dispose(disposeWebView: true)", body("public func dispose()"))
        self.assertNotIn("NSView()", SWIFT)


if __name__ == "__main__":
    unittest.main()
