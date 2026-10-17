import Foundation

// MARK: - Keychain

extension Encryption {

    // MARK: - Lifecycle

    public init(keychain store: KeychainKeyStore) throws {
        self.init(key: try store.loadOrCreate())
    }
}
