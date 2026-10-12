---
name: daily-calendar-integrity
description: Preserve DailyCalendar event/date/recurrence correctness, Drift migrations, Drive merge and deletion integrity, or account-scoped calendar visibility when changing persistence and calendar logic.
---

# Daily calendar integrity

## Trace storage and effects

Read `lib/features/events/domain/calendar_event.dart`, `recurrence_rule.dart`, `event_deletion.dart` in that directory; `lib/features/events/data/app_database.dart`, `drift_event_repository.dart`, `event_mapper.dart`, `recurrence_expander.dart`; `lib/features/events/application/event_command_service.dart`; and the affected UI/provider.

For cloud changes also read `lib/core/sync/google_drive_sync_service.dart`, `sync_version.dart`, `settings_sync_document.dart` and `lib/core/settings/settings_repository.dart`. The production model has per-event `daily-sync-v2-event-{eventId}.json`, `daily-sync-v2-settings.json` and `daily-sync-v2-timetable.json`; legacy input handling is not permission to restore whole-file v1 sync.

## Integrity constraints

- `AppDatabase.currentSchemaVersion` is currently 9, with LMS metadata and owner-scoped deletion markers added after schema 8. Re-check source before migration work. Test upgrades with in-memory historical schemas; do not delete a user's database or reset secure storage to make an upgrade pass.
- Preserve `normalizeAllDayBounds` and date-only all-day serialization. Timed events and mutation comparisons use UTC instants. Check boundaries in `lib/core/time/korea_time.dart` and `lib/core/calendar/` rather than substituting the host timezone.
- `compareEventVersions` uses persisted change time, deterministic tie handling and deletion precedence; pending/synced status or upload time must not decide newer content. Equal-time LMS metadata must survive older-client input. `syncTimestampDetails` preserves timestamp precision but must reject stale fingerprints after native writes.
- Keep deletion tombstones/compact deletion ledger effective so an older remote event cannot resurrect a deletion. Compaction must respect the existing retention policy, owner filtering, recurrence until/count, and pending state.
- Preserve per-field settings merges and timetable synchronization; do not overwrite unrelated fields from a stale settings snapshot.
- Use commands and atomic repository operations appropriate to the flow; preserve notification/alarm cancellation and scheduling, Drive queueing, widget refresh and account ownership checks. Do not bypass these side effects with a raw UI database write.
- For recurrence, distinguish series changes from occurrence completion/exclusion. Preserve repeat bounds, stable occurrence identity, holiday/system/read-only restrictions, and LMS source-owned vs personal fields.
- Filter owner-scoped events/deletions consistently across calendar, search, widgets and Siri. Hidden cache is not deleted cache; auth expiry is not explicit disconnect.

## Verification by changed behavior

```bash
bash tool/flutter.sh test --no-pub test/features/events/app_database_migration_test.dart test/core/sync/sync_merge_rules_test.dart
bash tool/flutter.sh test --no-pub test/features/events/recurrence_expander_test.dart test/features/events/event_command_service_optimization_test.dart
bash tool/flutter.sh test --no-pub test/core/sync/google_drive_sync_service_test.dart test/core/sync/timetable_drive_sync_test.dart
bash tool/flutter.sh test --no-pub test/core/calendar_event_movement_test.dart test/core/calendar_event_span_test.dart test/core/calendar_event_ordering_test.dart test/features/calendar
```

Select relevant groups, then broaden to analysis/full tests for shared behavior per `AGENTS.md`. Add a meaningful regression case when changing these high-impact rules: date/UTC round trip, old-schema upgrade, offline edit vs deletion, deterministic merge, stale editor save, recurrence exclusion or owner switch. Existing injected/in-memory tests should not access production data or remote Drive.

When schema or sync format changes, use `daily-cross-platform-check` to examine older/native writers and platform parity. A local merge test does not establish real device convergence; report any missing two-device create/edit/delete/offline-resume acceptance separately.
