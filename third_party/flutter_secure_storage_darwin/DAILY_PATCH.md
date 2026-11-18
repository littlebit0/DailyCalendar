Based on flutter_secure_storage_darwin 0.3.2 (pub.dev), original license retained. Daily patches preserve stored credentials on failure. Explicit delete operations are unchanged. See docs/reviews/ISSUES_207_208_201_205_140_142_2026-10-16.md.
Keychain update fix: every SecItemUpdate searches without kSecReturnData/kSecMatchLimit (errSecParam -50 on iOS/data-protection keychains broke all credential writes after the preserve-on-failure patch). See tool/tests/keychain_preserving_write_test.swift.
Accessibility search fix (#969): read, readAll, containsKey and the SecItemUpdate search omit kSecAttrAccessible, so a key stored with another accessibility is still found; the add query and the update attributes carry the requested accessibility, so a write moves the item to it. Secure Enclave paths are unchanged.

Files that differ from upstream (#972; update this list when re-vendoring):
- `darwin/.../FlutterSecureStorage.swift`: preserve-on-failure write through `PreservingKeychainWrite` (#201) and the accessibility search fix (#969, above).
- `darwin/.../PreservingKeychainWrite.swift` (new): update-then-add without deleting the stored item (#201), tested by `tool/tests/keychain_preserving_write_test.swift`.
