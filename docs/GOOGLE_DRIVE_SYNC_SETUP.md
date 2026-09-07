# Google Drive Sync Setup

Current release baseline: `3.0.1`. iOS and macOS use the shared app bundle ID
`com.littlebit0.daily`; their widget extensions use
`com.littlebit0.daily.widgets`.

This setup must be done in stages. Do not skip the Google Cloud/OAuth stage;
the app can build without it, but Google Drive connection will not complete
correctly until OAuth clients and scopes are configured.

## Stage 1: Implemented in the app

- Sync provider was switched from Firebase sync to Google Drive AppData sync.
- The app no longer uses the legacy `daily-sync-v1.json` whole-database
  snapshot. Version 2 stores one JSON file per event in the user's Google Drive
  `appDataFolder`.
- Event files are named `daily-sync-v2-event-{eventId}.json`. Non-secret app
  settings are stored separately in `daily-sync-v2-settings.json`.
- Local events and remote events are merged by event ID and the newest
  `updatedAt` or `deletedAt` timestamp.
- Deleted events are retained as tombstones so deletion can sync to other
  devices.
- Settings now has a Google Drive sync section with connect, manual sync, and
  disconnect actions.
- Automatic sync runs on app start, after Google Drive connection, when the app
  returns to the foreground, before the app backgrounds/exits, and after local
  event/settings changes.
- The app no longer polls Google Drive every few seconds while idle. Local
  event changes are debounced for 1 second so repeated edits trigger one Drive
  request without excessive cellular data use.
- If another sync request arrives while a sync is already running, one more
  sync pass is guaranteed after the current pass finishes.
- Event create/update/delete sync uploads only the changed event file. App
  start, Google Drive connection, resume, and manual sync list v2 event files
  and merge by event ID.
- All-day events are normalized to local date boundaries during sync and local
  database save/load. V2 event files include `startDate` and `endDate`
  date-only fields for all-day events, preventing iPhone/iOS UTC-midnight
  all-day events from appearing as two-day events on Android/Windows.
- Android Google Drive connection can receive a web OAuth client ID through:

```powershell
.\tool\flutter.ps1 run --dart-define=GOOGLE_SIGN_IN_SERVER_CLIENT_ID="<web-client-id>"
```

- Windows Google Drive sync uses a desktop OAuth browser flow with PKCE and a
  local loopback callback. It can receive a Desktop app OAuth client ID through
  either an environment variable, a build define, or a local OAuth JSON config
  file. The current Daily Desktop OAuth client rejects token exchange without
  its generated client secret, so Windows installs must provide that secret from
  a local secret store, CI secret, or `%APPDATA%\Daily\google_desktop_oauth.json`.

```powershell
$env:GOOGLE_DESKTOP_CLIENT_ID = "<desktop-client-id>"
.\tool\flutter.ps1 run -d windows

.\tool\flutter.ps1 build windows --release --dart-define=GOOGLE_DESKTOP_CLIENT_ID="<desktop-client-id>"
# $env:GOOGLE_DESKTOP_CLIENT_SECRET = "<desktop-client-secret>"
# .\tool\flutter.ps1 build windows --release --dart-define=GOOGLE_DESKTOP_CLIENT_ID="<desktop-client-id>" --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET="<desktop-client-secret>"
```

Example local Windows config file, never committed:

```json
{
  "installed": {
    "client_id": "<desktop-client-id>",
    "client_secret": "<desktop-client-secret>"
  }
}
```

## Stage 2: Google Cloud/Firebase setup status

OAuth clients currently checked in or referenced by the app:

- Google Drive AppData target project for iPhone/iOS, Android, and Windows sync:
  `234127810480`
- Legacy Firebase metadata project: `424765276744`. Android no longer includes
  `google-services.json`; the app supplies the Web client ID directly.
- Android package name: `com.littlebit0.dailycalendar`
- OAuth scope: `https://www.googleapis.com/auth/drive.appdata`
- Web OAuth client for Android Google Drive connection:
  `234127810480-uvesp3703ktqon6oj90abhjc62k9g6me.apps.googleusercontent.com`
- Android debug OAuth client:
  `234127810480-mst5c3lojau02lbdov924j8o7vaohonl.apps.googleusercontent.com`
- Android release OAuth client:
  `234127810480-otvrdan5a1q6gbqejulbp4e7tueebr4n.apps.googleusercontent.com`
- Android GitHub release APK OAuth client:
  `234127810480-os12mgge72im7ijpcs5c9riqnv75kqti.apps.googleusercontent.com`
- Android current macOS development machine debug OAuth client:
  `234127810480-duu31lqoedfl6fv9tn9gcdfs7dtka7ic.apps.googleusercontent.com`
- Windows Desktop OAuth client:
  `234127810480-caigb6e78fj43lv268t78sam64c3aivb.apps.googleusercontent.com`
- iOS bundle ID: `com.littlebit0.daily`
- iOS OAuth client:
  `234127810480-l6i9pnoq4hpg6as12n7g1q5h0cak39oa.apps.googleusercontent.com`
- iOS reversed client ID:
  `com.googleusercontent.apps.234127810480-l6i9pnoq4hpg6as12n7g1q5h0cak39oa`
- macOS bundle ID: `com.littlebit0.daily`
- macOS OAuth client:
  `424765276744-rjfs830agtj0i0mrrlc1pci4sbh1ifpq.apps.googleusercontent.com`

Known configuration notes:

- iOS Google Drive connection now has a checked-in iOS OAuth client for
  `com.littlebit0.daily`; keep `GIDServerClientID`/`SERVER_CLIENT_ID` absent
  unless a same-project iOS-specific server client is deliberately added.
- macOS Google Drive connection has a checked-in OAuth client and URL scheme.
  The native GoogleSignIn SDK path also requires keychain sharing entitlement in
  signed builds;
  local debug builds without an Apple development certificate keep that
  entitlement disabled so the app can still run in local mode.
- Android runtime now uses package `com.littlebit0.dailycalendar` and the
  project `234127810480` Web client so Android reads/writes the same Drive
  AppData v2 file set as the working iPhone build. Do not restore the removed
  legacy `google-services.json` as the source of the Android Web client ID.
- Google Cloud has separate Android clients for the GitHub release APK signing
  key and the current macOS development machine debug key. The release workflow
  verifies the built APK certificate against the registered GitHub APK SHA-1 so
  a signing-key mismatch fails before publication.
- Windows must have the Desktop OAuth client secret available locally. Without
  it Google rejects the token exchange and the app shows a Google Drive token
  request failure.
- iPhone/iOS and macOS must implement the same v2 file layout. Do not keep
  writing or reading the abandoned `daily-sync-v1.json` snapshot on those
  platforms.

Still required before public release:

1. Confirm OAuth consent screen public-facing text, privacy policy, and support
   email.
2. After the first AAB upload, confirm whether Play App signing uses the same
   SHA-1 as the current Android release OAuth client. Add another Android OAuth
   client if Play Console App integrity reports a different app signing SHA-1.
3. Publish the OAuth app to production when the app is ready for external users.
4. Re-test Google Drive connection/sync from a fresh Google account.

Android debug signing certificates:

```text
Existing registered debug key
SHA-1   D0:5F:5F:28:C7:A1:9C:92:8A:F4:80:B0:B5:81:97:19:6F:EC:21:E2

Current macOS development machine debug key
SHA-1   69:A6:8E:1C:3F:53:1D:43:2D:81:9B:3E:B2:67:78:06:3C:71:6B:18
SHA-256 65:94:60:F3:8F:F5:81:23:30:9D:2D:1E:17:9A:65:D9:2A:22:E1:96:E0:D4:55:5F:A3:EE:2F:AF:D3:DB:1E:1D
```

Android GitHub release APK signing certificate:

```text
SHA-1   04:97:A8:86:73:A5:53:43:D3:13:47:BB:C3:B2:EC:26:65:73:BC:0E
SHA-256 94:03:AB:FD:50:E3:00:75:29:0D:0F:B7:AC:3D:EC:15:08:4C:C7:97:CD:36:85:1F:43:59:2B:5E:42:74:0B:29
```

Android upload/alternate release signing certificate:

```text
SHA-1   2F:0D:16:3A:FB:B9:E8:DE:97:A5:41:04:43:90:0E:AC:6A:51:76:72
SHA-256 D6:D4:18:72:A4:71:BA:55:35:CD:DD:D1:77:3C:C1:A4:3D:71:F1:3C:9B:26:25:DF:86:E0:DA:A7:36:76:8E:F1
```

Google's Drive API documentation lists `drive.appdata` as a non-sensitive
scope for an app's own configuration data:

- https://developers.google.com/workspace/drive/api/guides/api-specific-auth
- https://developers.google.com/workspace/drive/api/guides/about-files

### Android authorization recovery

Credential Manager sign-in and Google Drive authorization are separate steps.
The message `Authorization failed: 16: [28433] Cannot find a matching credential`
comes from the second step, not from Drive file synchronization.

- First request authorization for the authenticated account as usual.
- Only for this missing-credential error, retry using Google's default-account
  authorization client. Interactive consent is permitted only for an explicit
  user action; automatic sync must keep `promptIfNecessary: false`.
- Include `openid` in the recovery request and verify the token's userinfo `sub`
  against the signed-in Google account ID before returning any API headers.
  An account mismatch or failed verification must never access Drive/Calendar.
- After verification, the current session can use this recovery path silently.
  Changing/signing out the account clears that session choice.
- Cancellation, unrelated errors, and invalid OAuth configuration do not enter
  an automatic retry loop. Native SDK exceptions are converted to app messages.

Google documents this default-account authorization flow at
https://developer.android.com/identity/authorization#get-user-information.

### Android automatic authentication must never show UI

- Do not call `attemptLightweightAuthentication` on Android from startup, resume,
  settings initialization, or token refresh. "Lightweight" allows One Tap/account
  selection UI; it does not mean silent authentication.
- `signIn` is the only Android entry point that calls `authenticate`. Backup,
  restore, and cloud-backup deletion do not initiate login or consent dialogs.
- To restore an existing linked account after an app restart, request its
  previously granted scopes through `authorizationForScopes` only. Include
  `openid` and `email`, verify userinfo's verified email against the linked Daily
  account, and pin the verified `sub` for the restored session. Local account
  metadata alone never proves authentication and cannot authorize API requests.
- Missing grants, expired tokens, another account, cancellation, or an offline
  device must not fall back to interactive authentication. Keep local data and
  pending sync changes; the user can explicitly reconnect from account settings.
- An explicit Google Calendar import can still request additional Calendar
  consent after silently verifying the existing Drive session. It must not
  implicitly call `signIn` when no usable session is available.
- Signing out or switching the linked account invalidates in-flight restoration.
  Android debug APK build and automated auth/settings tests cover these paths;
  real-device Google UI verification is performed only when the user requests it.

API contracts:
https://pub.dev/documentation/google_sign_in/latest/google_sign_in/GoogleSignIn/attemptLightweightAuthentication.html
https://pub.dev/documentation/google_sign_in/latest/google_sign_in/GoogleSignInAuthorizationClient/authorizationForScopes.html

## Stage 3: Platform rollout

1. Android: first runtime target. The current app code is wired for this.
2. Windows: the app now uses desktop OAuth instead of the unsupported native
   GoogleSignIn plugin path. A Desktop app OAuth client ID must be supplied
   through `GOOGLE_DESKTOP_CLIENT_ID` or `%APPDATA%\Daily\google_desktop_oauth.json`.
   The current 234 Desktop client also requires its generated client secret.
3. macOS: local mode builds and runs. The native GoogleSignIn SDK path is wired
   to the macOS OAuth client and URL scheme, but keychain sharing requires Apple
   development signing. If native GoogleSignIn is not suitable for the
   signing environment, build with
   `GOOGLE_MACOS_AUTH_MODE=desktop` and `GOOGLE_DESKTOP_CLIENT_ID` to use the
   browser OAuth flow instead. Add `GOOGLE_DESKTOP_CLIENT_SECRET` only when the
   Google Cloud Desktop client requires it.
4. iOS/iPadOS: local mode builds and runs. The iOS OAuth client and URL scheme
   are checked in; test the same Drive AppData sync flow on simulator and a
   connected iPhone after installing the latest build.

## Stage 4: Hardening before public release

- Add encryption for v2 event/settings sync files before treating this as
  production-grade private data storage.
- Add conflict UX for simultaneous edits on multiple devices.
- Add a sync status screen or last-sync timestamp.
- Test Google Drive connection and sync with a fresh Google account, two
  Android installs, and then each desktop/mobile platform.
- For public distribution, publish the OAuth consent screen to production and
  provide the required privacy policy/support links.
