Based on flutter_secure_storage 10.3.1 (pub.dev), original license retained. Daily patches preserve stored credentials on failure. Explicit delete operations are unchanged. See docs/reviews/ISSUES_207_208_201_205_140_142_2026-10-16.md.

- #937: `EncryptedPreferencesMigration` reads every EncryptedSharedPreferences value before the custom cipher writes to the shared file, publishes them in one commit with the algorithm markers, and removes ESP entries only afterwards. `initialize` reports a failed ESP migration as an error instead of falling back to ESP, removes markers written in that run so the next run retries, and sets `ENCRYPTED_PREFERENCES_MIGRATED` only after the ESP copy.

- #970: `StorageCipherFactory` treats a store with no algorithm markers, no stored values and no legacy wrapped AES-CBC key as a fresh install and uses the current algorithms; `initializeStorageCipher` commits the current markers to the data file before any key or value is created. Stores with legacy data keep the v9.2.4 default migration.

- #971: Android logs and error messages no longer contain storage key names; `FlutterSecureStoragePlugin.handleException` sends the Java stack trace as `PlatformException.details` only in debug builds. Removed the uncalled `migrateESPWithBackup` and `migrateNonBiometricWithBackup` (the default path uses `migrateNonBiometric`).
