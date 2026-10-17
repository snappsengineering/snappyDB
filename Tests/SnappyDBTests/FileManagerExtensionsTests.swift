import XCTest
@testable import SnappyDB

// MARK: - FileManagerExtensionsTests

final class FileManagerExtensionsTests: XCTestCase {

    // MARK: - Properties

    private var tempDir: URL!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SnappyFMTests-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - exists(at:)

    func testExistsAtURLFalseWhenMissing() {
        let missing = tempDir.appendingPathComponent("missing.json")
        XCTAssertFalse(FileManager.default.exists(at: missing))
    }

    func testExistsAtURLTrueForFile() throws {
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("present.json")
        try Data("x".utf8).write(to: file)
        XCTAssertTrue(FileManager.default.exists(at: file))
    }

    func testExistsAndDataAtURLWithSpacesInPath() throws {
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("hello world.json")
        let payload = Data("payload".utf8)
        try payload.write(to: file)
        XCTAssertTrue(FileManager.default.exists(at: file))
        XCTAssertEqual(try FileManager.default.data(at: file), payload)
    }

    // MARK: - ensureDirectory

    func testEnsureDirectoryNoOpWhenParentAlreadyExists() throws {
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let fileURL = tempDir.appendingPathComponent("file.json")
        XCTAssertNoThrow(try FileManager.default.ensureDirectory(at: fileURL))
    }

    func testEnsureDirectoryCreatesMissingFolder() throws {
        let fileURL = tempDir.appendingPathComponent("nested/file.json")
        try Data("x".utf8).writeAtomic(to: fileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    // MARK: - removeIfExists

    func testRemoveIfExistsNoOpWhenMissing() throws {
        let missing = tempDir.appendingPathComponent("nope.json")
        XCTAssertNoThrow(try FileManager.default.removeIfExists(at: missing))
    }

    func testRemoveIfExistsThrowsIOErrorWhenRemoveFails() throws {
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let url = tempDir.appendingPathComponent("immutable")
        try Data("x".utf8).write(to: url)
        try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: url.path)
        defer { try? FileManager.default.setAttributes([.immutable: false], ofItemAtPath: url.path) }
        XCTAssertThrowsError(try FileManager.default.removeIfExists(at: url)) { error in
            guard case StorageError.ioError = error else {
                return XCTFail("Expected ioError, got \(error)")
            }
        }
    }

    func testWriteAtomicThrowsDirectoryCreationFailedWhenParentIsFile() throws {
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let blocker = tempDir.appendingPathComponent("blocker")
        try Data("x".utf8).write(to: blocker)
        let blockedFile = blocker.appendingPathComponent("nested.json")
        XCTAssertThrowsError(try Data("y".utf8).writeAtomic(to: blockedFile)) { error in
            guard case StorageError.directoryCreationFailed = error else {
                return XCTFail("Expected directoryCreationFailed, got \(error)")
            }
        }
    }

    func testWriteAtomicThrowsIOErrorWhenWriteFails() throws {
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let readOnly = tempDir.appendingPathComponent("readonly")
        try FileManager.default.createDirectory(at: readOnly, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: readOnly.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: readOnly.path) }
        let fileURL = readOnly.appendingPathComponent("out.json")
        XCTAssertThrowsError(try Data("y".utf8).writeAtomic(to: fileURL)) { error in
            guard case StorageError.ioError = error else {
                return XCTFail("Expected ioError, got \(error)")
            }
        }
    }

    func testEnsureDirectoryThrowsWhenParentIsAFile() throws {
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let fileParent = tempDir.appendingPathComponent("not-a-dir")
        try Data("x".utf8).write(to: fileParent)
        let child = fileParent.appendingPathComponent("child.json")
        XCTAssertThrowsError(try FileManager.default.ensureDirectory(at: child)) { error in
            guard case StorageError.directoryCreationFailed = error else {
                return XCTFail("Expected directoryCreationFailed, got \(error)")
            }
        }
    }

    // MARK: - data(at:)

    func testDataAtThrowsFileDoesNotExist() {
        let missing = tempDir.appendingPathComponent("nope.json")
        XCTAssertThrowsError(try FileManager.default.data(at: missing)) { error in
            guard case StorageError.fileDoesNotExist = error else {
                return XCTFail("Expected fileDoesNotExist, got \(error)")
            }
        }
    }

    func testDataAtThrowsIOErrorForDirectory() throws {
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        XCTAssertThrowsError(try FileManager.default.data(at: tempDir)) { error in
            guard case StorageError.ioError = error else {
                return XCTFail("Expected ioError, got \(error)")
            }
        }
    }

    // MARK: - iCloud URL

    func testUbiquityDocumentsURLThrowsWhenContainerUnavailable() {
        XCTAssertThrowsError(
            try FileManager.default.ubiquityDocumentsURL(containerURLProvider: { _ in nil })
        ) { error in
            guard case DestinationError.urlNotFound = error else {
                return XCTFail("Expected urlNotFound, got \(error)")
            }
        }
    }

    func testUbiquityDocumentsURLAppendsDocumentsFolder() throws {
        let url = try FileManager.default.ubiquityDocumentsURL(
            folderName: "Documents",
            containerURLProvider: { _ in URL(fileURLWithPath: "/tmp/fake-icloud") }
        )
        XCTAssertEqual(url.path, "/tmp/fake-icloud/Documents")
    }

    // MARK: - ensureDirectory failure

    func testEnsureDirectoryThrowsWhenBlockedByFile() throws {
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let blocker = tempDir.appendingPathComponent("blocker")
        try Data("x".utf8).write(to: blocker)
        let blockedFileURL = blocker.appendingPathComponent("nested/file.json")
        XCTAssertThrowsError(try FileManager.default.ensureDirectory(at: blockedFileURL)) { error in
            guard case StorageError.directoryCreationFailed = error else {
                return XCTFail("Expected directoryCreationFailed, got \(error)")
            }
        }
    }
}
