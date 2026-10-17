import Foundation

// MARK: - SingleValueService

open class SingleValueService<T: Codable> {

    // MARK: - Properties

    private let persistence: Persistence
    private let destination: Destination
    private let file: File

    public private(set) var lastReadError: Error?

    // MARK: - Lifecycle

    public init(
        destination: Destination = .local(.documentDirectory),
        fileName: String,
        fileExtension: String = "json",
        jsonEncoder: JSONEncoder = JSONEncoder(),
        jsonDecoder: JSONDecoder = JSONDecoder(),
        encryption: Encryption? = nil
    ) {
        self.destination = destination
        self.file = File(name: fileName, fileExtension: fileExtension)
        self.persistence = Persistence(
            destination: destination,
            fileName: fileName,
            fileExtension: fileExtension,
            encoder: jsonEncoder,
            decoder: jsonDecoder,
            encryption: encryption
        )
    }

    // MARK: - Read

    public func exists() -> Bool {
        guard let url = try? Location(destination: destination, file: file).fileURL() else { return false }
        return FileManager.default.exists(at: url)
    }

    public func load() throws -> T? {
        do {
            return try persistence.read(T.self)
        } catch StorageError.fileDoesNotExist {
            return nil
        }
    }

    public func fetch() -> T? {
        lastReadError = nil
        do {
            return try load()
        } catch {
            lastReadError = error
            return nil
        }
    }

    // MARK: - Write

    public func save(_ value: T) throws {
        try persistence.write(value)
    }

    public func remove() throws {
        try persistence.remove()
    }
}
