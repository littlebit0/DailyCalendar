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
        var search = matchQuery(query)
        for key in [kSecReturnData, kSecReturnAttributes, kSecReturnRef, kSecReturnPersistentRef, kSecMatchLimit] {
            search.removeValue(forKey: key)
        }
        return search
    }

    // Daily (#969): accessibility is not part of an item's identity, so a
    // search that includes it misses the same key stored with another
    // accessibility (read gives nil, add gives errSecDuplicateItem). Search
    // without it; set it only when adding or updating an item.
    static func matchQuery(_ query: [CFString: Any]) -> [CFString: Any] {
        var search = query
        search.removeValue(forKey: kSecAttrAccessible)
        return search
    }

    static func updateAttributes(value: Any, query: [CFString: Any]) -> [CFString: Any] {
        var attributes: [CFString: Any] = [kSecValueData: value]
        if let accessible = query[kSecAttrAccessible] {
            attributes[kSecAttrAccessible] = accessible
        }
        return attributes
    }
}
