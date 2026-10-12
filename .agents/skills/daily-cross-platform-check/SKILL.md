---
name: daily-cross-platform-check
description: Plan and execute risk-matched DailyCalendar Flutter and native checks across Android, iOS, macOS, Windows and Linux, distinguishing unit/widget tests, builds, installation and actual device flows.
---

# Daily cross-platform check

## Select targets from the change

Read root `AGENTS.md`, `pubspec.yaml`, `.github/workflows/platform-builds.yml`, and the applicable release workflow. Map shared code to every affected platform; native changes require checks on the actual supported host. Linux exists in this repository and must be included when its services/packaging or shared behavior are affected. Do not infer that a successful build validates another platform.

Record available SDKs/devices first with `bash tool/flutter.sh doctor -v` and, when needed, `bash tool/flutter.sh devices`. This does not authorize launch or login. macOS/Linux use the shell wrapper; Windows uses `.\tool\flutter.ps1`. Missing Java/SDK/signing/device prerequisites are explicit blockers, not permission to install unrelated tools or claim success.

## Commands and evidence levels

| Target | Existing command / entry point | What it establishes |
| --- | --- | --- |
| Shared Flutter | `bash tool/flutter.sh analyze --no-pub`, `bash tool/flutter.sh test --no-pub` | Static and Dart/widget behavior, not native device acceptance |
| Android on supported host | `bash tool/flutter.sh build apk --debug --no-pub` | Debug compilation; CI configures Java 17 |
| iOS on macOS | `bash tool/flutter.sh build ios --debug --simulator --no-pub` | Simulator build; no signed device/install proof |
| iOS release check on macOS | `bash tool/flutter.sh build ios --release --no-codesign --no-pub` | Unsigned compilation, matching `release-apple.yml`; no App Store submission proof |
| macOS | `bash tool/flutter.sh build macos --debug --no-pub` | Native debug build; wrapper may load local desktop OAuth configuration without printing it |
| Windows on Windows | `.\tool\flutter.ps1 build windows --debug --no-pub` | Windows compilation, matching the platform CI target |
| Linux on Linux | `bash tool/flutter.sh build linux --debug --no-pub`, `python3 -m unittest discover -s test/linux -v` | Linux build and packaging/reminder unit checks; no desktop acceptance |
| Apple LMS cookies | `python3 -m unittest discover -s tool/tests -p 'test_lms_cookie_read_policy.py' -v` | Production policy extraction/Swift checks; no live WebView/session coexistence |
| Siri LMS visibility | `python3 -m unittest discover -s tool/tests -p 'test_siri_lms_visibility.py' -v` | Native source visibility checks; no spoken Siri flow |

Run only the checks relevant to the task. Validate tooling versions against workflow files rather than upgrading opportunistically. Existing GitHub workflow files describe intended CI; confirm an actual run before saying remote CI passed.

## UI and native parity

- Responsive calendar entry point: `lib/core/theme/daily_ui.dart` and `lib/features/calendar/presentation/month_calendar_page.dart`. Current `dailyCalendarWideMinWidth` is 720 usable pixels; verify the source, not historical handoff values.
- `test/widget_test.dart` covers resizing without losing date/view and Android wide tablet navigation. For layout work start with `bash tool/flutter.sh test --no-pub test/widget_test.dart --plain-name 'resizes calendar navigation'`, then the relevant calendar/timetable widgets. Include portrait/landscape, width transitions, safe areas, large text, focus/IME, scrolling and accessibility when affected.
- Native channels/entitlements live under platform runners; widgets and Siri also have `apple_widgets/` and `apple_siri/` consumers. Account visibility, notification delivery and cookie behavior require their own native evidence.
- Authorized device smoke checks should follow the changed user flow (for example create → edit → recurrence → completion → relaunch, or login chooser → cancel → retry). Use isolated test data and preserve existing account/data boundaries. Real authentication and multi-device sync need separate explicit evidence.

## Installation and handoff

Follow root `AGENTS.md` for approved product implementation updates and preservation of installed test identity/data. Instruction-only skill/config changes do not call for a product rebuild/install. Inspect helpers before execution: `tool/run_macos.sh` replaces the test bundle, refreshes registration/services and launches the app; it is not a read-only build command and must not run merely to check compilation.

Report each affected platform as checked, failed, skipped or unavailable, with command/result and remaining acceptance step. Build, signature, install, launch, UI flow, upload and store processing are separate outcomes. Record relevant cross-platform handoff in `AGENT_MEMORY.md` without overwriting existing work. External iOS/Android plugins may assist native checks if installed, but these skills do not depend on them; see `docs/CODEX_SETUP.md` for the setup boundary.
