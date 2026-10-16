import 'dart:io';

/// Retry only Windows path races and sharing/lock contention. Permanent errors
/// must escape so the caller's serial lock can release subsequent operations.
Future<void> retryTransientFileWrite(Future<void> Function() write) async {
  const retryableCodes = {2, 3, 32, 33};
  for (var attempt = 0;; attempt++) {
    try {
      await write();
      return;
    } on FileSystemException catch (error) {
      if (attempt >= 3 || !retryableCodes.contains(error.osError?.errorCode)) {
        rethrow;
      }
      await Future<void>.delayed(Duration(milliseconds: 25 * (1 << attempt)));
    }
  }
}
