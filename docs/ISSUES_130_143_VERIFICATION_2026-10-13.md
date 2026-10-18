# Issues130/143 — implemented and Mac test updated

## Issue130
Bootstrap no longer marks a partly upgraded legacy DB current after adding only three columns. Drift and snapshot bootstrap use the same generated-column migration implementation. Missing fields receive actual current defaults/constraints; legacy single reminders become lists only when the list column was absent. Stored categories/colors are preserved. Historical sensitive removal remains. Current-version databases are checked against generated current column type/null/default/primary-key metadata and Boolean constraints; incomplete v9 databases are repaired on a snapshot copy. SQLite integrity and retained IDs are validated before atomic replacement. Schema8→9 and current9 repair perform no remote restoration/full upload and retain pending/synced states. Helper connections do not emit fabricated actual-database startup timings.

## Issue143
App-lock and Settings PIN verification catch secure-store failures and always release checking. Errors remain distinct from wrong PIN; failed reads/writes do not unlock. Legacy verified PIN saves length only, without rewriting its secure hash. App PIN verification owns a generation: background/relock or disable invalidates old results. Disposed or dismissed Settings verification cannot close a newer dialog. Safe translated errors do not include PIN/hash/raw storage data.

## Verification
Migration/Drift46 passed; stricter SQLite-constraint regression28 passed (overlaps46). PIN widgets11 passed plus existing background-lock1 passed. Existing settings core checks passed in the initial combined run; all27 failures there were a new fixture expectation that confused stored category label with repository resolution without a custom-category list. The assertion now checks preserved SQL value and passes. Whole analysis found only four new test style lints; corrected checks and changed-scope analysis pass. Normal Drift upgrades cover explicit schema1–8; snapshot paths cover1–8 plus incomplete current9, offline/empty remote/winner conditions, post-upgrade repository reads/writes, preserved deletions and failure without original replacement.

These fixtures are reconstructed explicit historical definitions, not past-release exported DBs. Widget tests inject storage errors through a fake, not actual Keychain/Keystore failure. No live accounts/data modified. These local checks were followed by the full remote CI below. Neither establishes live account or all-device acceptance.

Mac optimized profile/AOT build succeeded. Canonical ~/Applications/Daily Test.app updated in place; test identifier/version4.0.0, signature, secure entitlements, source/built/installed academic/timetable/logo assets verified and preserved. Prior app saved as a compressed backup. Generated app removed to avoid duplicate installations. No launch/restart or real-device migration performed. See install-receipt.json for exact backup and hashes.

## Final remote CI — recorded 2026-10-14
Fix commit `0a7cf882` was pushed through merge commit `e20494b830642cdf3ced29b96af11aaf028d95eb`. The normal push [CI run38409055543](https://github.com/littlebit0/DailyCalendar/actions/runs/38409055543) completed successfully; its source commit, push event and all four job conclusions were rechecked when recording this handoff.

- Analyze and test: Linux full suite2028 passed,0 failed,32 Apple-only cases skipped.
- Apple LMS session tests:40 passed,0 failed,0 skipped. All32 Linux-skipped test names were individually matched to successful Mac cases.
- Windows debug build and Android debug build: build and artifact upload succeeded.

No known CI failure remains for this verified commit. No CI-skipping marker or reduced test selection was used. Later remote commits through `77f6124d` were documentation-only; this result is pinned to `e20494b8`, not a claim about subsequent workflow runs or unrelated uncommitted changes.

Nonblocking warnings remain: Node20-based actions forced onto Node24 and setup-java v4 deprecation. Ubuntu runner migration and Mac ARM runner capacity notices are environment notices, not test failures. Real past-release DB exports, real Keychain/Keystore fault injection and live device acceptance were not performed and remain unverified; reconstructed fixtures and fake-storage widget checks do not substitute for them.

Final evidence: `work/issues-130-143-20261013/final-ci-receipt.json`, `remote-ci-result.json`, `remote-ci.log` and `remote-apple/apple-lms-results.json`. University expansion/source/classification/support work remains STOPPED; issue92 remains deferred and was not completed by this CI.
