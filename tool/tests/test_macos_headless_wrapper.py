import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SWIFT = (ROOT / "third_party/flutter_inappwebview_macos/macos/Classes/HeadlessInAppWebView/HeadlessInAppWebView.swift").read_text()


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

    def test_prepare_keeps_its_own_wrapper_and_replaces_an_old_one(self):
        prepare = body("public func prepare(params: NSDictionary)")
        self.assertLess(prepare.index("removeWrapperView()"), prepare.index("let wrapperView = NSView()"))
        self.assertIn("self.wrapperView = wrapperView", prepare)

    def test_every_dispose_path_removes_only_the_stored_wrapper(self):
        dispose = body("public func dispose(disposeWebView: Bool)")
        self.assertIn("removeWrapperView()", dispose)
        # The visible move and the plain dispose both go through dispose(disposeWebView:).
        self.assertIn("dispose(disposeWebView: false)", body("public func disposeAndGetFlutterWebView"))
        self.assertIn("dispose(disposeWebView: true)", body("public func dispose()"))
        remove = body("private func removeWrapperView()")
        self.assertIn("wrapperView?.removeFromSuperview()", remove)
        self.assertIn("wrapperView = nil", remove)
        self.assertNotIn("subviews", SWIFT)


if __name__ == "__main__":
    unittest.main()
