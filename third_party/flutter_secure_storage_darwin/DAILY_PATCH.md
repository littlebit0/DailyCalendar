Based on flutter_secure_storage_darwin 0.3.2 (pub.dev), original license retained. Daily patches preserve stored credentials on failure. Explicit delete operations are unchanged. See docs/reviews/ISSUES_207_208_201_205_140_142_2026-10-16.md.
Keychain update fix: every SecItemUpdate searches without kSecReturnData/kSecMatchLimit (errSecParam -50 on iOS/data-protection keychains broke all credential writes after the preserve-on-failure patch). See tool/tests/keychain_preserving_write_test.swift.

Files that differ from upstream (#972; update this list when re-vendoring):
- `darwin/.../FlutterSecureStorage.swift`: preserve-on-failure write through `PreservingKeychainWrite` (#201) and the update search fix (above).
- `darwin/.../PreservingKeychainWrite.swift` (new): update-then-add without deleting the stored item (#201), tested by `tool/tests/keychain_preserving_write_test.swift`.
