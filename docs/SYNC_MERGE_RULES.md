# Sync Merge Rules

Implemented in the shared Flutter sync layer for 3.5.0, September 16, 2026.
The existing Google Drive AppData
per-event v2 layout remains in use; no new sync server or periodic full polling
was added.

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
- Category removals retain field tombstones. Absent fields from an older device
  do not silently remove newer values. Same-time settings use device ID followed
  by canonical value as a deterministic tie-breaker.
- Old snapshots have unknown field mutation times. They migrate as an untimed
  baseline, never as an invented current-time edit. Historical ordering between
  conflicting legacy values cannot be recovered; later tracked mutations win.
- Account credentials, onboarding state, app-lock settings and app language keep
  their existing local-only behavior.

## Backup, Restore And Concurrency

- Backup uploads eligible local changes after comparing remote versions. It does
  not apply newer remote values to the local UI. A newer remote conflict remains
  pending and is reported as incomplete rather than successful.
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

Primary references: [Drive file metadata](https://developers.google.com/workspace/drive/api/reference/rest/v2/files)
and [conditional update endpoint](https://developers.google.com/workspace/drive/api/reference/rest/v2/files/update).

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
