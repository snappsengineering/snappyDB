import XCTest
@testable import SnappyDB

// MARK: - Fixtures

private struct LegacyItem: Storable {
    var id: String
    var name: String
}

private struct MigratedItem: Storable, Sendable {
    var id: String
    var name: String
    var color: String
    var rank: Int

    static var migrationDefaults: [String: Any] { ["color": "blue", "rank": 7] }
}

private struct UnserializableDefaultsItem: Storable {
    var id: String
    var extra: String

    static var migrationDefaults: [String: Any] { ["extra": Date()] }
}

// MARK: - Tests

// MARK: - MigrationTests

final class MigrationTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SnappyMigrationTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Helpers

    private func writeLegacy(_ items: Set<LegacyItem>, encryption: Encryption? = nil) {
        Service<LegacyItem>(destination: .custom(tempDir.path), fileName: "MigratedItem", encryption: encryption)
            .replace(items)
    }

    private func writeRaw(_ json: String, fileName: String = "MigratedItem") throws {
        try json.write(to: tempDir.appendingPathComponent("\(fileName).json"), atomically: true, encoding: .utf8)
    }

    private func makeService(encryption: Encryption? = nil) -> Service<MigratedItem> {
        Service<MigratedItem>(destination: .custom(tempDir.path), encryption: encryption)
    }

    // MARK: - Service

    func testMissingKeysFilledFromDefaults() {
        writeLegacy([LegacyItem(id: "1", name: "one")])
        let service = makeService()
        XCTAssertEqual(service.fetch(id: "1")?.color, "blue")
        XCTAssertNil(service.loadError)
        XCTAssertEqual(service.fetch(id: "1")?.rank, 7)
        XCTAssertEqual(service.fetch(id: "1")?.name, "one")
    }

    func testNullKeysFilledFromDefaults() throws {
        try writeRaw(#"[{"id":"1","name":"one","color":null,"rank":null}]"#)
        let service = makeService()
        XCTAssertEqual(service.fetch(id: "1")?.color, "blue")
        XCTAssertNil(service.loadError)
        XCTAssertEqual(service.fetch(id: "1")?.rank, 7)
    }

    func testOnDiskValuesWinOverDefaults() throws {
        try writeRaw(#"[{"id":"1","name":"one","color":"red","rank":3}]"#)
        let service = makeService()
        XCTAssertEqual(service.fetch(id: "1")?.color, "red")
        XCTAssertEqual(service.fetch(id: "1")?.rank, 3)
    }

    func testUnknownKeysAreIgnored() throws {
        try writeRaw(#"[{"id":"1","name":"one","legacyField":true}]"#)
        let service = makeService()
        XCTAssertEqual(service.count, 1)
        XCTAssertNil(service.loadError)
    }

    func testEveryItemInCollectionIsMigrated() throws {
        try writeRaw(#"[{"id":"1","name":"a"},{"id":"2","name":"b","color":"green"}]"#)
        let service = makeService()
        XCTAssertEqual(service.fetch(id: "1")?.color, "blue")
        XCTAssertEqual(service.fetch(id: "2")?.color, "green")
    }

    func testEmptyDefaultsIsPlainDecode() {
        try? #"[{"id":"1","name":"only-name"}]"#.write(
            to: tempDir.appendingPathComponent("StoredObject.json"), atomically: true, encoding: .utf8)
        let service = Service<StoredObject>(destination: .custom(tempDir.path))
        XCTAssertEqual(service.count, 0)
        XCTAssertNotNil(service.loadError)
    }

    func testMigratedShapeIsPersistedOnNextWrite() throws {
        writeLegacy([LegacyItem(id: "1", name: "one")])
        let service = makeService()
        service.save(MigratedItem(id: "2", name: "two", color: "red", rank: 1))

        let raw = try Data(contentsOf: tempDir.appendingPathComponent("MigratedItem.json"))
        let objects = try XCTUnwrap(JSONSerialization.jsonObject(with: raw) as? [[String: Any]])
        XCTAssertEqual(objects.count, 2)
        XCTAssertTrue(objects.allSatisfy { $0["color"] != nil && $0["rank"] != nil })
    }

    func testEncryptedFileMigrates() {
        let encryption = Encryption(key: Encryption.generateKey())
        writeLegacy([LegacyItem(id: "1", name: "one")], encryption: encryption)
        let service = makeService(encryption: encryption)
        XCTAssertEqual(service.fetch(id: "1")?.color, "blue")
        XCTAssertNil(service.loadError)
    }

    // MARK: - Failure modes

    func testMalformedJSONStillSurfacesLoadError() throws {
        try writeRaw("this is not json")
        let service = makeService()
        XCTAssertEqual(service.count, 0)
        XCTAssertNotNil(service.loadError)
    }

    func testTopLevelObjectInsteadOfArraySurfacesLoadError() throws {
        try writeRaw(#"{"id":"1","name":"one"}"#)
        let service = makeService()
        XCTAssertEqual(service.count, 0)
        XCTAssertNotNil(service.loadError)
    }

    func testUnserializableDefaultsFallBackToPlainDecode() throws {
        try writeRaw(#"[{"id":"1"}]"#, fileName: "UnserializableDefaultsItem")
        let service = Service<UnserializableDefaultsItem>(destination: .custom(tempDir.path))
        XCTAssertEqual(service.count, 0)
        XCTAssertNotNil(service.loadError)
    }

    // MARK: - ActorService

    func testActorServiceMigrates() async throws {
        writeLegacy([LegacyItem(id: "1", name: "one")])
        let service = try ActorService<MigratedItem>(destination: .custom(tempDir.path))
        let item = await service.fetch(id: "1")
        XCTAssertEqual(item?.color, "blue")
        XCTAssertEqual(item?.rank, 7)
        let error = await service.loadError
        XCTAssertNil(error)
    }
}
