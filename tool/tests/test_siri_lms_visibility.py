"""Run the production Swift visibility policy without app/account/Shortcut access."""

from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "apple_siri/DailySiriIntents.swift"


class SiriLmsVisibilityTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("swiftc"), "Swift compiler is required")
    def test_production_visibility_policy(self):
        source = SOURCE.read_text()
        policy = source.split("// BEGIN LMS VISIBILITY POLICY\n", 1)[1].split(
            "// END LMS VISIBILITY POLICY", 1
        )[0]
        with tempfile.TemporaryDirectory(prefix="daily-siri-lms-") as directory:
            directory = Path(directory)
            implementation = directory / "policy.swift"
            implementation.write_text("import Foundation\n" + policy)
            executable = directory / "policy-tests"
            subprocess.run(
                ["swiftc", "-parse-as-library", str(implementation),
                 str(ROOT / "tool/tests/siri_lms_visibility_test.swift"),
                 "-o", str(executable)],
                check=True, capture_output=True, text=True,
            )
            result = subprocess.run(
                [str(executable)], check=True, capture_output=True, text=True,
            )
            self.assertIn("23 checks passed", result.stdout)

    def test_all_native_read_and_mutation_entry_points_are_guarded(self):
        source = SOURCE.read_text()
        query = source.split("private static func query(", 1)[1].split(
            "private static func hasLmsMetadataColumn", 1
        )[0]
        self.assertIn("visibility.allows(id: id, metadata: metadata)", query)
        self.assertIn("visibility != lmsVisibility()", query)
        self.assertNotIn('sql += " LIMIT', query)
        self.assertIn('try hasLmsMetadataColumn(database) ? "lms_metadata" : "NULL"', query)
        self.assertEqual(source.count("WHERE id = ? AND id NOT LIKE 'lms:%'"), 2)
        self.assertEqual(source.count("try DailySiriDatabase.requireEditable(id: event.id)"), 4)
        self.assertIn('"AND lms_metadata IS NULL"', source)
        self.assertIn(
            'static func indexableEvents() throws -> [DailySiriEvent] {\n'
            '    try query(\n      whereClause: "deleted_at IS NULL",\n'
            '      bindings: []\n    ).filter { !$0.isLms }', source,
        )


if __name__ == "__main__":
    unittest.main()
