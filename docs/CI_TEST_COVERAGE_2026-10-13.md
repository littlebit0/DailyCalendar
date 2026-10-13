# Reactivated UI and Apple LMS CI coverage — 2026-10-13

Only tests and CI configuration change. No product/native/source assets, academic support, installed app or accounts change. University support work remains stopped.

## Formerly skipped weekly-shell test

Removed unconditional skip:true. Kept initial weekly shell, period header bounds/fitted text, visible navigation/Siri/today controls, surface shape/border, selected marker bounds/position, compact/expanded dimensions, repeated-selection animation stability, gesture selection of quick view, header stability during transition, return to weekly calendar, horizontal swipe advancing seven days, and inline AI panel visibility/calendar-space reduction/header stability. Added close restoring calendar space.

Current mobile UI merges the old separate slider and two-mode toggle into one six-segment bar. Compact281.6x42 and expanded320x50 replace obsolete124x40/152x48 and separate-slider assumptions. Current rounded bordered surface intentionally clips inside its track; verify contained selection geometry instead of asserting old Clip.none/no-border. Siri uses graphic_eq_rounded. Removed reserved-header key no longer exists; actual header and period-button bounds remain checked. Closed AI AnimatedSize remains present at height0; its input is removed. Product behavior was traced from month_calendar_page.dart, not changed to fit tests.

## Mac CI

Added independent macos-latest Apple LMS session test job with Flutter3.44.0. It runs the entire existing LMS session file and checks JSON events:all40 cases complete successfully, no skipped cases, successful final suite event. This includes all32 Apple-specific cases skipped by Ubuntu. Results JSON uploaded even on failure. Linux full suite, Android and Windows build jobs remain unchanged. Mocked session-policy tests do not establish actual login/native WebView/multi-device acceptance.

## Verification

Independent HEAD checkout with only task changes: updated weekly test1pass; existing six-segment test1pass; full LMS file40pass/0skip with identical CI JSON guard; updated-test analysis clean. Initial updated-test failures were obsolete icon/dimension/closed-wrapper expectations; corrected only this test and reverified it. Normal push CI final result pending; authoritative run and final receipt will be saved under work/ci-skip-reactivation-20261013. Do not treat local checks as remote CI success.
