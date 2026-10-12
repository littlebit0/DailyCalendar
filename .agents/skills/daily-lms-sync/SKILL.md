---
name: daily-lms-sync
description: Implement or investigate DailyCalendar Coursemos parsing, LMS import, cache visibility, or refresh scheduling. Use for school data synchronization; use daily-auth-regression for login/session changes and honor an authentication-only investigation scope.
---

# Daily LMS sync

## Trace the import

Read `lib/core/lms/lms_controller.dart`, `lms_sync_service.dart`, `lms_models.dart`, `coursemos_parser.dart`, and `coursemos_learning_parser.dart` in that directory. Follow provider wiring in `lib/core/di/app_providers.dart` and import operations in `lib/features/events/application/event_command_service.dart`. Inspect the corresponding tests and `test/fixtures/coursemos/` before changing parsers.

- `LmsController` owns lifecycle, active Google owner/school/principal, generation invalidation, session restoration and queued refreshes. Reading the controller must not itself start a browser/network request.
- `LmsSyncService` performs paced reads, parses snapshots and applies local changes through commands. Its current refresh interval is five minutes and request spacing 400ms; verify constants before changing scheduling. LMS foreground refresh is distinct from Drive sync; the ban on idle Drive whole-file polling is not a reason to remove LMS refresh.
- Current enabled adapter is `smu` with origin `https://ecampus.smu.ac.kr`; course catalogs or academic sources for other schools do not establish LMS support.

## Import invariants

1. Keep `LmsSyncSession.sameAs`, generation/epoch checks and normalized Google owner checks around asynchronous reads and mutations. Results from a retired owner/principal must not update the new account.
2. `eventId` hashes provider, school, owner, principal, course, activity type and activity ID. Preserve stable IDs, idempotent imports, and LMS metadata through SQLite/Drive round trips.
3. Read the complete dashboard and assignment/quiz indexes before mutation. Login forms, redirects, unexpected origins, malformed or partial pages and failed writes are not empty successful snapshots.
4. Prune only the current owner's assignment/quiz records covered by a verified complete snapshot. Lecture/learning-report absence is not deletion evidence. Preserve unresolved/excluded/failed learning coverage reporting; do not fabricate dates or completion for ambiguous rows.
5. Preserve personal editor fields while refreshing source-owned titles/deadlines/status. Follow existing atomic LMS merge methods rather than replacing whole events from stale UI state.
6. Authentication loss invalidates fresh reads, not the owner's cache lifetime. Keep `isCachedEventVisible` school/principal/owner filtering consistent with `lms_event_status.dart`, `calendar_widget_service.dart`, and Siri. Explicit disconnect behavior must be traced separately from network failure or expiry.
7. Credentials/cookies remain device-local secure material; Drive-restored LMS events/settings do not prove another device can authenticate. No passwords, cookies or tokens in fixtures, Drive documents, diagnostics or handoff notes.

For login/renewal changes load `daily-auth-regression`. If the request is authentication-only, stay within issuance, reissuance, expiry, renewal and browser/device coexistence; do not expand into course/calendar reads to collect evidence.

## Verification

```bash
bash tool/flutter.sh test --no-pub test/core/lms
bash tool/flutter.sh test --no-pub test/features/settings/lms_settings_page_test.dart test/core/widgets/calendar_widget_service_test.dart test/core/sync/timetable_drive_sync_test.dart
```

Use existing HTML fixtures and injected fetch/session/clock/wait fakes. Cover repeated import, fully empty valid indexes, partial/error responses, learning coverage, stale in-flight work after account change, cache visibility, and source/personal-field preservation as relevant to the change. Use `daily-calendar-integrity` if changing serialization or deletion rules.

Live school acceptance is a separate authorized check: report actual imported records, refresh success time and platform. Cached display or mocked HTTP success does not prove live sync, continuous authentication, or multi-device operation.
