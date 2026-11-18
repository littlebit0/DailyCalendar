Vendored flutter_secure_storage_windows 4.2.2 from the resolved pub.dev package, license retained.
Daily issue #202: bounded transient file-write retries; permanent errors propagate.
Regression tests live under the root test directory. Upstream examples/tests omitted.
Analysis uses the root project Flutter lint package; no new lint dependency. Retry regression uses the actual production helper on every CI host; DPAPI/native Windows acceptance is separate.

- #971 (not changed, decision open): `CryptProtectData`/`CryptUnprotectData` pass no optional entropy and the file stays in Roaming AppData, as upstream. Adding entropy or moving the file to Local AppData needs a migration of the existing `flutter_secure_storage.dat`; entropy shipped in the app binary would not stop another program running as the same Windows user. The native Credential Manager plugin is still built and registered although Daily never sets `useBackwardCompatibility`.

Files that differ from upstream (#972; update this list when re-vendoring):
- `lib/src/file_write_retry.dart` (new): #202 (above).
- `lib/src/preserving_store_read.dart` (new): a read or decrypt failure keeps the encrypted file instead of deleting it (#205).
- `lib/src/atomic_file_write.dart` (new): the store is written to a temporary file and then replaces the original (#934).
- `lib/src/flutter_secure_storage_windows_ffi.dart`: uses the three helpers above.
- `analysis_options.yaml`: includes `package:flutter_lints/flutter.yaml` instead of `very_good_analysis` (no new lint dependency, above).
