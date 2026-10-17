import XCTest
@testable import SnappyDB

// MARK: - DestinationTests

final class DestinationTests: XCTestCase {

    // MARK: - Custom

    func testCustomResolvesToGivenPath() throws {
        let file = File(name: "Note", fileExtension: "json")
        let url = try Destination.custom("/tmp/snappyDB-tests").url(for: file)
        XCTAssertEqual(url.path, "/tmp/snappyDB-tests/Note.json")
    }

    // MARK: - Local

    func testLocalResolvesUnderDirectory() throws {
        let file = File(name: "Note", fileExtension: "json")
        let url = try Destination.local(.cachesDirectory).url(for: file)
        XCTAssertTrue(url.path.contains("Caches"))
        XCTAssertTrue(url.lastPathComponent == "Note.json")
    }

    // MARK: - iCloud

    func testICloudThrowsWhenContainerUnavailable() {
        let file = File(name: "Note", fileExtension: "json")
        XCTAssertThrowsError(try Destination.iCloud.url(for: file)) { error in
            guard case DestinationError.urlNotFound = error else {
                return XCTFail("Expected urlNotFound, got \(error)")
            }
        }
    }
}

// MARK: - Equatable

extension Destination: Equatable {
    public static func == (lhs: Destination, rhs: Destination) -> Bool {
        switch (lhs, rhs) {
        case (.local(let a), .local(let b)): return a == b
        case (.iCloud, .iCloud): return true
        case (.custom(let a), .custom(let b)): return a == b
        default: return false
        }
    }
}
