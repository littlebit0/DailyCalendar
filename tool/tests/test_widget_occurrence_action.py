"""Production Apple widget queue and optimistic update, in a temporary container."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
ROOT = Path(__file__).resolve().parents[2]

class WidgetOccurrenceActionTest(unittest.TestCase):
    @unittest.skipUnless(shutil.which('swiftc'), 'Swift compiler required')
    def test_selected_occurrence_only(self):
        source = (ROOT / 'apple_widgets/DailyWidgets.swift').read_text()
        store = source.split('private enum DailyWidgetTodoActionStore {', 1)[1].split('\n@available(iOS 17.0, macOS 14.0, *)\nstruct DailyToggleTodoIntent', 1)[0]
        store = 'private enum DailyWidgetTodoActionStore {' + store
        store = store.replace('FileManager.default.containerURL(\n      forSecurityApplicationGroupIdentifier: appGroup\n    )', 'Optional(testDirectory)')
        store = store[:store.index('  private static func notifyApp()')] + '  private static func notifyApp() {}\n}\n'
        harness = '''import Foundation
let testDirectory = URL(fileURLWithPath: CommandLine.arguments[1])
let snapshotFileName = "snapshot.json"
let todoActionsFileName = "actions.json"
let first = "series@2026-10-15T09:00:00.000"
let second = "series@2026-10-16T09:00:00.000"
let rows: [[String: Any]] = [first, second].map { ["id": $0, "eventId": "series", "completed": false] }
let url = testDirectory.appendingPathComponent(snapshotFileName)
try JSONSerialization.data(withJSONObject: ["todayEvents": rows, "scheduleEvents": rows]).write(to: url)
try DailyWidgetTodoActionStore.append(eventId: "series", completed: true, occurrenceId: first)
let snapshot = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
let events = snapshot["todayEvents"] as! [[String: Any]]
assert(events[0]["completed"] as? Bool == true)
assert(events[1]["completed"] as? Bool == false)
let actions = try JSONSerialization.jsonObject(with: Data(contentsOf: testDirectory.appendingPathComponent(todoActionsFileName))) as! [[String: Any]]
assert(actions[0]["eventId"] as? String == "series")
assert(actions[0]["occurrenceId"] as? String == first)
try DailyWidgetTodoActionStore.append(eventId: "series", completed: false, occurrenceId: first)
let undone = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
assert((undone["todayEvents"] as! [[String: Any]])[0]["completed"] as? Bool == false)
print("widget occurrence checks passed")
'''
        with tempfile.TemporaryDirectory() as d:
            path = Path(d)
            (path / 'main.swift').write_text(harness + store)
            compiled = subprocess.run(['swiftc', str(path / 'main.swift'), '-o', str(path / 'test')], capture_output=True, text=True)
            self.assertEqual(compiled.returncode, 0, compiled.stderr)
            result = subprocess.run([str(path / 'test'), d], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('widget occurrence checks passed', result.stdout)


class WidgetQueueConcurrencyTest(unittest.TestCase):
    @unittest.skipUnless(shutil.which('swiftc'), 'Swift compiler required')
    def test_acknowledge_never_drops_concurrent_appends(self):
        widget = (ROOT / 'apple_widgets/DailyWidgets.swift').read_text()
        store = 'private enum DailyWidgetTodoActionStore {' + widget.split('private enum DailyWidgetTodoActionStore {', 1)[1].split('\n@available(iOS 17.0, macOS 14.0, *)\nstruct DailyToggleTodoIntent', 1)[0]
        store = store.replace('FileManager.default.containerURL(\n      forSecurityApplicationGroupIdentifier: appGroup\n    )', 'Optional(testDirectory)')
        store = store[:store.index('  private static func notifyApp()')] + '  private static func notifyApp() {}\n}\n'
        # The production app-side lock/read/write helpers (iOS and macOS share them).
        app = {}
        for name, marker_end in (('ios/Runner/AppDelegate.swift', '\n}\n\nprivate final class DailySiriLogsBridge'),
                                 ('macos/Runner/MainFlutterWindow.swift', '\n}\n\nprivate final class DailySiriLogsBridge')):
            text = (ROOT / name).read_text()
            body = text.split('  /// Serializes read-modify-write', 1)[1].split(marker_end, 1)[0]
            app[name] = '  /// Serializes read-modify-write' + body
        harness = '''import Foundation
let testDirectory = URL(fileURLWithPath: CommandLine.arguments[1])
let snapshotFileName = "snapshot.json"
let todoActionsFileName = "actions.json"
enum AppAck {
  static func containerURL() throws -> URL { testDirectory }
%s
  static func acknowledgeAll() throws -> [String] {
    var acknowledged: [String] = []
    try withTodoActionsLock(in: try containerURL()) {
      let current = try loadTodoActions()
      acknowledged = current.compactMap { $0["token"] as? String }
      try writeTodoActions([])
    }
    return acknowledged
  }
}
let mode = CommandLine.arguments[2]
if mode == "append" {
  for _ in 0..<40 {
    try DailyWidgetTodoActionStore.append(eventId: "e", completed: true)
  }
} else {
  var acknowledged: [String] = []
  for _ in 0..<400 {
    acknowledged += try AppAck.acknowledgeAll()
    usleep(2000)
  }
  print(acknowledged.joined(separator: ","))
}
''' % app['ios/Runner/AppDelegate.swift']
        with tempfile.TemporaryDirectory() as d:
            path = Path(d)
            (path / 'main.swift').write_text(harness + store)
            compiled = subprocess.run(['swiftc', str(path / 'main.swift'), '-o', str(path / 'test')], capture_output=True, text=True)
            self.assertEqual(compiled.returncode, 0, compiled.stderr)
            work = path / 'container'
            work.mkdir()
            acker = subprocess.Popen([str(path / 'test'), str(work), 'ack'], stdout=subprocess.PIPE, text=True)
            appenders = [subprocess.Popen([str(path / 'test'), str(work), 'append']) for _ in range(4)]
            for process in appenders:
                self.assertEqual(process.wait(timeout=120), 0)
            out, _ = acker.communicate(timeout=120)
            self.assertEqual(acker.returncode, 0)
            acknowledged = [t for t in out.strip().split(',') if t]
            import json
            remaining = [a['token'] for a in json.loads((work / 'actions.json').read_text() or '[]')] if (work / 'actions.json').exists() else []
            # 4 appenders x 40 requests; every one is either processed or still queued once.
            self.assertEqual(len(acknowledged) + len(remaining), 160)
            self.assertEqual(len(set(acknowledged) | set(remaining)), 160)

    @unittest.skipUnless(shutil.which('swiftc'), 'Swift compiler required')
    def test_unreadable_queue_is_set_aside_not_erased(self):
        widget = (ROOT / 'apple_widgets/DailyWidgets.swift').read_text()
        store = 'private enum DailyWidgetTodoActionStore {' + widget.split('private enum DailyWidgetTodoActionStore {', 1)[1].split('\n@available(iOS 17.0, macOS 14.0, *)\nstruct DailyToggleTodoIntent', 1)[0]
        store = store.replace('FileManager.default.containerURL(\n      forSecurityApplicationGroupIdentifier: appGroup\n    )', 'Optional(testDirectory)')
        store = store[:store.index('  private static func notifyApp()')] + '  private static func notifyApp() {}\n}\n'
        harness = '''import Foundation
let testDirectory = URL(fileURLWithPath: CommandLine.arguments[1])
let snapshotFileName = "snapshot.json"
let todoActionsFileName = "actions.json"
try DailyWidgetTodoActionStore.append(eventId: "e", completed: true)
print("done")
'''
        with tempfile.TemporaryDirectory() as d:
            path = Path(d)
            (path / 'main.swift').write_text(harness + store)
            compiled = subprocess.run(['swiftc', str(path / 'main.swift'), '-o', str(path / 'test')], capture_output=True, text=True)
            self.assertEqual(compiled.returncode, 0, compiled.stderr)
            work = path / 'container'
            work.mkdir()
            (work / 'actions.json').write_text('{not json')
            result = subprocess.run([str(path / 'test'), str(work)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            kept = list(work.glob('daily-widget-todo-actions.corrupt-*.json'))
            self.assertEqual(len(kept), 1)
            self.assertEqual(kept[0].read_text(), '{not json')
