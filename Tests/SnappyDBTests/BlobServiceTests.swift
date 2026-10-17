import XCTest
@testable import SnappyDB

// MARK: - BlobServiceTests

final class BlobServiceTests: XCTestCase {

    // MARK: - Properties

    private var tempDir: URL!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SnappyBlobTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Tests

    func testStoreAndFetchData() throws {
        let service = BlobService(destination: .custom(tempDir.path), fileName: "blob", fileExtension: "bin")
        let data = Data("blob-bytes".utf8)
        try service.storeData(data)
        XCTAssertEqual(try service.fetchData(), data)
    }

    func testFetchThrowsWhenMissing() {
        let service = BlobService(destination: .custom(tempDir.path), fileName: "missing", fileExtension: "bin")
        XCTAssertFalse(service.exists())
        XCTAssertThrowsError(try service.fetchData())
    }

    func testExistsAfterStore() throws {
        let service = BlobService(destination: .custom(tempDir.path), fileName: "blob", fileExtension: "bin")
        XCTAssertFalse(service.exists())
        try service.storeData(Data("x".utf8))
        XCTAssertTrue(service.exists())
    }

    func testRemoveDeletesBlob() throws {
        let service = BlobService(destination: .custom(tempDir.path), fileName: "blob", fileExtension: "bin")
        try service.storeData(Data("x".utf8))
        try service.remove()
        XCTAssertThrowsError(try service.fetchData())
    }
}
