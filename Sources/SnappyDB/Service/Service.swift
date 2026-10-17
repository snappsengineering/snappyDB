import Foundation
import os

// MARK: - Service

open class Service<T: Storable> {

    // MARK: - Properties

    private let persistence: Persistence
    private static var logger: Logger { Logger(subsystem: "com.snappsengineering.snappyDB", category: "\(T.self)") }

    private var _collection: Set<T>?
    private var index: [String: T] = [:]

    public var collection: Set<T> {
        loadIfNeeded()
        return _collection!
    }

    public var count: Int {
        loadIfNeeded()
        return _collection!.count
    }

    public private(set) var loadError: Error?

    public private(set) var lastError: Error?

    // MARK: - Lifecycle

    public init(
        destination: Destination = .local(.documentDirectory),
        fileName: String? = nil,
        fileExtension: String = "json",
        jsonEncoder: JSONEncoder = JSONEncoder(),
        jsonDecoder: JSONDecoder = JSONDecoder(),
        encryption: Encryption? = nil
    ) {
        self.persistence = Persistence(
            destination: destination,
            fileName: fileName ?? "\(T.self)",
            fileExtension: fileExtension,
            encoder: jsonEncoder,
            decoder: jsonDecoder,
            encryption: encryption
        )
        let (collection, error) = Self.load(persistence: persistence)
        self._collection = collection
        self.index = Self.makeIndex(collection)
        self.loadError = error
    }

    // MARK: - Read

    public func fetchAll() -> Set<T> {
        collection
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

    // MARK: - Write

    open func save(_ item: T) {
        loadIfNeeded()
        loadedCollection.upsert(item)
        index[item.id] = item
        persist()
    }

    open func save(_ items: Set<T>) {
        loadIfNeeded()
        items.forEach {
            loadedCollection.upsert($0)
            index[$0.id] = $0
        }
        persist()
    }

    open func delete(_ item: T) {
        loadIfNeeded()
        loadedCollection.remove(item)
        index.removeValue(forKey: item.id)
        persist()
    }

    open func delete(id: String) {
        guard let item = fetch(id: id) else { return }
        delete(item)
    }

    open func delete(_ items: Set<T>) {
        loadIfNeeded()
        items.forEach {
            loadedCollection.remove($0)
            index.removeValue(forKey: $0.id)
        }
        persist()
    }

    open func replace(_ items: Set<T>) {
        loadedCollection = items
        rebuildIndex()
        persist()
    }

    open func batch(_ changes: (inout Set<T>) -> Void) {
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
    }

    public func unload() {
        _collection = nil
        index = [:]
        loadError = nil
    }

    // MARK: - Change hook

    open func collectionDidChange() {}

    // MARK: - Internal

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
    }

    private func rebuildIndex() {
        index = Self.makeIndex(_collection!)
    }

    private static func makeIndex(_ collection: Set<T>) -> [String: T] {
        Dictionary(collection.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
    }

    func persist() {
        do {
            try persistence.write(Array(loadedCollection))
            lastError = nil
        } catch {
            lastError = error
            Self.logger.warning("snappyDB persist failed: \(error.localizedDescription)")
        }
        collectionDidChange()
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
