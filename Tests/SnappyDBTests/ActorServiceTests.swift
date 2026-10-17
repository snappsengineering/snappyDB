import XCTest
@testable import SnappyDB

// MARK: - ActorServiceTests

final class ActorServiceTests: XCTestCase {

    // MARK: - Properties

    private var tempDir: URL!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SnappyActorTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Read and write

    func testStep1APISurface() async throws {
        let svc = try ActorService<StoredObject>(destination: .custom(tempDir.path))
        let a = StoredObject(name: "a", value: 1)
        let b = StoredObject(name: "b", value: 2)
        await svc.replace([a])
        await svc.batch { $0.insert(b) }
        await svc.save(StoredObject(name: "c", value: 3))
        await svc.save([StoredObject(name: "d", value: 4)])
        await svc.delete(a)
        await svc.delete([b])
        await svc.delete(id: "missing")
        _ = await svc.contains(id: "missing")
        _ = await svc.fetchIds()
        _ = await svc.count
        _ = await svc.fetch(id: "missing")
        await svc.reload()
        await svc.unload()
        try await svc.removeFile()
    }

    func testSaveAndFetch() async throws {
        let svc = try ActorService<StoredObject>(destination: .custom(tempDir.path))
        let obj = StoredObject(name: "async", value: 1)
        await svc.save(obj)
        let all = await svc.fetchAll()
        XCTAssertEqual(all.count, 1)
        let fetched = await svc.fetch(id: obj.id)
        XCTAssertEqual(fetched?.name, "async")
    }

    func testDelete() async throws {
        let svc = try ActorService<StoredObject>(destination: .custom(tempDir.path))
        let obj = StoredObject(name: "del", value: 0)
        await svc.save(obj)
        await svc.delete(obj)
        let all = await svc.fetchAll()
        XCTAssertTrue(all.isEmpty)
    }

    func testDeleteByIdContainsAndReload() async throws {
        let svc = try ActorService<StoredObject>(destination: .custom(tempDir.path))
        let obj = StoredObject(name: "actor-id", value: 2)
        await svc.save(obj)
        let hasId = await svc.contains(id: obj.id)
        XCTAssertTrue(hasId)
        await svc.delete(id: obj.id)
        let stillThere = await svc.contains(id: obj.id)
        XCTAssertFalse(stillThere)
        await svc.save(StoredObject(name: "reload-me", value: 3))
        await svc.reload()
        let count = await svc.count
        XCTAssertEqual(count, 1)
    }

    func testReplaceWithoutPriorLoad() async throws {
        let svc = try ActorService<StoredObject>(destination: .custom(tempDir.path))
        let item = StoredObject(name: "fresh-replace", value: 1)
        await svc.replace([item])
        let count = await svc.count
        XCTAssertEqual(count, 1)
    }

    func testWriteFailureStillYieldsSnapshot() async throws {
        let blocker = tempDir.appendingPathComponent("blocker")
        try Data("x".utf8).write(to: blocker)
        let svc = try ActorService<StoredObject>(destination: .custom(blocker.path))
        var iterator = await svc.updates.makeAsyncIterator()
        let initial = await iterator.next()
        XCTAssertEqual(initial, [])
        await svc.save(StoredObject(name: "a", value: 1))
        let afterFailedSave = await iterator.next()
        XCTAssertEqual(afterFailedSave?.count, 1)
    }

    func testLastErrorClearsOnSuccessfulPersist() async throws {
        let svc = try ActorService<StoredObject>(destination: .custom(tempDir.path))
        await svc.save(StoredObject(name: "a", value: 1))
        let err = await svc.lastError
        XCTAssertNil(err)
    }

    func testLastErrorSetWhenWriteFails() async throws {
        let blocker = tempDir.appendingPathComponent("blocker")
        try Data("x".utf8).write(to: blocker)
        let svc = try ActorService<StoredObject>(destination: .custom(blocker.path))
        await svc.save(StoredObject(name: "a", value: 1))
        let err = await svc.lastError
        XCTAssertNotNil(err)
    }

    func testSaveMultiple() async throws {
        let svc = try ActorService<StoredObject>(destination: .custom(tempDir.path))
        let items: Set<StoredObject> = [
            StoredObject(name: "a", value: 1),
            StoredObject(name: "b", value: 2)
        ]
        await svc.save(items)
        let all = await svc.fetchAll()
        XCTAssertEqual(all.count, 2)
    }

    func testRemoveFile() async throws {
        let svc = try ActorService<StoredObject>(destination: .custom(tempDir.path))
        await svc.save(StoredObject(name: "temp", value: 0))
        try await svc.removeFile()
        let reloaded = try ActorService<StoredObject>(destination: .custom(tempDir.path))
        let all = await reloaded.fetchAll()
        XCTAssertTrue(all.isEmpty)
    }

    func testDeleteMultiple() async throws {
        let svc = try ActorService<StoredObject>(destination: .custom(tempDir.path))
        let a = StoredObject(name: "a", value: 1)
        let b = StoredObject(name: "b", value: 2)
        let c = StoredObject(name: "c", value: 3)
        await svc.save([a, b, c])
        await svc.delete([a, c])
        let all = await svc.fetchAll()
        XCTAssertEqual(all.count, 1)
        let fetchedB = await svc.fetch(id: b.id)
        XCTAssertEqual(fetchedB?.name, "b")

        let reloaded = try ActorService<StoredObject>(destination: .custom(tempDir.path))
        let reloadedAll = await reloaded.fetchAll()
        XCTAssertEqual(reloadedAll.count, 1)
    }

    func testReplaceSwapsCollection() async throws {
        let svc = try ActorService<StoredObject>(destination: .custom(tempDir.path))
        let old = StoredObject(name: "old", value: 1)
        await svc.save(old)
        let replacement = StoredObject(name: "new", value: 2)
        await svc.replace([replacement])
        let oldFetched = await svc.fetch(id: old.id)
        XCTAssertNil(oldFetched)
        let replacementFetched = await svc.fetch(id: replacement.id)
        XCTAssertEqual(replacementFetched?.name, "new")

        let reloaded = try ActorService<StoredObject>(destination: .custom(tempDir.path))
        let reloadedAll = await reloaded.fetchAll()
        XCTAssertEqual(reloadedAll.count, 1)
        let oldOnReload = await reloaded.fetch(id: old.id)
        XCTAssertNil(oldOnReload)
    }

    func testBatchMutatesAndPersists() async throws {
        let svc = try ActorService<StoredObject>(destination: .custom(tempDir.path))
        let keep = StoredObject(name: "keep", value: 1)
        let drop = StoredObject(name: "drop", value: 2)
        await svc.save([keep, drop])
        await svc.batch { items in
            items.remove(drop)
            items.insert(StoredObject(name: "added", value: 3))
        }
        let count = await svc.count
        XCTAssertEqual(count, 2)
        let reloaded = try ActorService<StoredObject>(destination: .custom(tempDir.path))
        let reloadedCount = await reloaded.count
        XCTAssertEqual(reloadedCount, 2)
    }

    func testCountMatchesFetchAll() async throws {
        let svc = try ActorService<StoredObject>(destination: .custom(tempDir.path))
        let emptyCount = await svc.count
        XCTAssertEqual(emptyCount, 0)
        await svc.save(StoredObject(name: "a", value: 1))
        let count = await svc.count
        let fetched = await svc.fetchAll()
        XCTAssertEqual(count, fetched.count)
        await svc.unload()
        let countAfterUnload = await svc.count
        XCTAssertEqual(countAfterUnload, 1)
    }

    func testFetchIdNilWhenMissing() async throws {
        let svc = try ActorService<StoredObject>(destination: .custom(tempDir.path))
        let missing = await svc.fetch(id: "missing")
        XCTAssertNil(missing)
        let obj = StoredObject(name: "x", value: 1)
        await svc.save(obj)
        await svc.delete(obj)
        let afterDelete = await svc.fetch(id: obj.id)
        XCTAssertNil(afterDelete)
    }

    func testUnloadThenCorruptFileSoftFailsOnNextAccess() async throws {
        let svc = try ActorService<StoredObject>(destination: .custom(tempDir.path))
        let errorBeforeUnload = await svc.loadError
        XCTAssertNil(errorBeforeUnload)

        try corruptFile()
        await svc.unload()
        let errorAfterUnload = await svc.loadError
        XCTAssertNil(errorAfterUnload)

        _ = await svc.count
        let loadErrorAfterCount = await svc.loadError
        XCTAssertNotNil(loadErrorAfterCount)
        let all = await svc.fetchAll()
        XCTAssertTrue(all.isEmpty)
    }

    func testUnloadDropsCacheAndReloadsFromDisk() async throws {
        let svc = try ActorService<StoredObject>(destination: .custom(tempDir.path))
        await svc.save(StoredObject(name: "cached", value: 1))
        await svc.unload()
        let all = await svc.fetchAll()
        XCTAssertEqual(all.count, 1)
    }

    func testUnloadThenExternalCorruptionSurfacesOnNextRead() async throws {
        let svc = try ActorService<StoredObject>(destination: .custom(tempDir.path))
        await svc.save(StoredObject(name: "good", value: 1))
        await svc.unload()

        let storage = Storage(location: Location(destination: .custom(tempDir.path), file: File(name: "StoredObject")))
        try storage.write(Data("corrupt".utf8))

        let all = await svc.fetchAll()
        XCTAssertTrue(all.isEmpty)
        let loadError = await svc.loadError
        XCTAssertNotNil(loadError)
    }

    func testUpdatesStreamYieldsLoadedCollectionAtInit() async throws {
        let seed = try ActorService<StoredObject>(destination: .custom(tempDir.path))
        await seed.save(StoredObject(name: "seed", value: 0))

        let svc = try ActorService<StoredObject>(destination: .custom(tempDir.path))
        var iterator = await svc.updates.makeAsyncIterator()
        let initial = await iterator.next()
        XCTAssertEqual(initial?.count, 1)

        await svc.save(StoredObject(name: "stream", value: 1))
        let afterSave = await iterator.next()
        XCTAssertEqual(afterSave?.count, 2)

        await svc.unload()
        _ = await svc.fetchAll()
        let afterReload = await iterator.next()
        XCTAssertEqual(afterReload?.count, 2)
    }

    // MARK: - Eager load and errors (init throws)

    func testInitThrowsOnCorruptFileAndLeavesItUntouched() throws {
        try corruptFile()
        XCTAssertThrowsError(try ActorService<StoredObject>(destination: .custom(tempDir.path)))
        XCTAssertEqual(try corruptStorage().read(), Data("not json".utf8))
    }

    func testInitThrowsWhenEncryptionKeyIsWrong() async throws {
        let writer = try ActorService<StoredObject>(
            destination: .custom(tempDir.path),
            encryption: Encryption(key: Encryption.generateKey())
        )
        await writer.save(StoredObject(name: "secret", value: 1))
        XCTAssertThrowsError(try ActorService<StoredObject>(
            destination: .custom(tempDir.path),
            encryption: Encryption(key: Encryption.generateKey())
        ))
    }

    func testInitLoadsExistingFileEagerly() async throws {
        let seed = try ActorService<StoredObject>(destination: .custom(tempDir.path))
        await seed.save(StoredObject(name: "seed", value: 0))
        let svc = try ActorService<StoredObject>(destination: .custom(tempDir.path))
        let loadError = await svc.loadError
        XCTAssertNil(loadError)
        let all = await svc.fetchAll()
        XCTAssertEqual(all.count, 1)
    }

    // MARK: - softFailing

    func testSoftFailingSetsLoadErrorAndStaysEmpty() async throws {
        try corruptFile()
        let svc = ActorService<StoredObject>.softFailing(destination: .custom(tempDir.path))
        let loadError = await svc.loadError
        XCTAssertNotNil(loadError)
        let all = await svc.fetchAll()
        XCTAssertTrue(all.isEmpty)
        XCTAssertEqual(try corruptStorage().read(), Data("not json".utf8))
    }

    func testSoftFailingMissingFileHasNoError() async throws {
        let svc = ActorService<StoredObject>.softFailing(destination: .custom(tempDir.path))
        let loadError = await svc.loadError
        XCTAssertNil(loadError)
        let count = await svc.count
        XCTAssertEqual(count, 0)
    }

    func testSoftFailingLoadsExistingFile() async throws {
        let seed = try ActorService<StoredObject>(destination: .custom(tempDir.path))
        await seed.save(StoredObject(name: "seed", value: 0))
        let svc = ActorService<StoredObject>.softFailing(destination: .custom(tempDir.path))
        let count = await svc.count
        XCTAssertEqual(count, 1)
    }

    func testSoftFailingHonorsFileNameAndExtension() async throws {
        let svc = ActorService<StoredObject>.softFailing(
            destination: .custom(tempDir.path),
            fileName: "custom",
            fileExtension: "dat"
        )
        await svc.save(StoredObject(name: "x", value: 1))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("custom.dat").path))
    }

    // MARK: - Duplicate ids (custom ==)

    func testCountAndFetchSurviveItemsSharingAnId() async throws {
        let svc = try ActorService<LooseObject>(destination: .custom(tempDir.path))
        await svc.save(LooseObject(id: "dup", name: "first"))
        await svc.save(LooseObject(id: "dup", name: "second"))
        let count = await svc.count
        XCTAssertEqual(count, 2)
        let fetched = await svc.fetch(id: "dup")
        XCTAssertNotNil(fetched)
        let reloaded = try ActorService<LooseObject>(destination: .custom(tempDir.path))
        let reloadedCount = await reloaded.count
        XCTAssertEqual(reloadedCount, 2)
    }

    func testMissingFileReturnsEmptyCollection() async throws {
        let svc = try ActorService<StoredObject>(destination: .custom(tempDir.path))
        let all = await svc.fetchAll()
        XCTAssertTrue(all.isEmpty)
        let loadError = await svc.loadError
        XCTAssertNil(loadError)
    }

    // MARK: - Helpers

    private func corruptStorage() -> Storage {
        Storage(location: Location(destination: .custom(tempDir.path), file: File(name: "StoredObject")))
    }

    private func corruptFile() throws {
        try corruptStorage().write(Data("not json".utf8))
    }

    // MARK: - Concurrency

    func testConcurrentSavesOfDistinctItemsAllPersist() async throws {
        let svc = try ActorService<StoredObject>(destination: .custom(tempDir.path))
        let items = (0..<50).map { StoredObject(name: "item-\($0)", value: $0) }

        await withTaskGroup(of: Void.self) { group in
            for item in items {
                group.addTask { await svc.save(item) }
            }
        }

        let count = await svc.count
        XCTAssertEqual(count, items.count)
        for item in items {
            let fetched = await svc.fetch(id: item.id)
            XCTAssertEqual(fetched?.value, item.value)
        }

        let reloaded = try ActorService<StoredObject>(destination: .custom(tempDir.path))
        let reloadedCount = await reloaded.count
        XCTAssertEqual(reloadedCount, items.count, "every concurrent save must have persisted to disk")
    }

    func testConcurrentSaveAndDeleteOfSameItemStaysConsistent() async throws {
        let svc = try ActorService<StoredObject>(destination: .custom(tempDir.path))
        let shared = StoredObject(id: "shared", name: "shared", value: 0)

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<25 {
                group.addTask { await svc.save(StoredObject(id: "shared", name: "v\(i)", value: i)) }
                group.addTask { await svc.delete(shared) }
            }
        }

        let count = await svc.count
        let all = await svc.fetchAll()
        XCTAssertEqual(count, all.count)
        if let fetched = await svc.fetch(id: "shared") {
            XCTAssertTrue(all.contains(fetched))
        } else {
            XCTAssertFalse(all.contains { $0.id == "shared" })
        }
    }

    func testConcurrentUnloadDuringSavesStaysConsistent() async throws {
        let svc = try ActorService<StoredObject>(destination: .custom(tempDir.path))
        let items = (0..<20).map { StoredObject(name: "u-\($0)", value: $0) }

        await withTaskGroup(of: Void.self) { group in
            for item in items {
                group.addTask { await svc.save(item) }
            }
            group.addTask { await svc.unload() }
        }

        let count = await svc.count
        let all = await svc.fetchAll()
        XCTAssertEqual(count, all.count, "index and collection must never disagree after a race with unload()")
    }

    func testConcurrentReplacesResultInOneCompleteSnapshot() async throws {
        let svc = try ActorService<StoredObject>(destination: .custom(tempDir.path))
        let snapshotA: Set<StoredObject> = [StoredObject(id: "a1", name: "a1", value: 1)]
        let snapshotB: Set<StoredObject> = [StoredObject(id: "b1", name: "b1", value: 2), StoredObject(id: "b2", name: "b2", value: 3)]

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await svc.replace(snapshotA) }
            group.addTask { await svc.replace(snapshotB) }
        }

        let all = await svc.fetchAll()
        XCTAssertTrue(all == snapshotA || all == snapshotB, "final state must be exactly one full snapshot, not a mix")
    }

    func testSecondIteratorCreatedLaterDoesNotReplayHistory() async throws {
        let svc = try ActorService<StoredObject>(destination: .custom(tempDir.path))
        var iteratorA = await svc.updates.makeAsyncIterator()
        let initialA = await iteratorA.next()
        XCTAssertEqual(initialA, [])

        await svc.save(StoredObject(name: "one", value: 1))
        let afterSave = await iteratorA.next()
        XCTAssertEqual(afterSave?.count, 1)

        var iteratorB = await svc.updates.makeAsyncIterator()
        await svc.save(StoredObject(name: "two", value: 2))
        let fromB = await iteratorB.next()
        XCTAssertEqual(fromB?.count, 2)
    }
}
