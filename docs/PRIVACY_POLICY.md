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

## Optional School LMS Connection

The school LMS connection is optional and requires a Google login in Daily.
You authenticate on your school's official login page. Daily reads course
names and the titles, deadlines, submission status and learning progress of
assignments, quizzes and learning content, and turns them into events. Daily
does not submit assignments or change anything in the LMS.

On your device only: if you choose "save login for this device", your school
username and password are stored in the operating system's secure storage
(Keychain or Android encrypted storage) and are not synced to other devices.
School session cookies are also kept in secure storage on the device. This
saving is a separate, explicit choice, and Daily's own servers never receive
your school credentials.

Through Google Drive sync (if you use it): events imported from the LMS (with
their source identifiers and completion state), your school user number and
whether the connection is enabled are stored in the Daily AppData area of your
Google account, like other synced data. School passwords, cookies and session
data are never written to Drive.

Disconnecting the school: deletes the saved login and school session on that
device and stops new imports. Events already imported are not deleted and the
school user number stays in settings until you connect again. "Delete saved
login on this device" removes only the saved username and password. Daily
does not currently let you delete an individual LMS event: events imported
from the LMS can be removed only together with all other events on the device,
through Settings > "Reset local data" (or "Delete Daily account", which also
deletes the Daily AppData backup in Google Drive). You can also delete Drive
data through your Google account's app data management. Existing Drive
revision history and safety snapshots may retain older content.

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
address and does not store or log the access token. Reports are not published.
Before storing, the receiver masks tokens, cookies, passwords, email addresses,
phone numbers, long IDs, URL query strings, home-folder user names and quoted
text in the report, using the same rules as automatic error reports. The masked
report, the app environment and the verified email (kept so the developer can
contact you) are stored privately on Daily's Ubuntu server and deleted after 90
days. The app shows a report ID after submission.

Contact files kept by an earlier version that posted reports as public GitHub
issues are deleted no later than 365 days after they were written.
Bug-report submission is a support feature and is independent of the optional
anonymous analytics setting.

## Automatic Error Reports

Automatic error reports are on by default and can be turned off at any time in
Settings > Privacy > Automatic error reports. Turning them off also deletes
reports still waiting on the device. Debug builds never send them.

When Daily hits an unhandled error, a framework error, or a failed Google Drive
sync, it records the error type, the feature where it happened, the top stack
frames, the error message, how often it happened, the app lifecycle state, app
version and build number, build environment, platform, device type
(mobile/desktop), operating-system version, locale, UTC offset, whether Google
Drive and the LMS are connected, and the time of the last Drive sync. Event
titles, notes, account names, email addresses, school or LMS details, and
calendar content are not collected.

Before a report leaves the device, and again on the receiver, Daily masks access
and refresh tokens, cookies and session IDs, passwords, email addresses, the
user-name part of home-folder paths, URL query strings, UUIDs and long IDs,
phone numbers, and quoted text in error messages.

Reports are sent only while a Google account is signed in to Daily; until then
they wait on the device (at most 20, for at most 7 days). Daily sends the same
error at most once every 6 hours and at most 10 reports a day. The receiver
verifies the Google access token the same way as for bug reports, keeps a hash
of the account ID only for rate limiting, and does not store the token or the
email address. Reports are not published: the receiver stores them privately
on Daily's Ubuntu server, the same way as the anonymous analytics aggregates,
grouped per day and per distinct error with occurrence counts and the app and
OS environments seen. Stored reports are kept for no more than 90 days.

## Data Sharing

Daily does not operate a separate backend server for your calendar data. When
Google sync is enabled, data is transmitted to Google Drive AppData through
Google APIs under your Google account. If you explicitly enable anonymous
usage analytics, the allowlisted anonymous events described above are sent to
Daily's aggregate analytics receiver. They are not combined with calendar,
account, advertising, or third-party data.

When you explicitly submit a bug report, Google receives the one-time UserInfo
request needed to verify the signed-in account. The report and the verified
email stay on Daily's support receiver and are not shared with GitHub or any
other third party.

Automatic error reports, described above, are not shared with GitHub or any
other third party; they stay on Daily's server.

## Deleting Data

You can delete local app data from the app's settings. You can also disconnect
or delete Daily's Google Drive AppData through Google account and Drive app data
management options.

Turning anonymous analytics off stops collection and removes analytics waiting
on the device. Settings also provides a separate delete action for queued
analytics. Data already received is aggregate-only and has no account or
persistent device identifier, so it cannot be identified or deleted as one
specific user's history.

To request deletion of a stored bug report and its contact email, contact the
address below and include the report ID shown in the app. Issues created under
the earlier version can still be redacted on request with their GitHub issue
number.

## Contact

For privacy questions or support, contact:

kimhee8953@naver.com
