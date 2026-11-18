Based on flutter_secure_storage 10.3.1 (pub.dev), original license retained. Daily patches preserve stored credentials on failure. Explicit delete operations are unchanged. See docs/reviews/ISSUES_207_208_201_205_140_142_2026-10-16.md.

- #970: `StorageCipherFactory` treats a store with no algorithm markers, no stored values and no legacy wrapped AES-CBC key as a fresh install and uses the current algorithms; `initializeStorageCipher` commits the current markers to the data file before any key or value is created. Stores with legacy data keep the v9.2.4 default migration.
