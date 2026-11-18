Based on flutter_secure_storage 10.3.1 (pub.dev), original license retained. Daily patches preserve stored credentials on failure. Explicit delete operations are unchanged. See docs/reviews/ISSUES_207_208_201_205_140_142_2026-10-16.md.

- #937: `EncryptedPreferencesMigration` reads every EncryptedSharedPreferences value before the custom cipher writes to the shared file, publishes them in one commit with the algorithm markers, and removes ESP entries only afterwards. `initialize` reports a failed ESP migration as an error instead of falling back to ESP, removes markers written in that run so the next run retries, and sets `ENCRYPTED_PREFERENCES_MIGRATED` only after the ESP copy.

Daily issues: #207 (operation errors never delete stored credentials), #208 (cipher migration keeps the old key and data until the new data is committed), #397 (writes and deletes are committed and checked), #937 (above).

Files that differ from upstream (#972; update this list when re-vendoring):
- `android/.../FlutterSecureStorageConfig.java`: `shouldDeleteOnFailure()` is always false (#207).
- `lib/options/android_options.dart`, `test/flutter_secure_storage_test.dart`: `resetOnError` defaults to false and is documented as ignored on Android (#207).
- `android/.../FlutterSecureStoragePlugin.java`: a `DurableEdit.PersistenceException` is reported as an error, never as a reset (#397).
- `android/.../DurableEdit.java` (new), `android/src/test/.../DurableEditTest.java` (new): `commit()`-checked writes and deletes (#397).
- `android/.../FlutterSecureStorage.java`: uses `DurableEdit` (#397), the preserving default migration `migrateNonBiometric` (#208) and the ESP migration of #937.
- `android/.../EncryptedPreferencesMigration.java` (new), `android/src/test/.../EncryptedPreferencesMigrationTest.java` (new), `android/src/test/.../EncryptedPreferencesInitializeTest.java` (new): #937.
- `android/.../PreservingCipherMigration.java` (new), `android/src/test/.../PreservationTest.java` (new): publishes re-encrypted data and the `__daily_algorithm_*` markers in one commit (#208).
- `android/.../ciphers/StorageCipherFactory.java`: reads the markers from the data file first (#208).
- `android/.../ciphers/StorageCipherImplementationAES18.java`, `StorageCipherImplementationGCM.java`: a new wrapped key is committed and checked (#397).
- `android/src/test/.../FlutterSecureStorageConfigTest.java`, `android/src/test/.../ciphers/StorageCipherFactoryTest.java`: tests for the above.
- `.gitignore` (new), `pubspec.lock` (new): local files for running this package's own Dart tests. The app build does not read `pubspec.lock`; whether to keep it tracked is still open (#972).
