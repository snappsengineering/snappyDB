import Foundation

// MARK: - Storage

struct Storage: Sendable {

    // MARK: - Properties

    let location: Location

    func fileURL() throws -> URL {
        try location.fileURL()
    }

    // MARK: - Read and write

    func read() throws -> Data {
        try FileManager.default.data(at: location.fileURL())
    }

    func write(_ data: Data) throws {
        try data.writeAtomic(to: location.fileURL())
    }

    // MARK: - Remove

    func remove() throws {
        try FileManager.default.removeIfExists(at: location.fileURL())
    }
}
