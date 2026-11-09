# Daily 2.0.2 Release Notes

## Changes

- Google login and logout on Android and Windows do less blocking work.
- The connect flow no longer runs the initial restore and full sync twice.
- Login no longer backs up every local event. It starts the Google Drive
  listeners, uploads only pending local event changes, and then restores remote
  v2 data.
- Logout no longer runs a full sync. Before it clears account state, it tries
  to upload pending changes within what remains of the 10-second account-action
  budget.
- Android Google sign-out times out after 3 seconds. Mobile auth, desktop OAuth,
  desktop token and userinfo requests, and Google Drive requests time out after
  10 seconds or less.
- Google Drive event restore downloads now run in batches with limited
  concurrency.
- Pending-event upload finds the target remote files with one Drive query
  instead of one query per event.
- Android no longer opens the Google account chooser on its own at local
  startup.
- Daily flushes pending local v2 event changes on startup, background, and exit,
  so a delayed timer can no longer leave changes unsynced across app restarts.
- The Windows Flutter helper script quotes Java temp paths, so builds work from
  workspace paths that contain spaces.

## Verification

- `.\tool\flutter.ps1 analyze --no-pub`
- `.\tool\flutter.ps1 test --no-pub`
- Rebuilt the Android debug APK, reinstalled it on `emulator-5554`, and launched it.
- Rebuilt and launched the Windows debug build.

## Artifacts

- `daily-android-2.0.2.apk`: Android APK built from the 2.0.2 Windows/Android code.
- `daily-windows-2.0.2.zip`: Windows ZIP built from the 2.0.2 Windows/Android code.
- `daily-ios-2.0.1-unsigned.ipa`: the 2.0.1 file, carried over unchanged as requested.
- `daily-macos-2.0.1.dmg`: the 2.0.1 file, carried over unchanged as requested.
- `SHA256SUMS.txt`: SHA-256 checksums for the uploaded artifacts.
