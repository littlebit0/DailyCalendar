# Daily 2.0.2 Release Notes

## Changes

- Reduced Google login/logout blocking work on Android and Windows.
- Removed duplicate initial restore/full-sync work from the connect flow.
- Login now starts Google Drive listeners, uploads only pending local event
  changes, then restores remote v2 data instead of backing up every local event.
- Logout no longer runs a full sync. It only attempts pending-change upload
  within the remaining 10-second account-action budget before clearing account
  state.
- Android Google sign-out is bounded at 3 seconds. Mobile auth, desktop OAuth,
  desktop token/userinfo requests, and Google Drive requests are bounded at 10
  seconds or less.
- Google Drive event restore downloads are batched with limited concurrency.
- Pending-event upload resolves target remote files with one Drive query instead
  of one query per event.
- Android local startup no longer opens the Google account chooser
  automatically.
- Pending local v2 event changes are flushed on startup/background/exit so a
  delayed timer cannot leave changes unsynced across app restarts.
- Windows Flutter helper script now quotes Java temp paths so builds work from
  workspace paths containing spaces.

## Verification

- `.\tool\flutter.ps1 analyze --no-pub`
- `.\tool\flutter.ps1 test --no-pub`
- Android debug APK rebuilt, reinstalled, and launched on `emulator-5554`.
- Windows debug build rebuilt and launched.

## Artifacts

- `daily-android-2.0.2.apk`: Android APK built from the 2.0.2 Windows/Android code.
- `daily-windows-2.0.2.zip`: Windows ZIP built from the 2.0.2 Windows/Android code.
- `daily-ios-2.0.1-unsigned.ipa`: carried over unchanged from 2.0.1 as requested.
- `daily-macos-2.0.1.dmg`: carried over unchanged from 2.0.1 as requested.
- `SHA256SUMS.txt`: SHA-256 checksums for the uploaded artifacts.
