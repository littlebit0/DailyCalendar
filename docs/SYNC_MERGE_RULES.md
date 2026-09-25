# Sync Merge Rules

Implemented in the shared Flutter sync layer for 3.5.0, September 16, 2026.
The existing Google Drive AppData
per-event v2 layout remains in use; no new sync server or periodic full polling
was added.

The timetable extension below describes unreleased #74/#75 working-tree code.
It is not part of the published 3.5.0 or 3.5.2 assets; the verification counts
later in this document remain the historical 3.5.0 results.

## Latest Mutation Wins

- Compare event IDs, not titles. The latest of `createdAt`, `updatedAt`, and
  `deletedAt`, interpreted as a UTC instant, decides the winning event snapshot.
  Upload time, file modification time and pending/synced status do not decide it.
- Same instant: deletion wins over a live event; otherwise a canonical persisted
  payload comparison gives every device the same result. Exact ties cannot tell
  which human action happened last. Same-event concurrent edits select one whole
  snapshot; unrelated event IDs merge independently.
- All-day bounds and recurrence date fields travel as calendar dates. Time-zone
  conversion does not shift all-day dates. Incorrect physical device clocks can
  still misorder changes; UTC normalizes zones, not inaccurate clocks.
- SQLite schema 8 preserves shared-layer mutation timestamp precision alongside
  existing second-resolution columns. Legacy/native writes invalidate stale
  precision through a payload fingerprint. Native Siri/widget writers retain
  their existing timestamp precision; they were not changed in this task.

## Settings Merge

- Scalar settings have separate mutation timestamps. Category name, color and
  other properties merge separately per category ID; category visibility and
  each date's manual event order are independent fields.
- A category-order list, or one date's complete manual order, is one field. Two
  concurrent changes to that same list do not interleave individual positions.
- The unreleased `academicProfile` field is one complete university/campus/degree
  group snapshot. Its institution/campus IDs, display name and campus never merge
  independently. An optional campusId distinguishes new grouped profiles from
  legacy profiles that stored the campus row ID as universityId. Legacy profiles
  remain readable and are not rewritten merely by loading the directory.
  An unset profile is absent from ordinary values; an explicit clear keeps a
  null LWW revision so older copies cannot restore it. Legacy settings without
  a profile do not erase a newer profile. Account credentials stay local.
  Account changes swap only this field and its offline cache/register/pending
  state. Leaving an account does not create a tombstone in the destination
  account; returning restores the exact previous revision. Other settings keep
  their existing device-wide behavior. Account-switch write failure rolls back
  account metadata, profile/cache and settings sync metadata together.
- Category removals retain field tombstones. Absent fields from an older device
  do not silently remove newer values. Same-time settings use device ID followed
  by canonical value as a deterministic tie-breaker.
- Old snapshots have unknown field mutation times. They migrate as an untimed
  baseline, never as an invented current-time edit. Historical ordering between
  conflicting legacy values cannot be recovered; later tracked mutations win.
- Account credentials, onboarding state, app-lock settings and app language keep
  their existing local-only behavior.

## Backup, Restore And Concurrency

- Event/settings backup uploads eligible local changes after comparing remote
  versions. It does not apply newer remote values to the local UI. A newer
  remote conflict remains pending and is reported as incomplete rather than
  successful.
- Restore downloads and merges; it does not require a preliminary backup. Newer
  local winners remain pending for the existing change/lifecycle backup queue.
- Startup restores/checks remote changes before flushing pending changes.
  Resume/manual sync keeps its backup, delay, change-check/restore sequence, then
  flushes any remaining winners. Failures retain persistent pending state and
  use bounded retries. Automatic work never requests an interactive login.
- Before updating an existing Drive file, read its content and the Drive v2 file
  metadata ETag/checksum. Match the checksum to the downloaded bytes, then use
  `If-Match` on a v2 media update. HTTP 412/404 triggers re-read/re-merge with a
  bounded attempt count. Missing version metadata fails closed. A media ETag is
  not substituted for the file ETag.
- The HTTP API version is distinct from Daily's v2 storage layout. New files use
  the existing v3 multipart creation path. Concurrent first creation can produce
  duplicate filenames; reads compare all copies and writes reconcile them.
- Signing out must not clear unsent local changes after a partial backup.
- Unreleased request pacing serializes event and duplicate-file loops, with a
  shared HTTP queue covering metadata/media/upload/deletion and migration reads.
  Each complete response is followed by a minimum 250 ms quiet interval. The
  10-second network budget excludes queue time and aborts the request on timeout.
  The backup-to-change-check interval is 3 seconds only when local changes
  were queued. Manual sync initializes/reuses the Drive change cursor instead of
  restoring the complete snapshot every time. Initial restoration retains the
  cursor-before-snapshot ordering. Remote winners already covered by the cursor
  are recovered by exact conflicting event IDs or the settings file, and refresh
  UI/widget snapshots. Bulk event work exposes completed/total progress.
- Drive 403 `rateLimitExceeded` and `userRateLimitExceeded` follow the bounded
  retry path, like 429; they no longer incorrectly request account reconnection.
  See [Drive error handling](https://developers.google.com/workspace/drive/api/guides/handle-errors).
- The startup UI deadline never establishes sync success or failure by itself.
  Slow work retains its original future, and only successful completion opens
  the calendar automatically. Actual failures show a safe category without raw
  API responses, account identifiers or exception text.

Primary references: [Drive file metadata](https://developers.google.com/workspace/drive/api/reference/rest/v2/files)
and [conditional update endpoint](https://developers.google.com/workspace/drive/api/reference/rest/v2/files/update).

## Timetable Extension (Unreleased #74/#75)

- Timetables use the separate AppData file `daily-sync-v2-timetable.json`:
  outer `schemaVersion: 2`, `type: timetable`, and an inner `document` with
  `schemaVersion: 1`. Existing event/settings files and SQLite schema 8 remain
  unchanged. `daily.timetable.v1` is the offline cache, not a local-only feature.
- All terms' classes, session exceptions, term names, and inclusive date periods
  sync through the linked Google account. Each class is one latest-mutation
  register; names and optional `termPeriods` are independent registers. Different
  classes merge independently; concurrent edits within one class select one
  complete snapshot, including its session exceptions.
- The selected term stays local to each device. Legacy `activeTerm` registers
  remain readable/preserved but never move the UI or receive new local selections.
  Verified official defaults seed only absent period registers as an untimed
  baseline, including after remote restore. Explicit edits and tombstones win.
- Compare UTC mutation time, then prefer deletion on an equal timestamp,
  followed by device ID and canonical JSON. Null values are retained deletion
  tombstones. Imported courses use source ID plus academic year/semester as
  their identity, preventing duplicate imports with different local UUIDs.
- Existing local timetables migrate as an untimed baseline and remain pending
  until acknowledged. Migration does not invent a current-time edit or discard
  the original data when validation fails. Offline changes persist for retry.
- Startup/restore and the Drive change feed include timetables. Each linked
  session bootstraps the timetable even if a saved older-client change token
  produces an empty feed. Local timetable edits join the existing debounced
  sync queue; there is no new idle polling or interactive automatic login.
- Backup merges all same-name remote copies and uses the existing checksum,
  ETag/`If-Match`, and bounded retry protections. Acknowledging an uploaded
  snapshot merges it into the local timetable without clearing a later local
  edit. Restore also merges remote winners into the local timetable.
- Account/session changes invalidate in-flight apply/acknowledgement work.
  Unsent timetable changes participate in the incomplete-backup/sign-out check.
  Corrupt or unsupported remote documents fail without replacing local data.

See [Timetable](TIMETABLE.md) for the UI and data model. Current tests and
installation evidence are recorded in `AGENT_MEMORY.md`; component/HTTP tests
do not establish live Google Drive or cross-device acceptance.

## Deleted Event Retention

- Never purge an undeleted event just because it is in the past.
- Compact only user-deleted events after their last planned date has passed.
  Multi-day events use their exclusive end bound; finite recurrence respects its
  count/until limit. An unbounded recurrence remains a full deletion tombstone.
  Excluded final occurrences may conservatively delay cleanup, never advance it.
- Replace an eligible event body with an ID and deletion timestamp in the local
  deletion ledger and the corresponding Drive event file. Minimal markers remain
  to block stale devices from resurrecting deleted events. More recent edits
  still follow the same latest-mutation rule.
- Cleanup covers current event rows/files, not existing safety snapshots or
  historical Drive revisions. It is not a promise to erase all backup history.

## Migration And Compatibility

- Pre-open migration downloads remote winners, creates a consistent snapshot of
  the original local DB, then merges/migrates a separate working copy. It validates
  before replacing the original. Failed conversion leaves the original intact;
  failed post-migration backup leaves changes pending.
- All devices participating in this account must be updated before exercising
  compact deletion records and field-level settings. Older clients do not know
  the compact record format and can ignore the new conflict protections.
- Shared Windows/Linux code is included; their native builds/installation are
  not verified on this Mac. Do not publish this schema-changing release for only
  one platform family. The 3.5.0 release workflow stages all platform families
  before public release.

## Verification And User Checks

Automated tests cover actual SQLite migration/precision/compaction, deterministic
ties, time zones, independent settings edits, stale copies, duplicate filenames,
conditional-write retries, checksum mismatch, partial failures and auth behavior.
Drive concurrency tests use an HTTP fake, not the user's live Drive account.
Test-app installation is not permission to launch or interactively exercise apps.
Final verification: 548 tests passed, one pre-existing skip; static analysis and
diff whitespace checks passed. iPhone 17 simulator, Mac Daily Test and Android
Pixel 9 emulator were updated in place without launch; DB/preferences hashes
were unchanged and installed artifact hashes matched their fresh builds.

After updating all participating devices, use a separate test account or a safe
backup to check:

1. Edit one test event on two devices; the later edit wins regardless of upload
   order. Different test event edits both survive.
2. Change a category name on one device and its color on another; both survive.
   Check category order and per-date manual order as well.
3. Delete a past test event and reconnect a stale device; it must not reappear.
   Undeleted past events, future deleted events and multi-day limits stay intact.
4. Work offline, reconnect, and verify retry/pending states. Backup must not claim
   success for a conflict, and restore must not require backup first.
