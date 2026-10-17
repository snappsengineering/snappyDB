import Foundation
import SnappyDB

// MARK: - StoredObject

struct StoredObject: Storable {

    // MARK: - Properties

    var id: String
    var name: String
    var value: Int

    // MARK: - Lifecycle

    init(id: String = StoredObject.generateHexID(), name: String = "test", value: Int = 0) {
        self.id = id
        self.name = name
        self.value = value
    }
}

// MARK: - LooseObject

struct LooseObject: Storable {

    // MARK: - Properties

    var id: String
    var name: String

    // MARK: - Equatable

    static func == (lhs: LooseObject, rhs: LooseObject) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
    }
}
