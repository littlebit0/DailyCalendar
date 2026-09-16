# Daily Privacy Policy

Effective date: 2026-09-16

Current app release baseline: `3.5.0`.

Daily is a personal calendar app. This policy explains what data the app uses
and how it is handled.

## Data Stored On Your Device

Daily can be used without signing in. In local mode, calendar events, settings,
notification preferences, and related app data are stored on your device.

## Optional Google Drive Connection And Sync

Google Drive connection is optional. If you connect a Google account for Drive
sync, Daily uses Google Drive AppData to back up and sync app-specific data such
as calendar events, settings, D-day entries, and deletion tombstones.

Daily does not read, modify, or manage your regular Google Drive files. Sync
data is stored in the app-specific Google Drive AppData area.

Deleted event bodies may be compacted after their final planned date has passed.
Minimal event IDs and deletion timestamps remain to prevent stale devices from
restoring deleted events. Existing safety snapshots and Drive revision history
may still retain older content. Undeleted historical events are not purged by
this cleanup.

## Optional Weather And Academic Calendars

Weather display is off by default. You may choose a Korean region manually or
explicitly allow approximate location to select a nearby forecast region.
Daily requests Korea Meteorological Administration forecasts using the region's
grid, not raw device coordinates or account identity. The service receives the
usual network connection information, including the requesting IP address.
Location is not collected for advertising, analytics or background tracking.
Forecast preferences and bounded caches remain on the device.

University calendar imports request public academic-calendar records from the
selected university's official website. Daily does not send personal schedules
or account credentials to that website. Imported events can be backed up through
the optional Drive connection; subscription preferences remain device-local.

## Data Use

Daily uses your data only to provide app functionality, including calendar
display, reminders and alarms, widgets, calendar import, backup, restore, and
cross-device sync.

Daily does not sell personal data, does not show ads, and does not use your data
for third-party tracking.

## Optional Anonymous Usage Analytics

Anonymous usage analytics is off by default. You may turn it on or off at any
time in Settings > Privacy.

When enabled, Daily may collect screen and calendar-view usage, whether major
features such as event editing, search, filters, widgets, and sync succeed or
fail, categorized error codes, interaction duration, slow-frame counts, app
version, platform, and the operating system major version.

Daily does not include calendar titles, notes, locations, links, search text,
free-form input, names, email addresses, Apple or Google account information,
authentication tokens, precise location, advertising identifiers, or a
persistent device identifier in analytics.

Analytics events use a random session identifier that exists only for the
current app process. Offline events are kept on the device for no more than
seven days and the queue is limited to 200 events. The receiver validates an
allowlist again and stores only daily aggregate counts and performance totals
for up to 90 days. It does not persist session identifiers, event identifiers,
network addresses, or raw request bodies.

## User-Submitted Bug Reports

The in-app bug-report form is available only to users with an active Google
login. When you explicitly submit a report, Daily sends the report text, app
version, build number, platform, operating-system version, and the current
Google access token to Daily's support receiver.

The receiver uses the access token only to request your Google account identity
from Google's OpenID Connect UserInfo service. It requires a verified email
address and does not store or log the access token. The verified email is kept
privately so the developer can contact you about the report. The report text and
app environment are posted as a public issue in the DailyCalendar GitHub
repository; the email address is not included in that public issue. The app
shows this public/private distinction before submission.

Private email-to-issue contact mappings are access-restricted on Daily's Ubuntu
server and are retained for no more than 365 days. Bug-report submission is a
support feature and is independent of the optional anonymous analytics setting.

## Data Sharing

Daily does not operate a separate backend server for your calendar data. When
Google sync is enabled, data is transmitted to Google Drive AppData through
Google APIs under your Google account. If you explicitly enable anonymous
usage analytics, the allowlisted anonymous events described above are sent to
Daily's aggregate analytics receiver. They are not combined with calendar,
account, advertising, or third-party data.

When you explicitly submit a bug report, the report text and app environment are
shared with GitHub as a public issue. Google receives the one-time UserInfo
request needed to verify the signed-in account. The verified email is retained
only by Daily's support receiver and is not published to GitHub.

## Deleting Data

You can delete local app data from the app's settings. You can also disconnect
or delete Daily's Google Drive AppData through Google account and Drive app data
management options.

Turning anonymous analytics off stops collection and removes analytics waiting
on the device. Settings also provides a separate delete action for queued
analytics. Data already received is aggregate-only and has no account or
persistent device identifier, so it cannot be identified or deleted as one
specific user's history.

To request deletion of a private bug-report contact mapping or redaction of a
public issue, contact the address below and include the GitHub issue number.

## Contact

For privacy questions or support, contact:

kimhee8953@naver.com
