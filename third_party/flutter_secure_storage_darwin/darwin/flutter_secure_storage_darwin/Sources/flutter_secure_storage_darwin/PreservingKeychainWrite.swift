import Security

// An update error is not evidence that an existing credential may be deleted.
internal enum PreservingKeychainWrite {
    static func perform(update: () -> OSStatus, add: () -> OSStatus) -> OSStatus {
        let status = update()
        guard status == errSecItemNotFound else { return status }
        let added = add()
        // Another writer may have inserted the item after the missing result.
        return added == errSecDuplicateItem ? update() : added
    }
}
