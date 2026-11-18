Based on flutter_secure_storage 10.3.1 (pub.dev), original license retained. Daily patches preserve stored credentials on failure. Explicit delete operations are unchanged. See docs/reviews/ISSUES_207_208_201_205_140_142_2026-10-16.md.

- #971: Android logs and error messages no longer contain storage key names; `FlutterSecureStoragePlugin.handleException` sends the Java stack trace as `PlatformException.details` only in debug builds. Removed the uncalled `migrateESPWithBackup` and `migrateNonBiometricWithBackup` (the default path uses `migrateNonBiometric`).
