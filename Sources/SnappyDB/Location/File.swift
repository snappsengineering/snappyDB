import Foundation

// MARK: - File

struct File: Sendable {

    // MARK: - Properties

    var name: String
    var fileExtension: String = "json"

    var fileName: String { "\(name).\(fileExtension)" }
}
