"""Release gate: only a tag whose newest Platform Builds run succeeded passes."""

import json
import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "require_platform_builds.sh"

# Stands in for `gh api <url> --jq <filter>`: answers from files, and fails
# like an API error when the file for the request is missing.
FAKE_GH = """#!/usr/bin/env bash
set -euo pipefail
case "$2" in
  */commits/tags/*) file="$FAKE_GH_DIR/commit.json" ;;
  */actions/workflows/platform-builds.yml/runs\\?head_sha=abc123*) file="$FAKE_GH_DIR/runs.json" ;;
  *) echo "unexpected request: $2" >&2; exit 2 ;;
esac
[[ -f "$file" ]] || { echo "gh: HTTP 500" >&2; exit 1; }
jq -r "$4" "$file"
"""


def run(number, status, conclusion):
    return {
        "run_number": number,
        "status": status,
        "conclusion": conclusion,
        "html_url": f"https://example.invalid/runs/{number}",
    }


class RequirePlatformBuildsTest(unittest.TestCase):
    def gate(self, runs, commit={"sha": "abc123"}):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            gh = root / "gh"
            gh.write_text(FAKE_GH, encoding="utf-8")
            gh.chmod(gh.stat().st_mode | stat.S_IXUSR)
            if commit is not None:
                (root / "commit.json").write_text(json.dumps(commit))
            if runs is not None:
                (root / "runs.json").write_text(json.dumps({"workflow_runs": runs}))
            return subprocess.run(
                ["bash", str(SCRIPT), "owner/repo", "v1.2.3"],
                env={
                    **os.environ,
                    "PATH": f"{root}{os.pathsep}{os.environ['PATH']}",
                    "FAKE_GH_DIR": str(root),
                },
                capture_output=True,
                text=True,
            )

    def assert_blocked(self, result, text):
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn(text, result.stderr)

    def test_a_successful_run_passes(self):
        result = self.gate([run(7, "completed", "success")])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("passed for v1.2.3 (abc123)", result.stdout)

    def test_a_rerun_that_succeeds_replaces_an_earlier_failure(self):
        result = self.gate(
            [run(9, "completed", "success"), run(8, "completed", "failure")]
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_an_older_success_does_not_override_a_newer_failure(self):
        result = self.gate(
            [run(8, "completed", "success"), run(9, "completed", "failure")]
        )
        self.assert_blocked(result, "'completed/failure'")
        self.assertIn("runs/9", result.stderr)

    def test_unfinished_and_unsuccessful_runs_block(self):
        for status, conclusion in [
            ("queued", None),
            ("in_progress", None),
            ("completed", "cancelled"),
            ("completed", "failure"),
            ("completed", "timed_out"),
            ("completed", "skipped"),
        ]:
            with self.subTest(status=status, conclusion=conclusion):
                result = self.gate(
                    [run(8, "completed", "success"), run(9, status, conclusion)]
                )
                self.assert_blocked(result, f"'{status}/{conclusion or 'null'}'")

    def test_a_tag_without_runs_blocks_and_says_how_to_run_one(self):
        result = self.gate([])
        self.assert_blocked(result, "No Platform Builds run exists for v1.2.3")
        self.assertIn("Run workflow", result.stderr)

    def test_api_errors_block(self):
        self.assertNotEqual(self.gate(None).returncode, 0)
        self.assertNotEqual(
            self.gate([run(7, "completed", "success")], commit=None).returncode, 0
        )

    def test_an_unresolved_tag_blocks(self):
        result = self.gate([run(7, "completed", "success")], commit={})
        self.assertNotEqual(result.returncode, 0, result.stdout)


if __name__ == "__main__":
    unittest.main()
