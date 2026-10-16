"""Exercise production voice bridge with delayed OS callbacks, without a microphone."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]

class SignalVoiceLifecycleTest(unittest.TestCase):
    @unittest.skipUnless(shutil.which('swiftc'), 'Swift compiler required')
    def test_production_bridge(self):
        source = (ROOT / 'apple_siri/DailySiriIntents.swift').read_text()
        bridge = source.split('final class DailySignalVoiceBridge: NSObject {', 1)[1].split('  private func runSignal(', 1)[0]
        bridge = 'final class DailySignalVoiceBridge: NSObject {' + bridge
        bridge += '''
          private func runSignal(command: String, confirmed: Bool, result: @escaping FlutterResult) {}
          private func speak(_ message: String) {}
        }
        '''
        with tempfile.TemporaryDirectory() as d:
            main = Path(d) / 'main.swift'
            main.write_text((ROOT / 'tool/tests/signal_voice_lifecycle_test.swift').read_text() + '\n' + bridge)
            executable = Path(d) / 'test'
            compiled = subprocess.run(['swiftc', str(main), '-o', str(executable)], capture_output=True, text=True)
            self.assertEqual(compiled.returncode, 0, compiled.stderr)
            result = subprocess.run([str(executable)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('voice lifecycle checks passed', result.stdout)
