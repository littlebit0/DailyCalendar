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
