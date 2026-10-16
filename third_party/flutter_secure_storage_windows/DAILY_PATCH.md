Vendored flutter_secure_storage_windows 4.2.2 from the resolved pub.dev package, license retained.
Only Daily issue #202: bounded transient file-write retries; permanent errors propagate.
Regression tests live under the root test directory. Upstream examples/tests omitted.
Analysis uses the root project Flutter lint package; no new lint dependency. Retry regression uses the actual production helper on every CI host; DPAPI/native Windows acceptance is separate.
