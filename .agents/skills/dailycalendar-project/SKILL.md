---
name: dailycalendar-project
description: Orient and implement DailyCalendar Flutter changes using its actual providers, services, persistence, and test tooling. Use for project onboarding or changes spanning features; use the focused Daily skills for LMS, auth, calendar integrity, or platform validation.
---

# DailyCalendar project

## Start from the working tree

- Work from the Git root; confirm `git remote -v` identifies `littlebit0/DailyCalendar` and inspect `git status --short` and the relevant `git diff`. Existing uncommitted LMS/native/test work may be intentional; do not reset or stage it as your own.
- Read `AGENTS.md` and the concise current handoff/index in `AGENT_MEMORY.md`; follow its detailed handoff links, and consult archived history only when relevant. Read `docs/AGENT_MEMORY_AUDIT_2026-09-24.md` when resolving historical claims. Dated releases, old absolute paths, and deleted experiments are evidence, not current instructions or runnable assets.
- Re-read `pubspec.yaml`, the affected source/tests, and `.github/workflows/platform-builds.yml` before selecting commands. Version and schema numbers below are orientation, not values to pin in future edits.

## Architecture map

This is the `daily` Flutter/Dart package, not a SwiftUI application. `lib/main.dart` initializes settings/analytics; `lib/app/daily_bootstrap.dart` handles startup migration and `lib/app/daily_app.dart` hosts the application; `lib/core/di/app_providers.dart` wires Riverpod providers and platform services.

| Concern | Start here |
| --- | --- |
| Month/week/day UI and responsive navigation | `lib/features/calendar/presentation/month_calendar_page.dart`, `lib/core/theme/daily_ui.dart` |
| Event writes and side effects | `lib/features/events/application/event_command_service.dart` |
| Drift/SQLite persistence | `lib/features/events/data/app_database.dart`, `drift_event_repository.dart`, `event_mapper.dart` in the same directory |
| Account filtering | `lib/features/events/data/owner_scoped_event_repository.dart`, `lib/core/di/app_providers.dart` |
| Settings and account metadata | `lib/core/settings/settings_repository.dart`, `lib/core/settings/app_settings.dart`, `lib/core/auth/` |
| Drive sync and authorization | `lib/core/sync/google_drive_sync_service.dart`, `lib/core/sync/google_drive_auth_service.dart` |
| School connection and data import | `lib/core/lms/`, `lib/features/settings/presentation/lms_login_page.dart`, `lms_settings_page.dart` in the same directory |
| Timetable, academic calendar, notifications, widgets | `lib/features/timetable/`, `lib/core/academic/`, `lib/core/notifications/`, `lib/core/widgets/` |
| Native bridges and extensions | `ios/Runner/`, `macos/Runner/`, `android/app/`, `windows/runner/`, `linux/runner/`, `apple_widgets/`, `apple_siri/` |

Trace UI → provider → service/command → repository/native bridge → resulting refresh before changing behavior. Use provider overrides, in-memory databases and injected fakes already present in `test/`. Preserve scheduling, widget refresh, owner checks and sync side effects when changing event writes.

## Repository tooling

Run commands from the repository root. macOS/Linux use `bash tool/flutter.sh`; Windows uses `.\tool\flutter.ps1`. The shell wrapper finds `FLUTTER_ROOT` or Flutter on PATH, configures `PUB_CACHE`, and may create the temporary build symlink. If using the existing package configuration, preserve its dependency cache; set `PUB_CACHE` only to an actual available cache. Do not embed one machine's SDK path in project instructions.

```bash
bash tool/flutter.sh --version
bash tool/flutter.sh test --no-pub test/core/sync/sync_merge_rules_test.dart
bash tool/flutter.sh analyze --no-pub
bash tool/flutter.sh test --no-pub
```

Use `--no-pub` with resolved dependencies; use `bash tool/flutter.sh pub get` when resolution is actually needed. CI currently uses Flutter 3.44.0; `pubspec.yaml` requires Dart ^3.11.5. Check these files again if tooling disagrees. Regenerate Drift output with `bash tool/flutter.sh pub run build_runner build --delete-conflicting-outputs` only for an approved schema/model change; inspect generated diffs and migration tests.

## Select additional guidance

Load only the relevant skill: `daily-lms-sync` for school parsing/import, `daily-auth-regression` for session/identity behavior, `daily-calendar-integrity` for event persistence/merge/date logic, `daily-cross-platform-check` for platform validation. Root `AGENTS.md` owns product, sync, release, installation and handoff rules; do not duplicate or relax them here.

Instruction-only changes require skill format/path/diff validation, not app installation. Product behavior changes require the relevant tests and the platform checks described in those skills. Report executed checks, blockers and untested acceptance flows separately.
