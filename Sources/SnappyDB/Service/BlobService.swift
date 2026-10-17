import Foundation

// MARK: - BlobService

open class BlobService {

    // MARK: - Properties

    private let storage: Storage

    // MARK: - Lifecycle

    public init(destination: Destination, fileName: String, fileExtension: String) {
        self.storage = Storage(location: Location(
            destination: destination,
            file: File(name: fileName, fileExtension: fileExtension)
        ))
    }

    // MARK: - Read and write

    public func exists() -> Bool {
        guard let url = try? storage.fileURL() else { return false }
        return FileManager.default.exists(at: url)
    }

    public func fetchData() throws -> Data {
        try storage.read()
    }

    public func storeData(_ data: Data) throws {
        try storage.write(data)
    }

    // MARK: - Remove

    public func remove() throws {
        try storage.remove()
    }
}
