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

    // SecItemUpdate rejects a search query that asks for results with
    // errSecParam (-50, "return data not supported by update"). Every call from
    // Dart carries kSecReturnData, so each update must search without it.
    static func updateSearchQuery(_ query: [CFString: Any]) -> [CFString: Any] {
        var search = query
        for key in [kSecReturnData, kSecReturnAttributes, kSecReturnRef, kSecReturnPersistentRef, kSecMatchLimit] {
            search.removeValue(forKey: key)
        }
        return search
    }
}
