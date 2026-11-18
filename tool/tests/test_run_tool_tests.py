"""The CI runner must fail on anything that would hide a missing check."""

import importlib.util
import io
import os
import sys
import tempfile
import unittest
from pathlib import Path

_spec = importlib.util.spec_from_file_location(
    "run_tool_tests", Path(__file__).resolve().parents[1] / "run_tool_tests.py"
)
runner = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(runner)

PASSING = "def test_ok(self): pass"
SKIPPED = "@unittest.skip('no compiler')\n    def test_skipped(self): pass"
FAILING = "def test_fails(self): self.fail('broken')"
ERRORING = "def test_errors(self): raise RuntimeError('broken')"


class RunToolTestsTest(unittest.TestCase):
    count = 0

    def setUp(self):
        self._cwd = os.getcwd()
        self._path = list(sys.path)
        self._directory = tempfile.TemporaryDirectory()
        self.root = Path(self._directory.name).resolve()
        (self.root / "tool" / "tests").mkdir(parents=True)
        (self.root / ".github" / "workflows").mkdir(parents=True)

    def tearDown(self):
        os.chdir(self._cwd)
        sys.path[:] = self._path
        self._directory.cleanup()

    def suite(self, body):
        """Writes a suite under a name no other test has imported."""
        RunToolTestsTest.count += 1
        name = f"test_runner_fixture_{RunToolTestsTest.count}"
        (self.root / "tool" / "tests" / f"{name}.py").write_text(
            f"import unittest\n\nclass Fixture(unittest.TestCase):\n    {body}\n",
            encoding="utf-8",
        )
        return name

    def run_ci(self, suites, excluded=None, allowed_skips=()):
        self.output = io.StringIO()
        return runner.run(
            self.root, suites, excluded or {}, set(allowed_skips), self.output
        )

    def test_passing_suites_succeed(self):
        self.assertEqual(self.run_ci([self.suite(PASSING)]), 0)

    def test_a_failure_or_error_fails(self):
        for body in (FAILING, ERRORING):
            with self.subTest(body=body):
                self.assertEqual(self.run_ci([self.suite(body)]), 1)

    def test_an_unexpected_skip_fails(self):
        name = self.suite(SKIPPED)
        self.assertEqual(self.run_ci([name]), 1)
        self.assertIn(
            f"error: {name}.Fixture.test_skipped: skipped (no compiler)",
            self.output.getvalue(),
        )

    def test_an_allowed_skip_succeeds(self):
        name = self.suite(SKIPPED)
        self.assertEqual(
            self.run_ci([name], allowed_skips=[f"{name}.Fixture.test_skipped"]), 0
        )

    def test_a_suite_nothing_runs_fails(self):
        left_out = self.suite(PASSING)
        self.assertEqual(self.run_ci([self.suite(PASSING)]), 1)
        self.assertIn(f"error: {left_out}: not run", self.output.getvalue())

    def test_a_suite_named_by_a_workflow_or_excluded_is_accepted(self):
        in_workflow = self.suite(PASSING)
        excluded = self.suite(FAILING)
        (self.root / ".github" / "workflows" / "ci.yml").write_text(
            f"run: python3 -m unittest discover -s tool/tests -p {in_workflow}.py\n",
            encoding="utf-8",
        )
        self.assertEqual(
            self.run_ci([self.suite(PASSING)], excluded={excluded: "no input"}), 0
        )
        self.assertIn(f"not run: {excluded}: no input", self.output.getvalue())

    def test_a_listed_suite_without_a_file_fails(self):
        self.assertEqual(
            self.run_ci([self.suite(PASSING)], excluded={"test_gone": "removed"}), 1
        )
        self.assertIn("error: test_gone: listed but", self.output.getvalue())

    def test_the_real_lists_cover_every_suite_in_the_repository(self):
        self.assertEqual(
            runner.uncovered_suites(runner.ROOT, runner.SUITES, runner.EXCLUDED), []
        )
        for name in [*runner.SUITES, *runner.EXCLUDED]:
            self.assertTrue(
                (runner.ROOT / "tool" / "tests" / f"{name}.py").is_file(), name
            )


if __name__ == "__main__":
    unittest.main()
