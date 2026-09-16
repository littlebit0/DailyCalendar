# Issue 71: Startup Sync Gate

## Behavior

- Shared Flutter implementation for macOS, iOS, Android, Windows and Linux.
- A linked Google account waits at startup while stored credentials are
  restored non-interactively and Drive v2 changes are checked and merged.
- No linked Google account means no blocking sync gate. Existing legacy-session
  migration remains best-effort in the background.
- Startup checks/merges remote changes before flushing pending local changes.
  Retrying startup uses this same ordering, not the resume backup/delay path.
- Existing change tokens avoid downloading all events when nothing changed.
  The existing first-baseline restore remains necessary when no token exists.
- Persisted settings are loaded and initial month/week/day stream providers are
  ready before showing the calendar. There is no minimum loading duration.
- After an error or 20 seconds, offer Retry or Continue with data on this device.
  Continue neither signs out nor claims synchronization succeeded. It does not
  clear pending changes. An in-flight operation can finish in the background;
  retry joins it instead of duplicating it. Existing bounded retries remain.
- Resuming the app never reinstates this startup screen. Resume/background sync
  does not race the initial operation while it remains in flight.
- Session changes invalidate old sync results before applying downloaded data
  or marking uploads successful. The startup path also validates identity
  before starting the sync and before proceeding after it.
- App lock, consent/onboarding, database migration, manual backup/restore,
  per-event tombstones and existing merge conflict rules are preserved.
- The screen follows theme, text scale and KO/EN/JA/Traditional Chinese locale.

## Manual Acceptance

1. With a linked Google account, change events and categories on another device,
   then cold-start Daily. Verify updated calendar and sidebar content appears
   together after loading, without initially displaying the old calendar.
2. Restart without remote changes. Verify no artificial three-second wait and
   no full download; pending local edits should still back up safely.
3. Cold-start offline or with expired credentials. Verify an error choice is
   shown within 20 seconds, no Google login sheet opens automatically, Retry
   works after connectivity is restored, and Continue retains the account.
4. Continue with device data after timeout, then edit an event. Verify a late
   remote response does not overwrite the newer pending local edit. Switch
   accounts after Continue and verify old-account downloads are not applied.
5. Start with a local or Apple-only account. Verify the calendar is not blocked
   by this gate. Verify app-lock and database-migration flows still operate.
6. Background/resume while waiting and after entering the calendar. Verify no
   duplicated startup job and no second startup screen on resume.
7. Check light/dark mode, large text and all four languages on supported OSes.

## Delivery Boundary

Automated verification: 459 Flutter tests passed, 1 existing skip; analyze and
`git diff --check` passed.

Implementation and automated tests only in this change. No real-user account
GUI test, test-app installation, version bump, commit, push, release or issue
closure is performed. Native OS acceptance remains manual.
