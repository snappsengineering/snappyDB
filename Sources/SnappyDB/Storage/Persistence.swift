import Foundation

// MARK: - Persistence

struct Persistence: Sendable {

    // MARK: - Properties

    private let storage: Storage
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let encryption: Encryption?

    // MARK: - Lifecycle

    init(
        destination: Destination,
        fileName: String,
        fileExtension: String,
        encoder: JSONEncoder,
        decoder: JSONDecoder,
        encryption: Encryption?
    ) {
        self.storage = Storage(location: Location(
            destination: destination,
            file: File(name: fileName, fileExtension: fileExtension)
        ))
        self.encoder = encoder
        self.decoder = decoder
        self.encryption = encryption
    }

    // MARK: - Read and write

    func read<T: Decodable>(_ type: T.Type) throws -> T {
        let payload = try storage.read()
        let data = try Self.open(payload, encryption: encryption)
        return try decoder.decodePayload(type, from: data)
    }

    func readCollection<T: Storable>(_ type: T.Type) throws -> [T] {
        let payload = try storage.read()
        let data = try Self.open(payload, encryption: encryption)
        let defaults = T.migrationDefaults
        guard !defaults.isEmpty else {
            return try decoder.decodePayload([T].self, from: data)
        }
        return try decoder.decodePayload([T].self, from: Self.applying(defaults, to: data))
    }

    func write<T: Encodable>(_ value: T) throws {
        let data = try encoder.encodePayload(value)
        try storage.write(try Self.seal(data, encryption: encryption))
    }

    // MARK: - Remove

    func remove() throws {
        try storage.remove()
    }

    // MARK: - Helpers

    private static func seal(_ data: Data, encryption: Encryption?) throws -> Data {
        try encryption.sealedPayload(from: data)
    }

    private static func open(_ data: Data, encryption: Encryption?) throws -> Data {
        try encryption.openedPayload(from: data)
    }

    // MARK: - Migration

    private static func applying(_ defaults: [String: Any], to data: Data) -> Data {
        guard let objects = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else {
            return data
        }
        let merged = objects.map { object in
            defaults.reduce(into: object) { result, entry in
                if result[entry.key] == nil || result[entry.key] is NSNull {
                    result[entry.key] = entry.value
                }
            }
        }
        guard JSONSerialization.isValidJSONObject(merged),
              let migrated = try? JSONSerialization.data(withJSONObject: merged) else {
            return data
        }
        return migrated
    }
}
