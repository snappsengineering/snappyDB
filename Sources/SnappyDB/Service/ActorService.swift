import Foundation
import os

// MARK: - ActorService

public actor ActorService<T: Storable & Sendable> {

    // MARK: - Properties

    private let persistence: Persistence
    private static var logger: Logger { Logger(subsystem: "com.snappsengineering.snappyDB", category: "\(T.self)") }

    private var _collection: Set<T>?
    private var index: [String: T] = [:]
    private let continuation: AsyncStream<Set<T>>.Continuation

    public private(set) var loadError: Error?

    public private(set) var lastError: Error?

    public let updates: AsyncStream<Set<T>>

    // MARK: - Lifecycle

    public init(
        destination: Destination = .local(.documentDirectory),
        fileName: String? = nil,
        fileExtension: String = "json",
        jsonEncoder: JSONEncoder = JSONEncoder(),
        jsonDecoder: JSONDecoder = JSONDecoder(),
        encryption: Encryption? = nil
    ) throws {
        let persistence = Persistence(
            destination: destination,
            fileName: fileName ?? "\(T.self)",
            fileExtension: fileExtension,
            encoder: jsonEncoder,
            decoder: jsonDecoder,
            encryption: encryption
        )
        let (collection, error) = Self.load(persistence: persistence)
        if let error { throw error }
        self.init(persistence: persistence, collection: collection, loadError: nil)
    }

    public static func softFailing(
        destination: Destination = .local(.documentDirectory),
        fileName: String? = nil,
        fileExtension: String = "json",
        jsonEncoder: JSONEncoder = JSONEncoder(),
        jsonDecoder: JSONDecoder = JSONDecoder(),
        encryption: Encryption? = nil
    ) -> ActorService<T> {
        let persistence = Persistence(
            destination: destination,
            fileName: fileName ?? "\(T.self)",
            fileExtension: fileExtension,
            encoder: jsonEncoder,
            decoder: jsonDecoder,
            encryption: encryption
        )
        let (collection, error) = load(persistence: persistence)
        return ActorService(persistence: persistence, collection: collection, loadError: error)
    }

    private init(persistence: Persistence, collection: Set<T>, loadError: Error?) {
        self.persistence = persistence
        self._collection = collection
        self.index = Self.makeIndex(collection)
        self.loadError = loadError
        let (stream, continuation) = AsyncStream<Set<T>>.makeStream(bufferingPolicy: .bufferingNewest(1))
        self.updates = stream
        self.continuation = continuation
        continuation.yield(collection)
    }

    deinit {
        continuation.finish()
    }

    // MARK: - Read

    public func fetchAll() -> Set<T> {
        loadIfNeeded()
        return _collection!
    }

    public func fetch(id: String) -> T? {
        loadIfNeeded()
        return index[id]
    }

    public func contains(id: String) -> Bool {
        loadIfNeeded()
        return index[id] != nil
    }

    public func fetchIds() -> Set<String> {
        loadIfNeeded()
        return Set(index.keys)
    }

    public var count: Int {
        loadIfNeeded()
        return _collection!.count
    }

    // MARK: - Write

    public func save(_ item: T) {
        loadIfNeeded()
        loadedCollection.upsert(item)
        index[item.id] = item
        persist()
    }

    public func save(_ items: Set<T>) {
        loadIfNeeded()
        items.forEach {
            loadedCollection.upsert($0)
            index[$0.id] = $0
        }
        persist()
    }

    public func delete(_ item: T) {
        loadIfNeeded()
        loadedCollection.remove(item)
        index.removeValue(forKey: item.id)
        persist()
    }

    public func delete(id: String) {
        guard let item = fetch(id: id) else { return }
        delete(item)
    }

    public func delete(_ items: Set<T>) {
        loadIfNeeded()
        items.forEach {
            loadedCollection.remove($0)
            index.removeValue(forKey: $0.id)
        }
        persist()
    }

    public func replace(_ items: Set<T>) {
        loadedCollection = items
        rebuildIndex()
        persist()
    }

    public func batch(_ changes: (inout Set<T>) -> Void) {
        loadIfNeeded()
        var updated = loadedCollection
        changes(&updated)
        loadedCollection = updated
        rebuildIndex()
        persist()
    }

    // MARK: - File management

    public func removeFile() throws {
        try persistence.remove()
    }

    public func reload() {
        let (collection, error) = Self.load(persistence: persistence)
        _collection = collection
        loadError = error
        rebuildIndex()
        continuation.yield(collection)
    }

    public func unload() {
        _collection = nil
        index = [:]
        loadError = nil
    }

    // MARK: - Private

    private var loadedCollection: Set<T> {
        get { _collection! }
        set { _collection = newValue }
    }

    private func loadIfNeeded() {
        guard _collection == nil else { return }
        let (collection, error) = Self.load(persistence: persistence)
        _collection = collection
        loadError = error
        rebuildIndex()
        continuation.yield(collection)
    }

    private func rebuildIndex() {
        index = Self.makeIndex(_collection!)
    }

    private static func makeIndex(_ collection: Set<T>) -> [String: T] {
        Dictionary(collection.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
    }

    func persist() {
        let snapshot = loadedCollection
        do {
            try persistence.write(Array(snapshot))
            lastError = nil
        } catch {
            lastError = error
            Self.logger.warning("snappyDB persist failed: \(error.localizedDescription)")
        }
        continuation.yield(snapshot)
    }

    private static func load(persistence: Persistence) -> (Set<T>, Error?) {
        do {
            let items = try persistence.readCollection(T.self)
            return (Set(items), nil)
        } catch StorageError.fileDoesNotExist {
            return ([], nil)
        } catch {
            logger.warning("snappyDB failed to load collection, starting empty: \(error.localizedDescription)")
            return ([], error)
        }
    }
}
