import Foundation

// MARK: - Storable

public protocol Storable: Codable, Hashable, Identifiable {
    var id: String { get }

    static var migrationDefaults: [String: Any] { get }
}

// MARK: - Default implementations

extension Storable {

    public static var migrationDefaults: [String: Any] { [:] }

    public static func generateHexID(length: Int = 12) -> String {
        let digits = "0123456789ABCDEF"
        return String((0..<length).map { _ in digits.randomElement()! })
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Set upsert

extension Set where Element: Storable {

    mutating func upsert(_ item: Element) {
        remove(item)
        insert(item)
    }
}
