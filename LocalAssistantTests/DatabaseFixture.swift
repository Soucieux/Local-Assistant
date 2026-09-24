import Foundation

@testable import LocalAssistant

/// Owner of one isolated temporary SQLite database and its directory.
internal struct DatabaseFixture {
    private static let databaseFilename = "assistant.sqlite3"

    internal let directory: URL
    internal let databaseURL: URL

    /// Creates an isolated writable directory outside production storage.
    /// - Throws: A file error when the temporary directory cannot be created.
    internal init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        databaseURL = directory.appendingPathComponent(Self.databaseFilename)
    }

    /// Removes only this test's UUID-named temporary directory.
    ///
    /// The database and the `-wal` and `-shm` sidecars SQLite leaves beside it all live
    /// inside that directory, so removing it needs no separate sidecar cleanup.
    internal func remove() {
        try? FileManager.default.removeItem(at: directory)
    }
}
