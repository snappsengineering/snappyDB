import Foundation

// MARK: - File I/O

extension FileManager {

    func exists(at url: URL) -> Bool {
        (try? url.checkResourceIsReachable()) == true
    }

    func ensureDirectory(at fileURL: URL) throws {
        let folder = fileURL.deletingLastPathComponent()
        let path = folder.path(percentEncoded: false)
        let values = try? folder.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
        if values?.isDirectory == true {
            return
        }
        if values?.isRegularFile == true {
            throw StorageError.directoryCreationFailed(path)
        }
        do {
            try createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            throw StorageError.directoryCreationFailed(path)
        }
    }

    func removeIfExists(at url: URL) throws {
        guard exists(at: url) else { return }
        do {
            try removeItem(at: url)
        } catch {
            throw StorageError.ioError(error)
        }
    }

    func data(at url: URL) throws -> Data {
        guard exists(at: url) else { throw StorageError.fileDoesNotExist }
        do {
            return try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            throw StorageError.ioError(error)
        }
    }
}

// MARK: - Atomic write

extension Data {

    func writeAtomic(to url: URL) throws {
        try FileManager.default.ensureDirectory(at: url)
        do {
            try write(to: url, options: .atomic)
        } catch {
            throw StorageError.ioError(error)
        }
    }
}
