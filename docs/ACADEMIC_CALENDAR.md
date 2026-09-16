# University academic calendars (#63)

## Scope

- Shared Flutter implementation for Android, iOS, macOS, Windows and Linux.
- First supported source: Sangmyung University undergraduate official calendar.
  The selector only lists implemented sources, not unsupported universities.
- Settings > Screen and calendar > University calendar. Preview a year, select
  events, then import. University-named category supports existing category color,
  ordering and visibility settings. Original titles/campus labels are retained.
- The official annual view uses January through December, NOT an inferred
  March-February academic year. This includes February course registration.
  Overlapping events keep their full span, including next-year dates.

## Category color

- The category-color swatch opens the same presets and custom RGB palette as
  ordinary category settings, including touch/drag selection and numeric inputs.
- Before importing, color stays in the page draft and preview. Import creates
  the university category with it. Cancel/back does not write the selected color.
- For an existing university category, Apply updates its events and settings
  through the existing category command/sync path. Completion, notes and dates
  are preserved. Refresh/reimport keeps the current category color.
- Color choices do not automatically import events or enable subscriptions.

## Update introduction

- Existing users receive a new-feature introduction after the startup sync gate,
  using the stable ID `university-academic-calendar-v1`. The minimum version is
  3.4.0; the feature ID, not a version bump, determines whether it is unseen.
- Settings opens the academic calendar page without importing anything. Later
  dismisses it without changing settings. Returning from the page or dismissing
  acknowledges it; interruption before acknowledgement does not.
- Previously acknowledged weather/wallpaper introductions are not replayed.
  Fresh installation retains the existing onboarding baseline behavior.
- Automated tests cover same-version upgrades, platform filtering, interruption,
  persistence, settings navigation, four languages and large-text layout.

## Verified official source

- https://www.smu.ac.kr/ko/life/academicCalendar.do
- The page loads `/_custom/smu/resource/js/app/app.bachelor_calendar.calendar.js`.
- Same public POST as the page: `/app/common/selectDataList.do`,
  `sqlId=jw.Article.selectCalendarArticle`, `modelNm=list`,
  `jsonStr={"year":"2026","month":"1","bachelorBoardNoList":["85"]}`.
- Board 85 is the official undergraduate calendar, not an inferred graduate or
  department calendar. No account, credential or personal event data is sent.
- `articleNo` is the stable identity. `etcChar6` is the start and `etcChar7` the
  inclusive final day; Daily stores a date-only exclusive end. `etcChar8` is
  currently `etc` even for academic records, so it is NOT used to filter them out.
- `dart run tool/check_academic_calendar.dart 2026` verified 62 unique official
  records with valid periods on 2026-09-16. The app fetches live data, not fixtures.
- Invalid dates, duplicate conflicting IDs, empty/unrecognized responses and HTTP
  failures fail closed. Website changes require updating the source adapter.

## Ownership and refresh

- Stable Daily event ID is derived from university ID plus source ID, not title,
  date or selected year. Source edits and year-overlapping imports do not duplicate.
- Import uses EventCommandService and the existing v2 event sync queue. No database
  schema changes, full-file synchronization or new backend service.
- Local `academic.subscriptions.v1` stores year, exclusions, source baselines,
  managed event IDs, refresh attempts and success/failure state. It is cleared on
  local reset/logout. It does not sync subscription settings across devices.
- Source updates modify title/dates/source URL only while those fields still
  match the previous source baseline. Local title/date/link edits, recurrence and
  deleted events are protected. Notes, completion, reminders, alarms and category
  edits are preserved. On a different device with no baseline, a different local
  record is preserved conservatively, not assumed safe to overwrite.
- Automatic checks occur after startup/resume Drive synchronization attempts,
  at most once per 24 hours (also throttling failures). No timer or idle polling.
  A subscription to the current year follows the new calendar year; deliberately
  selected historical years remain fixed. Manual update is always available.
- Source removals never delete a stored event. Deselected records are excluded
  from further updates, and already-stored records remain. University category
  visibility can be toggled separately without disconnecting.
- Disconnect keeps events. Explicit confirmed removal deletes only managed IDs
  and queues ordinary deletion tombstones; personal events in the same category
  remain. Category is retained. Deleted events are not resurrected on reimport.
- Partial writes are reported and retried. Managed IDs are persisted before the
  batch, so interruption cannot orphan imported records from explicit removal.
- No unsupported school, source-type classifier, background timer or PDF/OCR
  fallback is presented as implemented.

## User acceptance (not performed by the agent)

1. Open University calendar in settings; preview Sangmyung University 2026.
2. Deselect a few records, import; verify category name/color and period endings.
3. Refresh twice: event count must not grow. Re-import another year with an
   overlapping event: it must remain one event with its original complete span.
4. Edit/delete an imported event, refresh: edits/deletions must remain.
5. Toggle category visibility and color; verify calendar, quick view and widgets.
6. Disconnect, reopen app: no automatic source update; stored events remain.
7. On disposable test data, confirm removal: only university-imported records
   disappear; a personally created event in the same category must remain.
8. Check large text, light/dark appearance and all four supported UI languages.
9. On a second connected device, confirm imported events arrive through existing
   Drive sync. Subscription setup/refresh preferences are per device.
10. Choose a preset/custom color before import; verify previews and imported
    events use it. Change it repeatedly after import, including completed events.
    Cancel a color change and refresh the calendar: the saved color must remain.

Automated coverage lives in `test/core/academic_calendar_test.dart` and the
existing import tests. Installed app interaction is reserved for the user.

## Verification on 2026-09-16

- `flutter analyze --no-pub`: clean.
- Full Flutter suite: 497 passed, one pre-existing skip.
- Apple Debug builds and strict/deep code signatures verified; Android Debug
  APK built and signature verified. iPhone 17, macOS Daily Test and Pixel 9 were
  updated in place without launching. SQLite/preferences hashes unchanged.
- Native Windows/Linux build and installation were not available in this macOS
  environment. Shared code is included, but native parity is not asserted.
- No production installation, version bump, public release, commit or push.
- Announcement follow-up: targeted tests 35 passed, full suite 507 passed with
  one pre-existing skip, analyze clean. All three test apps updated again without
  launch; installed artifacts matched fresh builds and database/settings hashes
  remained unchanged. Native Windows/Linux installation is still unverified.
- Category-color follow-up: full suite 522 passed, one existing skip; analyze
  clean. Rebuilt/signed-verified and updated all three test apps without launch,
  preserving SQLite/preferences. Real-use acceptance remains with the user.
