# Public university calendar adapters

Checked 2026-09-26. Existing Sangmyung (`smu`) behavior remains unchanged.

## Dankook (`dku`)

The official [university calendar](https://www.dankook.ac.kr/web/kor/-2014-)
requests `/o/dku_calendar-rest/calendar/events/0/{startMs}/{endMs}`. This public
JSON endpoint supplies the university-wide calendar including campus-specific
labels in the original titles. The 2026 calendar request returned 125 rows.
No account, browser token or authenticated endpoint is required.

The adapter constructs query boundaries in Korean time and interprets event
millisecond timestamps in Korean time regardless of the device timezone. The
published final date becomes an exclusive date-only end, matching Daily's
all-day model. Empty/malformed responses fail without replacing existing events.

## Chonnam (`jnu`)

The official [undergraduate annual calendar](https://events.jnu.ac.kr/Schedule.aspx?mode=1&YY=2026)
is shared by Gwangju and Yeosu. The adapter requests `mode=1` and the selected
`YY`, reads only the identified undergraduate calendar table and preserves its
original titles. The official response repeats the entrance-ceremony row;
identical title/date pairs are deduplicated. Graduate (`mode=2`) events are not
mixed into the undergraduate subscription.

## Identity and validation

Neither new public source publishes an event identifier. IDs therefore use the
event's start year, normalized title hash and occurrence order for repeated
same-title events. Date-only corrections keep the same ID if start year and
same-title occurrence order remain unchanged. A title/year change can produce a
new identity; the existing user-edit/deletion preservation rules still apply.
This limitation is explicit rather than claiming a nonexistent official ID.

The adapters reject malformed dates, reversed ranges, unexpected row shapes,
missing tables and empty years. Existing lifecycle refresh throttling, preview
selection, local-edit preservation and Drive sync behavior remain in the common
AcademicCalendarService.
