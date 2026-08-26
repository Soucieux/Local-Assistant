import Foundation
import Testing

@testable import LocalAssistant

/// Complete-snapshot writes must be atomic because CloudBase has no tombstones or cursor.
struct ReminderDatabaseTests {
    @Test("An incomplete changed embedding set keeps the previous complete snapshot")
    internal func preservesSnapshotOnIncompleteReplacement() async throws {
        let fixture = try DatabaseFixture()
        defer { fixture.remove() }
        let database = AssistantDatabase(databaseURL: fixture.databaseURL)
        try await database.open()

        let first = reminder(text: "Renew permit", hash: "v1")
        try await database.reconcileReminders(
            [first],
            embeddings: [first.id: zeroEmbedding],
            syncedAt: first.lastSyncedAt
        )

        let changed = reminder(text: "Renew passport", hash: "v2")
        var replacementFailed = false
        do {
            try await database.reconcileReminders(
                [changed],
                embeddings: [:],
                syncedAt: changed.lastSyncedAt
            )
        } catch {
            replacementFailed = true
        }

        #expect(replacementFailed)
        let cached = try await database.fetchReminders()
        #expect(cached.map(\.text) == ["Renew permit"])
        let metadata = try await database.reminderSyncMetadata()
        #expect(metadata?.count == 1)
        await database.close()
    }

    @Test("A successful empty full snapshot removes rows without tombstones")
    internal func removesMissingRowsFromCompleteSnapshot() async throws {
        let fixture = try DatabaseFixture()
        defer { fixture.remove() }
        let database = AssistantDatabase(databaseURL: fixture.databaseURL)
        try await database.open()

        let first = reminder(text: "Renew permit", hash: "v1")
        try await database.reconcileReminders(
            [first],
            embeddings: [first.id: zeroEmbedding],
            syncedAt: first.lastSyncedAt
        )
        let secondSync = Date(timeIntervalSince1970: 3)
        try await database.reconcileReminders(
            [],
            embeddings: [:],
            syncedAt: secondSync
        )

        let cached = try await database.fetchReminders()
        let metadata = try await database.reminderSyncMetadata()
        #expect(cached.isEmpty)
        #expect(metadata?.count == 0)
        await database.close()
    }

    /// Creates one app-owned reminder with deterministic metadata.
    private func reminder(text: String, hash: String) -> ReminderItem {
        ReminderItem(
            id: "reminder-1",
            text: text,
            date: "2026-08-24",
            managedBy: ReminderConstants.Identity.localAssistantOwner,
            clientRequestId: UUID().uuidString,
            ownership: .localAssistant,
            contentHash: hash,
            lastSyncedAt: Date(timeIntervalSince1970: 2)
        )
    }

    /// One correctly sized vector used only to exercise snapshot storage.
    private var zeroEmbedding: [Float] {
        [Float](
            repeating: 0,
            count: AppConstants.Indexing.embeddingDimensions
        )
    }
}

/// Owner of one isolated temporary SQLite database and its directory.
private struct DatabaseFixture {
    let directory: URL
    let databaseURL: URL

    /// Creates an isolated writable directory outside production storage.
    internal init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        databaseURL = directory.appendingPathComponent("assistant.sqlite3")
    }

    /// Removes only this test's UUID-named temporary directory.
    internal func remove() {
        try? FileManager.default.removeItem(at: directory)
    }
}
