# Daily 64-bit notification time patch (#222)

Vendored from pub.dev flutter_local_notifications_windows 3.1.1 (BSD-3-Clause;
original LICENSE retained; upstream tests and test config omitted). 3.1.1 was the
latest version when vendored.

Only Daily issue #222:

- `scheduleNotification` takes the UNIX second as `int64_t` in `src/ffi_api.h` and
  `src/ffi_api.cpp`, and as `ffi.Int64` in the hand-edited `lib/src/ffi/bindings.dart`
  (regenerate with ffigen from the header if it changes). C `int` and `ffi.Int` are 32-bit
  on Windows, so times after 2038-01-19 03:14:07 UTC lost their value.
- The native `AddToSchedule` call is inside `try`/`catch (winrt::hresult_error)` and returns
  `false` instead of throwing across the FFI boundary.
- `zonedSchedule` and `zonedScheduleRawXml` throw a `StateError` when the native schedule
  returns `false` (invalid XML or a refused time) instead of ignoring it.
