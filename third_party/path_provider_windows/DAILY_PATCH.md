# Daily known-folder path release patch (#210)

Vendored from pub.dev path_provider_windows 2.3.0 (BSD-3-Clause; original
LICENSE retained; upstream example and tests omitted).

Only Daily issue #210: `getPath` releases the string returned by
`SHGetKnownFolderPath` with `CoTaskMemFree` (new `ole32.dll` binding in
`win32_wrappers.dart`) after copying it, on success and failure, before freeing
the container and GUID as before. Upstream 2.3.0 (latest at vendoring) freed
only the container, leaking one OS allocation per lookup; the default secure
storage looks the path up on every read and write.
Lint: `win32_wrappers.dart` also ignores `constant_identifier_names` for the Windows API constant names.
