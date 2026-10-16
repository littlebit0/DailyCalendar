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
        print("8 Keychain write policy cases passed")
    }
}
