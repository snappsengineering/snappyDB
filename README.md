# snappyDB

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-iOS%2016%20%7C%20macOS%2013%20%7C%20tvOS%2016%20%7C%20watchOS%209-lightgrey.svg)](https://github.com/snappsengineering/snappyDB/releases)
[![CI](https://github.com/snappsengineering/snappyDB/actions/workflows/ci.yml/badge.svg)](https://github.com/snappsengineering/snappyDB/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Local JSON files on device. Optional AES-GCM encryption and Keychain keys. iCloud optional. Replaces ad-hoc `UserDefaults` + `FileManager` code.

## Get set up in 60 seconds

**1. Add the package** — in `Package.swift` or Xcode (**File → Add Package Dependencies**), pin the tag for your minimum OS ([VERSIONING.md](VERSIONING.md)):

```swift
.package(url: "https://github.com/snappsengineering/snappyDB.git", exact: "16.0.0")
```

Prefer `exact:` for reproducible builds. For bleeding edge, use `branch: "develop"`.

**2. Import and save a model** — define a type with a stable string `id`, create a service, and save:

```swift
import SnappyDB

struct Note: Storable {
    var id: String = Note.generateHexID()
    var title: String
    var body: String
}

let notes = Service<Note>()
notes.save(Note(title: "Hello", body: "World"))
print(notes.fetchAll())
```

One JSON file per collection. `Service` and `PublishedService` load from disk in `init`. Default `generateHexID()` length is **12** characters.

## Which type should I use?

| Type | Use when |
|------|----------|
| `Service<T>` | One JSON file, `Set` of models; call from one queue (e.g. main). |
| `PublishedService<T>` | Same + `@Published` for SwiftUI / Combine. |
| `ActorService<T>` | Async/await + `AsyncStream`; `T: Sendable`. |
| `SingleValueService<T>` | One `Codable` settings object. |
| `BlobService` | Raw `Data` (not JSON models). |

Not thread-safe unless you use `ActorService` or a single serial context.

## Usage notes

**Collections** — `save`, `delete`, `delete(id:)`, `replace`, `batch`, `fetchAll`, `fetch(id:)`, `contains(id:)`, `fetchIds()` (O(1) lookup). Updates go through `save` / `replace` / `batch` (equality is by `id` only). Duplicate `id`s in JSON collapse to one entry in the in-memory set. `reload()` refreshes from disk (`ActorService` included).

**Encryption** — Prefer `Encryption(keychain: KeychainKeyStore.forApp(bundleIdentifier:))`. `Encryption(keyString:)` hashes the string once (SHA256); use only for fixed app secrets, not user passwords.

**Soft-fail** — Bad or wrong-key files leave data on disk; `loadError` / `lastError` on `Service` and `PublishedService`; `ActorService` exposes the same after failed writes. `ActorService.softFailing(...)` matches load behavior of `Service`; plain `ActorService` throws on corrupt init.

**Single value** — Prefer `load()` when errors matter. `fetch()` returns `nil` for a missing file or a failed read; check `lastReadError` on failure. `exists()` checks the backing file without decoding.

**Blobs** — `exists()` before `fetchData()` when you only need to know if bytes are on disk.

**Migrations** — `Storable.migrationDefaults` fills missing JSON keys when you add properties.

**Destinations** — `.local(.documentDirectory)` (default), `.local(.applicationSupportDirectory)`, `.local(.cachesDirectory)` (rebuildable only), `.iCloud`, `.custom(path)`.

**Demo** — `Example/SnappyDBDemo.xcodeproj`.

[CONTRIBUTING.md](CONTRIBUTING.md) · [VERSIONING.md](VERSIONING.md) · [SECURITY.md](SECURITY.md) · MIT
