#!/usr/bin/env python3
"""Runs the tool/tests Python suites that no workflow step names on its own.

Run from the repository root on macOS (several suites compile Swift):

    python3 tool/run_tool_tests.py

Fails on a failure, an error, or a skipped test that is not listed in
ALLOWED_SKIPS: a skipped policy check must not look like a pass. It also fails
when a tool/tests/test_*.py file is covered by neither a workflow step, SUITES
nor EXCLUDED, so a new suite cannot be left out of CI unnoticed.
"""

import os
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Privacy and platform policy checks.
POLICY_SUITES = [
    "test_inappwebview_android_keep_rules",
    "test_ios_location_privacy",
    "test_lms_cookie_read_policy",
    "test_macos_test_host",
    "test_package_info_privacy_manifest",
    "test_password_input_scope",
    "test_shared_store_namespace",
    "test_siri_lms_visibility",
    "test_wallpaper_shortcut",
]

# University timetable import and fetch checks.
IMPORT_SUITES = [
    "test_dankook_import",
    "test_expanded_university_courses",
    "test_fetch_konkuk",
    "test_gachon_fetch",
    "test_hansung_import",
    "test_hknu_import",
    "test_hufs_fetch",
    "test_hufs_import",
    "test_import_chosun",
    "test_import_daegu_missing_rows",
    "test_import_konkuk",
    "test_import_mju",
    "test_import_pcu",
    "test_jnu_import",
    "test_kmu_import",
    "test_kookmin_import",
    "test_pnu_import",
    "test_sejong_import",
    "test_seoultech_import",
    "test_sungshin_import",
    "test_timetable_import",
    "test_tuk_import",
    "test_ulsan_view",
    "test_uos_import",
]

# Apple widget behaviour checks (compile Swift).
WIDGET_SUITES = [
    "test_widget_unreadable_snapshot",
    "test_widget_timeline_plan",
    "test_apple_widget_text",
]

# Apple native import checks (compile Swift).
APPLE_IMPORT_SUITES = [
    "test_ios_import_first_occurrences",
]

SUITES = POLICY_SUITES + IMPORT_SUITES + WIDGET_SUITES + APPLE_IMPORT_SUITES + ["test_run_tool_tests"]

# Suites that cannot run from a clean checkout, with the reason. Remove an
# entry (and add the suite above) once its input is available in CI.
EXCLUDED = {
    "test_kangwon_research_import": "reads work/university-research, which is not in the repository (#939)",
    "test_knu_import": "reads work/university-research, which is not in the repository (#939)",
    "test_yongin_import": "needs the pdfplumber package, which CI does not install",
}

# Tests that may skip in CI, with the reason.
ALLOWED_SKIPS = {
    # Needs a built app passed in DAILY_WALLPAPER_BUILT_APP.
    "test_wallpaper_shortcut.WallpaperShortcutTests.test_compiled_intents_match_workflow_and_include_signed_file",
}


def uncovered_suites(root, suites, excluded):
    workflows = "".join(
        path.read_text(encoding="utf-8")
        for path in sorted((root / ".github" / "workflows").glob("*.yml"))
    )
    return sorted(
        path.stem
        for path in (root / "tool" / "tests").glob("test_*.py")
        if path.stem not in suites
        and path.stem not in excluded
        and path.name not in workflows
    )


def run(root, suites, excluded, allowed_skips, stream=None):
    """Runs [suites] under root/tool/tests and returns the exit code."""
    tests = root / "tool" / "tests"
    problems = [
        f"{name}: not run by a workflow step, SUITES or EXCLUDED"
        for name in uncovered_suites(root, suites, excluded)
    ]
    problems += [
        f"{name}: listed but tool/tests/{name}.py does not exist"
        for name in [*suites, *excluded]
        if not (tests / f"{name}.py").is_file()
    ]

    # Same lookup as `python3 -m unittest discover -s tool/tests` from the root.
    os.chdir(root)
    sys.path[:0] = [str(tests), str(root)]
    suite = unittest.defaultTestLoader.loadTestsFromNames(suites)
    result = unittest.TextTestRunner(stream=stream, verbosity=2).run(suite)
    problems += [
        f"{test.id()}: skipped ({reason})"
        for test, reason in result.skipped
        if test.id() not in allowed_skips
    ]

    for name, reason in excluded.items():
        print(f"not run: {name}: {reason}", file=stream or sys.stdout)
    for problem in problems:
        print(f"error: {problem}", file=stream or sys.stderr)
    return 0 if result.wasSuccessful() and not problems else 1


if __name__ == "__main__":
    sys.exit(run(ROOT, SUITES, EXCLUDED, ALLOWED_SKIPS))
