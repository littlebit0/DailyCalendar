# LMS event storage and Drive ownership

LMS schedules use the existing per-event Google Drive AppData v2 files. SQLite
schema 9 adds nullable `event_records.lms_metadata` JSON and nullable
`sync_event_deletions.lms_owner_id`; existing personal events and deletion
records retain their existing values and account-switch behavior. Both Drift
migration and the snapshot/validate/replace startup migration create the columns.
The schema 8 -> 9 startup migration is local-only: it retains existing row values,
sync status and tombstones and does not restore or re-upload the entire Drive
dataset. Older Todo migrations retain their existing cloud migration behavior.

`CalendarEvent.lms` stores the provider, school, normalized Google email owner,
LMS principal, course and activity identity, source URL, opening/deadline times,
and optional source submission/progress state. These values participate in event
version comparisons. `fetchedAt`, credentials, browser cookies and connection
state are not part of event metadata, so an unchanged fetch does not create a
new event version or upload. Personal completion is separate from submission or
lecture progress. Source refreshes use existing event copies to retain personal
memo, reminders and completion. An optional account-scoped academicProfile.lmsCategoryId
selects the destination category for existing and future LMS events. When configured,
imports apply that category inside the event transaction; ordinary personal events
and other owners remain unchanged. A deleted category falls back to Basic. Before
a destination is configured, existing per-event categories are retained.

LMS command writes resolve against the latest row inside the existing repository
transaction: editor saves retain current school fields and completion; source
imports retain current personal fields; completion toggles retain current school
fields. This protects an editor opened before a source refresh and an import
prepared before a personal edit. Account checks also precede notification,
alarm, Drive-queue and widget side effects. Ordinary event commands keep their
existing behavior.

New LMS event IDs start with `lms:` and derive from the owner, school, LMS user,
course, activity type and stable activity ID. For this prefix, missing metadata
means unknown ownership: the event is not displayed or uploaded as a personal
event. A metadata-stripped remote edit may recover metadata from an existing
same-owner local record, and the next upload repairs the extension. A fresh
installation cannot infer ownership from a stripped ID; a subsequent authorized
LMS fetch reconstructs the source record. Equal-time versions with source data
take precedence over versions missing that data.

Upload selection, pending-change checks, restore, and deletion records restrict
LMS events to the authenticated Google owner. Existing local records belonging
to another owner cannot be replaced or deleted by the active account's restore.
Compacting an expired user-deleted LMS event retains its owner in the deletion
ledger and Drive deletion JSON. Ordinary tombstones omit `lmsOwnerId`, preserving
their existing wire shape. Ownerless legacy LMS deletions require a known local
source/ledger owner before application; otherwise they are ignored.

A timed LMS deadline with equal start/end timestamps is included at the start
of its own day, but excluded at the end boundary of the preceding day. Personal
event range semantics are unchanged.

Older released applications do not understand LMS metadata or ownership. These
protections apply to updated clients and cannot add protections to old binaries;
the shared-schema release must include all four supported platforms together.
