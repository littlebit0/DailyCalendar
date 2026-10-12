"""Check production password-input scope without changing the host input method."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
CHANNEL_STUBS = r'''
protocol FlutterBinaryMessenger {}
final class Messenger: FlutterBinaryMessenger {}
struct FlutterMethodCall { let method: String; let arguments: Any? }
let FlutterMethodNotImplemented = "not implemented"
struct FlutterError { init(code: String, message: String?, details: Any?) {} }
final class FlutterMethodChannel {
  static var handler: ((FlutterMethodCall, (Any?) -> Void) -> Void)?
  init(name: String, binaryMessenger: FlutterBinaryMessenger) {}
  func setMethodCallHandler(_ handler: @escaping (FlutterMethodCall, (Any?) -> Void) -> Void) {
    Self.handler = handler
  }
}
'''
CONTEXT_STUBS = r'''
typealias NSTextInputSourceIdentifier = String
final class NSTextInputContext {
  var allowedInputSourceLocales: [String]? = ["ko", "en"]
  var selectedKeyboardInputSource: String? = "com.apple.inputmethod.Korean.2SetKorean"
  var keyboardInputSources: [String]? = ["com.apple.inputmethod.Korean.2SetKorean", "com.apple.keylayout.ABC"]
}
final class NSTextView: NSObject { var inputContext: NSTextInputContext? }
final class NSWindow: NSObject {
  static let didResignKeyNotification = Notification.Name("resign")
  static let didBecomeKeyNotification = Notification.Name("become")
  static let willCloseNotification = Notification.Name("close")
  var isKeyWindow = true
  var firstResponder: AnyObject?
}
'''
CHECKS = r'''
let active = NSTextInputContext()
let editor = NSTextView()
editor.inputContext = active
let window = NSWindow()
window.firstResponder = editor
private let bridge = DailyPasswordInputBridge(messenger: Messenger(), window: window)
func mode(_ value: Bool) {
  var result: Any?
  FlutterMethodChannel.handler!(FlutterMethodCall(method: "setEnglishInput", arguments: value)) { result = $0 }
  precondition(result is Bool)
}
func english() {
  precondition(active.allowedInputSourceLocales == ["en"])
  precondition(active.selectedKeyboardInputSource == "com.apple.keylayout.ABC")
}
func restored() {
  precondition(active.allowedInputSourceLocales == ["ko", "en"])
  precondition(active.selectedKeyboardInputSource == "com.apple.inputmethod.Korean.2SetKorean")
}
mode(true); english()
mode(true); mode(false); restored() // Repeated focus does not replace the snapshot.
mode(true); english()
window.isKeyWindow = false
NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: window)
restored()
mode(true); restored() // Inactive window cannot change the input context.
window.isKeyWindow = true
NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: window)
english()
NotificationCenter.default.post(name: NSWindow.willCloseNotification, object: window)
restored()
NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: window)
restored() // Closing clears the request, not just the current restriction.
mode(true); english(); mode(false); restored()
active.allowedInputSourceLocales = nil
mode(true); english(); mode(false)
precondition(active.allowedInputSourceLocales == nil)
print("Password input scope: focus, repeat, blur, activation, close and nil restoration passed")
'''

class PasswordInputScopeTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("swiftc"), "Swift compiler required")
    def test_production_scope_and_actual_appkit_types(self):
        source = (ROOT / "macos/Runner/MainFlutterWindow.swift").read_text()
        implementation = source.split("private final class DailyPasswordInputBridge {", 1)[1].split(
            "// The school browser uses a nonpersistent", 1
        )[0]
        implementation = "private final class DailyPasswordInputBridge {" + implementation
        with tempfile.TemporaryDirectory(prefix="daily-password-input-") as directory:
            directory = Path(directory)
            file = directory / "main.swift"
            file.write_text("import Foundation\n" + CHANNEL_STUBS + CONTEXT_STUBS + implementation + CHECKS)
            executable = directory / "scope-tests"
            result = subprocess.run(["swiftc", str(file), "-o", str(executable)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            result = subprocess.run([str(executable)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("restoration passed", result.stdout)
            # Compile against real AppKit; fake-context checks do not prove live IME behavior.
            file.write_text("import Cocoa\n" + CHANNEL_STUBS + implementation)
            result = subprocess.run(["swiftc", "-typecheck", str(file)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
