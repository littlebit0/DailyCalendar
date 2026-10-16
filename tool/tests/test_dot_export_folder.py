"""Execute the native export boundary with isolated files; no app or accounts."""
from pathlib import Path
import platform
import subprocess
import tempfile
import unittest


@unittest.skipUnless(platform.system() == 'Darwin', 'macOS native export policy')
class DotExportFolderTest(unittest.TestCase):
    def test_suspended_channel_rejects_every_method_without_starting_services(self):
        root = Path(__file__).resolve().parents[2]
        source = (root / 'macos/Runner/MainFlutterWindow.swift').read_text()
        registration = source.split('@MainActor\nprivate enum DailyDotIntegration {', 1)[1].split('\n@available(macOS 12.0, *)', 1)[0]
        program = """import Foundation
struct FlutterError { let code: String; let message: String?; let details: Any? }
struct Call { let method: String }
class Engine { let binaryMessenger = 0 }
class FlutterViewController { let engine = Engine() }
class FlutterMethodChannel {
  static var handler: ((Call, (Any?) -> Void) -> Void)?
  init(name: String, binaryMessenger: Int) {}
  func setMethodCallHandler(_ handler: @escaping (Call, (Any?) -> Void) -> Void) {
    Self.handler = handler
  }
}
enum DailyDotIntegration {
""" + registration + """
DailyDotIntegration.register(with: FlutterViewController())
for method in ["purchaseStatus", "purchase", "restorePurchases", "preparePlugin", "openPlugin", "setupStatus", "requestSetup", "openGoogle", "openDot", "unknown"] {
  var called = false
  FlutterMethodChannel.handler!(Call(method: method)) { value in
    assert((value as? FlutterError)?.code == "integration_disabled")
    called = true
  }
  assert(called)
}
print("All Dot channel methods rejected without purchase/export service initialization")
"""
        with tempfile.TemporaryDirectory(prefix='daily-dot-disabled-') as temp:
            swift = Path(temp) / 'disabled.swift'
            swift.write_text(program)
            result = subprocess.run(['swift', str(swift)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_private_reusable_directory_and_protected_paths(self):
        root = Path(__file__).resolve().parents[2]
        source = (root / 'macos/Runner/MainFlutterWindow.swift').read_text()
        method = source.split('  private func exportRoot(in directory: URL) throws -> URL {', 1)[1].split('\n  // A deep link', 1)[0]
        method = '  func exportRoot(in directory: URL) throws -> URL {' + method
        program = '''import Foundation
import Darwin
struct Policy {
  enum PurchaseError: Error { case protectedFolder }
''' + method + '''
}
let base = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let fm = FileManager.default
let policy = Policy()
let directory = try policy.exportRoot(in: base)
let reopened = try policy.exportRoot(in: base)
assert(reopened == directory)
let attrs = try fm.attributesOfItem(atPath: directory.path)
assert((attrs[.posixPermissions] as! NSNumber).intValue == 0o700)
assert((attrs[.ownerAccountID] as! NSNumber).uint32Value == getuid())
try fm.removeItem(at: directory)
let outside = base.appendingPathComponent("outside")
try fm.createDirectory(at: outside, withIntermediateDirectories: false)
try fm.createSymbolicLink(at: directory, withDestinationURL: outside)
do { _ = try policy.exportRoot(in: base); fatalError("symlink accepted") }
catch Policy.PurchaseError.protectedFolder {}
try fm.removeItem(at: directory)
try Data("keep".utf8).write(to: directory)
do { _ = try policy.exportRoot(in: base); fatalError("file accepted") }
catch Policy.PurchaseError.protectedFolder {}
let preserved = try String(contentsOf: directory, encoding: .utf8)
assert(preserved == "keep")
for path in ["Library/Containers", "Library/Containers/app", "Library/Group Containers/group"] {
  do { _ = try policy.exportRoot(in: base.appendingPathComponent(path)); fatalError("container accepted") }
  catch Policy.PurchaseError.protectedFolder {}
}
print("Export folder: create/reuse, private mode, owner, symlink, file and container boundaries passed")
'''
        with tempfile.TemporaryDirectory(prefix='daily-dot-export-') as temp:
            folder = Path(temp).resolve()
            swift = folder / 'policy.swift'
            swift.write_text(program)
            result = subprocess.run(['swift', str(swift), str(folder)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            print(result.stdout.strip())


if __name__ == '__main__':
    unittest.main()
