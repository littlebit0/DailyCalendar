# Privacy, Security, and Consent Notes

Current release baseline: `3.3.1`.

This document is the pre-release checklist for Daily's current data handling.
It is not legal advice; it is the engineering baseline that should be reviewed
before public distribution.

## Data Stored Locally

- Calendar events: title, dates, times, all-day flag, recurrence, category,
  memo, location, URL, optional weather note, reminders, D-day display flag,
  sync metadata, and soft-delete timestamps.
- Unreleased timetable work (#74/#75): an offline cache of course titles,
  professors, meeting days/times and classrooms, notes, colors, lecture modes,
  session exceptions, source IDs, academic terms/date periods, timetable names, and sync
  metadata/deletion records. These fields also sync when Google Drive is linked.
- App settings: reminder defaults, week start day, lunar-date display, category
  definitions, D-day reminder offsets, onboarding completion, default calendar
  view, calendar filters, calendar display preferences, and AI feature toggles.
- Unreleased academic profile: stable university and campus IDs, school/campus
  names and degree group selected by the user. The linked Google account's
  AppData settings document stores this profile; the device keeps an offline
  cache. Login offers selection or Later, and account settings allow editing.
  Switching or unlinking Google accounts retains each inactive academic profile
  and its pending field revision in a local account-scoped cache. Reconnecting
  that account restores it; another account cannot upload it. Explicit local
  data reset removes the inactive caches too.
  Daily does not infer school membership from an email address or collect a
  university password, student number, department or enrollment history.
  Public university-directory and course data are bundled from documented
  official sources. Directory search is local and sends no search text to a
  school or third-party search service.
- App lock PIN, when enabled, is stored locally through platform secure storage
  and is not included in Google Drive sync files.
- Linked Apple and Google account metadata is stored locally in secure app
  preferences to restore the user's chosen sign-in state. Daily does not yet
  operate a backend account-linking service.
- Gemini API key, if used later, is stored through platform secure storage.
  The AI UI is currently disabled and marked as in development.

## Anonymous Usage Analytics

- Default state: disabled. Consent is a device-local setting and is not synced
  through Google Drive.
- Allowed data: screen/feature enum, success state, categorized error code,
  bounded duration and slow-frame count, app version, platform, OS major.
- Forbidden data: calendar content, search/free text, account metadata, tokens,
  precise location, advertising IDs, persistent user or device IDs.
- Identity boundary: the session UUID is memory-only. Queued event UUIDs exist
  only for delivery deduplication and are removed after transmission.
- Local retention: maximum 200 events and seven days. Disabling collection or
  selecting delete removes the queue immediately.
- Network isolation: analytics errors are swallowed outside the calendar and
  Drive synchronization paths. Analytics never changes an event or sync result.
- Server boundary: the receiver repeats strict schema validation, stores daily
  aggregate groups for 90 days, and never persists request bodies, session IDs,
  event IDs, accounts, or network addresses. Dedupe hashes expire after seven
  days.
- Transport: production builds must set an HTTPS `DAILY_ANALYTICS_ENDPOINT`.
  HTTP is accepted only for localhost debug tests.

See [Anonymous Analytics Deployment](ANALYTICS_DEPLOYMENT.md) for server and
release configuration.

## Authenticated Bug Reports

- Availability: only while a verified Google account is actively signed in.
- Explicit action: no report is sent until the user reviews and submits the
  in-app form.
- Collected data: the user-entered report, app version/build, platform, OS
  version, and verified Google email address.
- Token boundary: the Google bearer token is used only against Google's UserInfo
  endpoint and is never persisted or logged.
- Public/private boundary: report text and environment are posted to the public
  `littlebit0/DailyCalendar` GitHub issue tracker. Email is excluded from the
  issue and stored only in a private server-side contact mapping.
- Server storage: contact files use directory mode `0700`, file mode `0600`, and
  a maximum 365-day retention period on `/mnt/storage/daily-analytics`.
- Abuse control: each verified Google subject is limited to five reports per
  hour; only a SHA-256 digest of the Google subject is stored with the contact.
- GitHub credential: a fine-grained token owned by `littlebit0`, restricted to
  the DailyCalendar repository with Issues write access, is loaded from a
  systemd environment file and never committed.

## App Store Connect Update For Analytics

Before distributing a build with a configured analytics endpoint:

- Set `Data Used to Track You` to No. Daily does not combine this data across
  apps or websites and does not use advertising identifiers.
- Declare `Usage Data > Product Interaction` as collected for `Analytics`.
- Mark it as not linked to the user's identity.
- Do not select advertising, marketing, personalization, or third-party
  tracking purposes.
- Keep the privacy-policy URL pointing to the policy that contains the optional
  analytics section above.

For a build that includes authenticated bug reporting, also declare:

- `Contact Info > Email Address` as collected, linked to the user, and used for
  `App Functionality`/customer support.
- User-entered bug-report text under the applicable `User Content` support
  category, linked to the user and used only for app functionality/support.
- Do not mark either category as tracking or advertising data.

## Google Drive Sync

- Sync uses the Google Drive `appDataFolder` scope:
  `https://www.googleapis.com/auth/drive.appdata`.
- The app stores private v2 JSON files in the user's app data folder:
  `daily-sync-v2-event-{eventId}.json` for each event and
  `daily-sync-v2-settings.json` for non-secret app settings.
- Unreleased #74/#75 working-tree code also stores
  `daily-sync-v2-timetable.json` for the timetable fields listed above, including
  user-entered course notes. This addition is not in the published 3.5.2 assets.
- Sync files do not include the local app lock PIN.
- The app does not request access to the user's visible Drive files.
- Google Drive AppData sync files are not yet end-to-end encrypted. Treat that
  as a blocker before storing highly sensitive content.

## User Consent Text Needed Before Public Release

Use this wording as the basis for the OAuth consent screen and store listing:

```text
Daily stores your calendar events and app settings on your device. If you sign
in with Google, Daily saves private app-data files in your Google Drive app
data folder so your devices can restore and sync your data. Daily does not
read, list, or modify your visible Google Drive files.
```

Required public links before production OAuth release:

- Privacy policy URL
- Support email
- App homepage or support page
- Data deletion instructions

## Data Deletion

Users must be able to:

- Delete local events from the app.
- Log out from Settings, which returns the app to the welcome flow.
- Use the in-app membership withdrawal action, which deletes the Google Drive
  app-data backup when available, clears local events/settings, signs out, and
  returns to the welcome flow.
- Delete the app's Google Drive app-data files from their Google account if
  manual removal is needed.

## Security Hardening Still Needed

- Add optional encryption for Google Drive AppData sync files.
- Continue release-device testing of PIN, biometric, and system authentication
  unlock paths on iOS and macOS.
- Re-test with a fresh Google account after publishing the OAuth app to
  production.

## Korea Holiday Source

Korean public holidays and substitute holiday rules are based on the current
`관공서의 공휴일에 관한 규정` in the National Law Information Center:

- https://law.go.kr/LSW/lsLinkCommonInfo.do?chrClsCd=010202&lsJoLnkSeq=1018770085
- https://law.go.kr/LSW/lsLinkCommonInfo.do?chrClsCd=010202&lsJoLnkSeq=1027161473
