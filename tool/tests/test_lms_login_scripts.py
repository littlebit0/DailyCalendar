"""Execute production authentication JS with controlled DOM/transport adapters.

This proves script branching and request restrictions, not a real WebView/login.
"""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class LmsLoginScriptTests(unittest.TestCase):
    def test_production_scripts_with_controlled_school_documents(self):
        node = shutil.which('node')
        self.assertIsNotNone(node, 'Node is required to execute production JS')
        source = (ROOT / 'lib/core/lms/lms_web_session.dart').read_text()
        scripts = {}
        for name in ('authenticationScript', 'automaticLoginScript'):
            match = re.search(r'static const ' + name + r"\s*=\s*r'''(.*?)''';", source, re.S)
            self.assertIsNotNone(match, name)
            scripts[name] = match.group(1)
        import json
        with tempfile.TemporaryDirectory(prefix='daily-lms-js-') as directory:
            script = Path(directory) / 'tests.cjs'
            script.write_text('const scripts = ' + json.dumps(scripts) + ';\n' +
                (ROOT / 'tool/tests/lms_login_scripts_test.cjs').read_text())
            result = subprocess.run([node, str(script)], check=True, capture_output=True, text=True)
            self.assertIn('LMS JS: 22 checks passed', result.stdout)


if __name__ == '__main__':
    unittest.main()
