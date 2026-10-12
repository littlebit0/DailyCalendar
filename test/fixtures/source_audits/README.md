# Frozen public source audit fixtures

These are existing public-source test inputs from the paused university work,
not new collection, enabled support or a completion claim. The product does not
load this directory. Logical `work/...` names preserve test/source provenance;
tests resolve them exclusively through `test/support/source_fixture.dart` and
never fall back to the ignored local research workspace.

`manifest.json` maps logical paths to SHA-256 hashes of the original bytes.
The four archive parts concatenate into XZ-compressed tar streams, whose combined SHA-256 is
also in the manifest. Identical bytes are stored once. The archive contains only
regular files named by their hashes. `tool/prepare_test_fixtures.py` uses Python 3
standard libraries to verify the archive and each source, reject unsafe paths,
and materialize a shared temporary cache keyed by the manifest hash; the Dart resolver holds an OS file
lock while preparation runs. No network access or school login is involved.

Historical source/CELL/staging/checkpoint tests use the corresponding frozen
version, rather than comparing an old source against later intentionally
modified release data. Historical publication projection changes only
`researchOnly` metadata in memory. Model/Drive regression checks remain, and
`release_asset_integrity_test.dart` independently checks the SHA-256 of every
4.0.0 timetable and organization JSON so CI repairs cannot change product data.
Capture-only UI audits write to OS temporary directories rather than `work/`.

Collected from existing test reads on 2026-10-12: 10,092 logical inputs, 9,475
unique byte sequences. Text inputs were checked for credential/key/token
patterns with no findings. Original bytes and source hash assertions are
preserved. An absent fixture fails normally; there is no skip-on-missing rule.

Python 3 is required for these source tests on a fresh checkout. The ordinary
Flutter test command prepares the cache automatically. To discard only this
cache, remove the `daily-source-fixtures-<manifestSHA256>` directory and matching
`.lock` file in the OS temporary directory when no test process is using it.
