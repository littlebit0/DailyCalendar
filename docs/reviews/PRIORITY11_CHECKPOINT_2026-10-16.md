# Priority 11 through #97 — 2026-10-16

The final user request was to finish #97, fix discovered failures, validate, and commit/push. Test-app update and CI-result review remain deferred. No university expansion or new issue creation.

## Changes

- #116: request ownership across native permission, Dart cancellation and late voice callbacks.
- #164/#125/#166/#167/#168: atomic recurring moves/completion, Siri occurrence identity, editor count/exclusion preservation.
- #102: occurrence identity across Android/Apple/Windows widget actions.
- #145: durable per-stage recovery after successful database saves, including retryable widget failures and retained drafts only on failed saves.
- #93: verified Windows installer download and installed-edition eligibility; helper waits for natural process exit.
- #94: keep stored alarm preferences when capability/permission is absent.
- #155: persisted unique negative notification IDs; migrate colliding legacy positive IDs without deleting other known reminders.
- #118: retain normal zero-minute fallback until native scheduling confirms a same-time alarm.
- #104: reconcile existing pending/snoozed/ringing alarms instead of unconditional startup cancellation.
- #96: stable occurrence completion identity and recoverable post-write effects.
- #97: original-anchor monthly/yearly expansion in Dart and Swift; nullable schema10 recurrenceAnchorDay survives future split, database and Drive transfer; explicit date edits reset anchor. Schema8/9 additive migration avoids cloud reimport. Existing user dates/exclusions/detached records remain intact.

#117 remains deferred by explicit user decision; next priority #101 is not started.

## Verification and corrections

Initial full Flutter run:2122 passed,37 failures. Kept all tests and corrected failures; no skips added. Narrow reruns only:

- migration/event group:134 passed,2 new chat UI tests failed; chat2 subsequently passed after preserving input-frame rebuild and avoiding settle while the confirmation's background spinner remains active.
- follow-up/Drive/fixture/accessibility group:130 passed, same2 chat failures subsequently resolved.
- timetable loader/UI:22 passed after moving actual background catalog parsing outside fake-async widget execution and reusing loaded fixtures. No source data or support policy changes.
- provider/widgets:217 passed, including previously compilation-blocked files; corrected callback provider wiring, platform debug-state restoration before test invariants and the atomic repository test double.
- final recurrence/updater:25 passed. Shared10 recurrence fixtures cover29/30/31/28, leap return, intervals1/2/12, year boundary, count/until/exclusions, narrow window, February split anchor and final-end agreement; actual SQLite roundtrips and Drive encode/decode checks included.

Counts overlap; do not sum into a distinct total or describe the initial whole run as all green. Every observed failure has a passing affected rerun. Full lib/test/tool/vendor static analysis passed; final changed files checked separately. Product whitespace check excludes vendored upstream CRLF/trailing whitespace retained unchanged in imported packages.

Android app unit18 passed/0skips. Native Swift voice/widget tests passed; production SQLite Siri mutation and shared fixture test passed after fixing throwing-expression syntax. Portable Windows action codec compiled and passed with clang++; cmake was unavailable locally. macOS Debug native build passed with host-only deployment target14, iOS arm64 simulator unsigned build passed. Project deployment targets unchanged.

## Boundaries

No test app update, install, launch, login, real-device session or physical notification action. No actual Windows updater/process/native acceptance. No full remote CI result reviewed. Normal CI triggers are intact; Android native tests and Apple/Windows regression selection are registered. Prior batches' individual review documents retain their own validation and limitations.

Local evidence: work/priority11-onward-20261016/{flutter-tests,affected-rerun,affected-rerun2,chat-settle-correction,timetable-loader-rerun,provider-widget-rerun,anchor-end-final,analyze-final,analyze-two-final,android-tests,native,siri-rerun,mac-compile,ios-compile}.log. University work remains paused.
