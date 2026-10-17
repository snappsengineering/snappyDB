import Foundation

// MARK: - Location

struct Location: Sendable {

    // MARK: - Properties

    var destination: Destination
    var file: File
}

// MARK: - File URL

extension Location {

    func fileURL() throws -> URL {
        try destination.url(for: file).standardizedFileURL
    }
}
