import Foundation
import Security

@main struct KeychainWriteTests {
    static func main() {
        for error in [errSecInteractionNotAllowed, errSecAuthFailed, errSecDecode, errSecNotAvailable] {
            var adds = 0
            let status = PreservingKeychainWrite.perform(update: { error }, add: { adds += 1; return errSecSuccess })
            precondition(status == error && adds == 0)
        }
        var updates = 0
        let result = PreservingKeychainWrite.perform(update: {
            updates += 1
            return updates == 1 ? errSecItemNotFound : errSecSuccess
        }, add: { errSecDuplicateItem })
        precondition(result == errSecSuccess && updates == 2)
        precondition(PreservingKeychainWrite.perform(update: { errSecItemNotFound }, add: { errSecNotAvailable }) == errSecNotAvailable)
        precondition(PreservingKeychainWrite.perform(update: { errSecItemNotFound }, add: { errSecSuccess }) == errSecSuccess)
        precondition(PreservingKeychainWrite.perform(update: { errSecSuccess }, add: { fatalError("not called") }) == errSecSuccess)
        // iOS rejects an update whose search asks for results (errSecParam, -50), as every
        // Dart write did. The macOS file keychain accepts it, so the host can only prove
        // that the stripped query still finds and updates the item.
        let service = "daily.keychain.update.test.\(UUID().uuidString)"
        let base: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: "k",
        ]
        var item = base
        item[kSecValueData] = Data("one".utf8)
        let added = SecItemAdd(item as CFDictionary, nil)
        if added == errSecSuccess {
            defer { SecItemDelete(base as CFDictionary) }
            var asRequested = base
            asRequested[kSecReturnData] = true
            asRequested[kSecMatchLimit] = kSecMatchLimitOne
            let update = [kSecValueData: Data("two".utf8)] as CFDictionary
            let search = PreservingKeychainWrite.updateSearchQuery(asRequested)
            precondition(search[kSecReturnData] == nil && search[kSecMatchLimit] == nil)
            precondition(search[kSecAttrService] as? String == service)
            precondition(SecItemUpdate(search as CFDictionary, update) == errSecSuccess)
            var read = base
            read[kSecReturnData] = true
            var out: CFTypeRef?
            precondition(SecItemCopyMatching(read as CFDictionary, &out) == errSecSuccess)
            precondition((out as? Data).flatMap { String(data: $0, encoding: .utf8) } == "two")
            print("Keychain update with the stripped search query passed")
        } else {
            print("Keychain unavailable (\(added)); live update check skipped")
        }
        // #969: searches ignore accessibility; add and update still carry it.
        let withAccessibility: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword, kSecAttrService: "s", kSecAttrAccount: "k",
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock, kSecReturnData: true,
        ]
        precondition(PreservingKeychainWrite.matchQuery(withAccessibility)[kSecAttrAccessible] == nil)
        precondition(PreservingKeychainWrite.matchQuery(withAccessibility)[kSecAttrAccount] as? String == "k")
        precondition(PreservingKeychainWrite.updateSearchQuery(withAccessibility)[kSecAttrAccessible] == nil)
        let attributes = PreservingKeychainWrite.updateAttributes(value: Data("v".utf8), query: withAccessibility)
        precondition(attributes[kSecValueData] as? Data == Data("v".utf8))
        precondition((attributes[kSecAttrAccessible] as! CFString) == kSecAttrAccessibleAfterFirstUnlock)
        precondition(PreservingKeychainWrite.updateAttributes(value: Data(), query: base)[kSecAttrAccessible] == nil)
        print("13 Keychain write policy cases passed")
    }
}
