import CryptoKit
import Foundation

// MARK: - Data representation

extension SymmetricKey {

    var dataRepresentation: Data {
        withUnsafeBytes { Data($0) }
    }

    init?(dataRepresentation: Data) {
        guard !dataRepresentation.isEmpty else { return nil }
        self.init(data: dataRepresentation)
    }
}
