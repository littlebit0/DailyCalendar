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

## Category editing and SQLite identity (issues 89/90, 2026-10-12)

SQLite writes stable category IDs instead of regenerating IDs from labels. The
existing local precision JSON column carries `categoryIdentity` (id/label/color/lock)
without a schema migration. Category identity is reused only when the stored
category matches that ID, or an unambiguous legacy non-reserved label. Native
category changes cannot revive stale identity; stale timestamp fingerprints still
reject precision after native edits. Drive v2 already carries category ID and label.

The editor resolves the actual ID first, then an exact unique legacy representation.
Missing/deleted categories require reselection, never a silent fallback. Categories
are reread on save. An untouched category preserves the latest repository value
inside the LMS write transaction; an explicit selection applies the chosen category.
Configured LMS import/reclassification remains its existing separate policy.

Startup shows the locally scoped calendar first and performs Drive, LMS and academic
refresh without blocking that screen. Migration, account filtering, paced requests,
bounded Drive retries and existing LMS/academic cache/error policies remain in force.

## LMS sequential refresh efficiency (2026-10-12)

Required dashboard/course indexes, learning reports and quiz status reads remain
fresh; completed quizzes are not permanently cached. A dashboard just loaded
and verified during login/restoration can be consumed once within2s of the
actual page load, only under the same origin/principal/generation. Subsequent
reads or an expired/unrecognized snapshot use ordinary authenticated GETs.

Concurrent force requests during restoration upgrade the upcoming collection
instead of starting a redundant second full pass. A force request AFTER collection
starts retains a trailing pass, so a newly submitted quiz cannot be missed because
its detail was already read. Owner/session invalidation behavior remains intact.

Requests remain sequential with >=100ms between request starts. Slow responses
count toward that interval rather than receiving an additional pause afterwards.
Live cookies are still validated on every response; identical snapshots already
successfully saved by this session skip Keychain/secure-store rewrites. Changed
cookies save immediately; failed writes are not marked saved. Only an in-memory
fingerprint is retained for comparison. No credential/cookie Drive serialization.

Profile diagnostics include fixed read kinds and apply durations, without URLs,
course names, identities or response contents. Fixture request/wait reductions
are not measured real-account speed improvements.

## Verified missing-status and learning coverage recovery (2026-10-12)

A verified future-opening notice on the correct quiz/course landing page can
prove not attempted even when the school omits both the attempt table and POST
start form. An elapsed/ambiguous access restriction remains unknown. No attempt,
answer, review, grade, media or submission endpoint is followed.

The authenticated exact report warning that no progress-enabled resources exist
is distinguished from a missing/error response; lecture absence never prunes
previous schedules. An unstudied report can omit its detail marker/periods. Only
a unique same-course vod/econtents resource with its real module link and explicit
displayed opening/deadline supplements such a row. Verified SMU course formats
ubstopics/ubsweeks supported. Course-module IDs are explicitly distinct from
opaque report module IDs. Ambiguous matches remain unresolved. Missing learned
time stays null, never fabricated zero/completion. Existing lecture identity is
retained across marker appearance only for a unique same-owner/principal/course
match with identical title, opening/deadline and attendance requirement.

Current authorized live snapshot:9 courses,49 schedules (2 recovered),6 quizzes,
zero unresolved quiz/learning rows or failed reports. Independent app repository
read:49 persisted active rows, zero missing/extra/duplicate keys, date mismatch or
confirmed completion mismatch. Three quizzes complete/three incomplete. Current
account has no manual overrides; fixture tests establish their preservation.
Evidence work/lms-coverage-speed-20261012/live/database-integrity.json.
