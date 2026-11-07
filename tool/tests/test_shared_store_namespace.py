"""App Store and test macOS builds must not share widget/Siri stores (#388)."""
from pathlib import Path
import json
import os
import re
import shutil
import subprocess
import tempfile
import unittest

from test_widget_occurrence_action import ROOT, shared_store_block

TEST_NAMESPACE = 'com.littlebit0.daily.test'


def build_configurations(pbxproj):
    return re.findall(r'isa = XCBuildConfiguration;.*?name = \w+;', pbxproj, re.S)


class SharedStoreConfigurationTest(unittest.TestCase):
    def test_each_macos_build_passes_its_namespace_to_app_and_widget(self):
        for plist in ('macos/Runner/Info.plist', 'apple_widgets/Info.plist'):
            text = (ROOT / plist).read_text()
            self.assertIn('<key>DailySharedStoreNamespace</key>\n\t<string>$(DAILY_SHARED_STORE_NAMESPACE)</string>', text, plist)
        pbxproj = (ROOT / 'macos/Runner.xcodeproj/project.pbxproj').read_text()
        configs = build_configurations(pbxproj)
        namespaced = {}
        for config in configs:
            bundle = re.search(r'PRODUCT_BUNDLE_IDENTIFIER = ([\w.]+);', config)
            if not bundle or 'RunnerTests' in bundle.group(1):
                continue
            namespace = re.search(r'DAILY_SHARED_STORE_NAMESPACE = ([\w.]+);', config)
            namespaced[bundle.group(1)] = namespace.group(1) if namespace else ''
        # Test app and its widget share one namespace; the App Store pair keeps the root.
        self.assertEqual(namespaced['com.littlebit0.daily.test'], TEST_NAMESPACE)
        self.assertEqual(namespaced['com.littlebit0.daily.test.widgets'], TEST_NAMESPACE)
        self.assertEqual(namespaced['com.littlebit0.daily.widgets'], '')
        for config in configs:
            if 'PRODUCT_BUNDLE_IDENTIFIER' not in config:
                self.assertNotIn('DAILY_SHARED_STORE_NAMESPACE', config)

    def test_every_app_group_path_and_signal_is_namespaced(self):
        for name in ('apple_widgets/DailyWidgets.swift', 'apple_siri/DailySiriIntents.swift', 'macos/Runner/MainFlutterWindow.swift'):
            text = (ROOT / name).read_text()
            calls = text.count('FileManager.default.containerURL(')
            wrapped = len(re.findall(r'(?:dailySharedStoreDirectory|DailySharedStore\.directory)\(FileManager\.default\.containerURL\(', text))
            self.assertGreater(calls, 0, name)
            self.assertEqual(calls, wrapped, name)
        widget = (ROOT / 'apple_widgets/DailyWidgets.swift').read_text()
        siri = (ROOT / 'apple_siri/DailySiriIntents.swift').read_text()
        app = (ROOT / 'macos/Runner/MainFlutterWindow.swift').read_text()
        self.assertIn('dailySharedStoreNotificationName(\n  "com.littlebit0.daily.widgetTodoActionsChanged"', widget)
        self.assertIn('DailySharedStore.notificationName("com.littlebit0.daily.widgetTodoActionsChanged")', app)
        self.assertIn('DailySharedStore.notificationName(\n    "com.littlebit0.daily.siri.events-changed"', siri)


class SharedStoreIsolationTest(unittest.TestCase):
    @unittest.skipUnless(shutil.which('swiftc'), 'Swift compiler required')
    def test_alternating_builds_keep_snapshots_and_queues_apart(self):
        widget = (ROOT / 'apple_widgets/DailyWidgets.swift').read_text()
        store = 'private enum DailyWidgetTodoActionStore {' + widget.split('private enum DailyWidgetTodoActionStore {', 1)[1].split('\n@available(iOS 17.0, macOS 14.0, *)\nstruct DailyToggleTodoIntent', 1)[0]
        store = store.replace('FileManager.default.containerURL(\n      forSecurityApplicationGroupIdentifier: appGroup\n    )', 'Optional(testDirectory)')
        store = store[:store.index('  private static func notifyApp()')] + '  private static func notifyApp() {}\n}\n'
        siri = (ROOT / 'apple_siri/DailySiriIntents.swift').read_text()
        lookup = '(Bundle.main.object(forInfoDictionaryKey: "DailySharedStoreNamespace") as? String)'
        siri_block = siri.split('// BEGIN DAILY SHARED STORE NAMESPACE', 1)[1].split('// END DAILY SHARED STORE NAMESPACE', 1)[0]
        self.assertIn(lookup, siri_block)
        siri_block = siri_block.replace(lookup, 'ProcessInfo.processInfo.environment["DAILY_TEST_NAMESPACE"]')
        app = (ROOT / 'macos/Runner/MainFlutterWindow.swift').read_text()
        app_store = '  private static func containerURL() throws -> URL {' + app.split('  private static func containerURL() throws -> URL {', 1)[1].split('\n}\n\nprivate final class DailySiriLogsBridge', 1)[0]
        app_store = app_store.replace('FileManager.default.containerURL(\n      forSecurityApplicationGroupIdentifier: appGroup\n    )', 'Optional(testDirectory)')
        harness = '''import Foundation
let testDirectory = URL(fileURLWithPath: CommandLine.arguments[1])
let snapshotFileName = "daily-widget-snapshot.json"
let todoActionsFileName = "daily-widget-todo-actions.json"
enum App {
%s
  static func publish(_ id: String) throws {
    try writeSnapshot(["todayEvents": [["id": id, "eventId": id, "completed": false]]])
  }
  static func acknowledgeAll() throws -> [String] {
    var ids: [String] = []
    try withTodoActionsLock(in: try containerURL()) {
      ids = try loadTodoActions().compactMap { $0["eventId"] as? String }
      try writeTodoActions([])
    }
    return ids
  }
}
switch CommandLine.arguments[2] {
case "publish": try App.publish(CommandLine.arguments[3])
case "complete": try DailyWidgetTodoActionStore.append(eventId: CommandLine.arguments[3], completed: true)
case "ack": print(try App.acknowledgeAll().joined(separator: ","))
default:
  print(DailySharedStore.notificationName("com.littlebit0.daily.widgetTodoActionsChanged"))
  print(dailySharedStoreNotificationName("com.littlebit0.daily.widgetTodoActionsChanged"))
}
''' % app_store
        with tempfile.TemporaryDirectory() as d:
            path = Path(d)
            (path / 'main.swift').write_text(harness.replace('import Foundation\n', 'import Foundation\n' + siri_block + shared_store_block(), 1) + store)
            compiled = subprocess.run(['swiftc', str(path / 'main.swift'), '-o', str(path / 'test')], capture_output=True, text=True)
            self.assertEqual(compiled.returncode, 0, compiled.stderr)
            group = path / 'group'
            group.mkdir()

            def run(namespace, *args):
                env = dict(os.environ, DAILY_TEST_NAMESPACE=namespace)
                result = subprocess.run([str(path / 'test'), str(group), *args], capture_output=True, text=True, env=env)
                self.assertEqual(result.returncode, 0, result.stderr)
                return result.stdout.strip()

            # Alternate the App Store ('') and test builds against one App Group.
            run('', 'publish', 'store-event')
            run(TEST_NAMESPACE, 'publish', 'test-event')
            run(TEST_NAMESPACE, 'complete', 'test-event')
            run('', 'complete', 'store-event')
            self.assertEqual(run('', 'ack'), 'store-event')
            self.assertEqual(run(TEST_NAMESPACE, 'ack'), 'test-event')

            def snapshot(directory):
                return json.loads((directory / 'daily-widget-snapshot.json').read_text())['todayEvents']

            self.assertEqual(snapshot(group), [{'id': 'store-event', 'eventId': 'store-event', 'completed': True}])
            self.assertEqual(snapshot(group / TEST_NAMESPACE), [{'id': 'test-event', 'eventId': 'test-event', 'completed': True}])
            self.assertTrue((group / TEST_NAMESPACE / 'daily-widget-todo-actions.lock').exists())
            store_names = run('', 'names').splitlines()
            test_names = run(TEST_NAMESPACE, 'names').splitlines()
            self.assertEqual(store_names, ['com.littlebit0.daily.widgetTodoActionsChanged'] * 2)
            self.assertEqual(test_names, [f'com.littlebit0.daily.widgetTodoActionsChanged.{TEST_NAMESPACE}'] * 2)


if __name__ == '__main__':
    unittest.main()
